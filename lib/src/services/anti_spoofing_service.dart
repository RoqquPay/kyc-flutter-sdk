import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/config.dart';
import '../models/enums.dart';
import '../models/spoof_result.dart';
import 'face_kit.dart';

const _modelAssetPath = 'packages/roqqu_kyc/assets/ml_models/anti_spoof.tflite';
const _isolateResponseTimeout = Duration(seconds: 10);

// ---------------------------------------------------------------------------
// Core inference service (runs inside isolate)
// ---------------------------------------------------------------------------

class AntiSpoofingService {
  AntiSpoofingService(this._interpreter, this._config);

  final Interpreter _interpreter;
  final KycConfig _config;

  static const _laplaceThreshold = 50;

  Future<KycSpoofResult> isSpoofing(imglib.Image image) async {
    final clearness = laplacian(image);
    final livenessScore = await liveness(image);

    if (clearness < _config.clearnessThreshold) {
      return KycSpoofResult(
        isSpoof: true,
        clearnessScore: clearness.toDouble(),
        livenessScore: livenessScore,
        message: "Make sure you're in a well-lit environment.",
        shouldAddToHistory:
            !(livenessScore <= _config.livenessThreshold && clearness > _config.clearnessLowerThreshold),
      );
    }

    return KycSpoofResult(
      isSpoof: livenessScore > _config.livenessThreshold,
      clearnessScore: clearness.toDouble(),
      livenessScore: livenessScore,
    );
  }

  int laplacian(imglib.Image image) {
    final img = imglib.grayscale(imglib.copyResize(image, width: 256, height: 256));
    const laplaceKernel = [
      [0, 1, 0],
      [1, -4, 1],
      [0, 1, 0],
    ];
    int score = 0;

    for (int x = 0; x < 254; x++) {
      for (int y = 0; y < 254; y++) {
        int result = 0;
        for (int i = 0; i < 3; i++) {
          for (int j = 0; j < 3; j++) {
            final pixel = img.getPixel(x + i, y + j).r;
            result += pixel.toInt() * laplaceKernel[i][j];
          }
        }
        if (result.abs() > _laplaceThreshold) score++;
      }
    }
    return score;
  }

  Future<double> liveness(imglib.Image image) async {
    final input = _preProcess(image).reshape([1, 256, 256, 3]);
    final output = <int, Object>{};

    final clssPred = List<double>.filled(8, 0).reshape([1, 8]);
    final leafNodeMask = List<double>.filled(8, 0).reshape([1, 8]);

    output[_interpreter.getOutputIndex('Identity')] = clssPred;
    output[_interpreter.getOutputIndex('Identity_1')] = leafNodeMask;

    _interpreter.runForMultipleInputs([input], output);

    return _calculateLeafScore(clssPred, leafNodeMask);
  }

  double _calculateLeafScore(List clssPred, List leafNodeMask) {
    double score = 0;
    for (int i = 0; i < 8; i++) {
      score += (clssPred[0][i] * leafNodeMask[0][i]).abs();
    }
    return score;
  }

  Float32List _preProcess(imglib.Image image) {
    final resized = imglib.copyResize(image, width: 256, height: 256);
    return _imageToFloat32List(resized);
  }

  Float32List _imageToFloat32List(imglib.Image image) {
    final buffer = Float32List(256 * 256 * 3);
    int idx = 0;
    for (int y = 0; y < 256; y++) {
      for (int x = 0; x < 256; x++) {
        final pixel = image.getPixel(x, y);
        buffer[idx++] = pixel.r / 255.0;
        buffer[idx++] = pixel.g / 255.0;
        buffer[idx++] = pixel.b / 255.0;
      }
    }
    return buffer;
  }
}

// ---------------------------------------------------------------------------
// IPC message types
// ---------------------------------------------------------------------------

class _AntiSpoofingRequest {
  _AntiSpoofingRequest(this.image, this.modelBytes, this.config, this.responsePort);
  final imglib.Image image;
  final Uint8List modelBytes;
  final KycConfig config;
  final SendPort responsePort;
}

class _SpoofIsolateResult {
  _SpoofIsolateResult({
    required this.isSpoof,
    this.message,
    this.clearnessScore,
    this.livenessScore,
    this.shouldAddToHistory = true,
  });
  final bool isSpoof;
  final String? message;
  final double? clearnessScore;
  final double? livenessScore;
  final bool shouldAddToHistory;
}

// ---------------------------------------------------------------------------
// Isolate-based anti-spoofing service
// ---------------------------------------------------------------------------

class KycAntiSpoofingIsolateService {
  KycAntiSpoofingIsolateService(this._config);

  final KycConfig _config;

  Isolate? _isolate;
  SendPort? _sendPort;
  Completer<void>? _initCompleter;
  ReceivePort? _receivePort;

  Uint8List? _modelBytes;

  /// Lock to prevent concurrent frame processing
  Completer<void>? _processingLock;

  /// Frame results tracking
  final List<bool> _frameResults = [];
  final Map<int, bool> _stepsSpoofResult = {};
  final Map<KycFaceRecognitionStage, List<bool>> _stepFrameHistory = {};

  KycSpoofResult? _lastValidSpoofResult;

  bool _isStarted = false;

  int get totalFrameCount => _frameResults.length;
  int get nonSpoofFrameCount => _frameResults.where((r) => !r).length;
  int get spoofFrameCount => _frameResults.where((r) => r).length;

  int get _spoofPassThreshold =>
      (_config.framePassPercentage * _config.maxFrameCount).round();

  /// Start the isolate service. Loads the model from bundled assets.
  Future<void> start() async {
    if (!_config.isAntispoofingEnabled) return;

    resetState();
    await _loadModelBytes();

    _receivePort = ReceivePort();
    _initCompleter = Completer<void>();
    _isolate = await Isolate.spawn<SendPort>(
      _entryPoint,
      _receivePort!.sendPort,
    );
    _sendPort = await _receivePort!.first as SendPort;
    _initCompleter!.complete();
    _isStarted = true;
  }

  Future<void> _loadModelBytes() async {
    final byteData = await rootBundle.load(_modelAssetPath);
    _modelBytes = byteData.buffer.asUint8List();
  }

  static Future<void> _entryPoint(SendPort mainSendPort) async {
    final port = ReceivePort();
    mainSendPort.send(port.sendPort);

    Interpreter? interpreter;

    await for (final message in port) {
      if (message is _AntiSpoofingRequest) {
        try {
          interpreter ??= Interpreter.fromBuffer(message.modelBytes);
          final service = AntiSpoofingService(interpreter, message.config);
          final result = await service.isSpoofing(message.image);

          message.responsePort.send(_SpoofIsolateResult(
            isSpoof: result.isSpoof,
            message: result.message,
            clearnessScore: result.clearnessScore,
            livenessScore: result.livenessScore,
            shouldAddToHistory: result.shouldAddToHistory,
          ));
        } catch (e) {
          message.responsePort.send(_SpoofIsolateResult(
            isSpoof: true,
            shouldAddToHistory: false,
          ));
        }
      }
    }
  }

  /// Run anti-spoofing inference on a camera frame.
  Future<KycSpoofResult> runInference(
    CameraImage cameraImage,
    Face face, {
    required KycFaceRecognitionStage step,
  }) async {
    if (!_config.isAntispoofingEnabled) {
      return const KycSpoofResult(isSpoof: false);
    }

    final spoofResult = await _processSpoofModel(cameraImage, face);
    _processStepHistory(spoofResult, step);

    if (spoofResult.shouldAddToHistory && spoofResult.clearnessScore != null) {
      _lastValidSpoofResult = spoofResult;
    }

    final resultToUse =
        (spoofResult.clearnessScore != null) ? spoofResult : _lastValidSpoofResult;

    if (_frameResults.length < _config.maxFrameCount) {
      if (spoofResult.shouldAddToHistory) {
        _frameResults.add(spoofResult.isSpoof);
      }
      return KycSpoofResult(
        isSpoof: true,
        shouldAddToHistory: spoofResult.shouldAddToHistory,
        message: resultToUse?.message,
        clearnessScore: resultToUse?.clearnessScore,
        croppedFaceImage: resultToUse?.croppedFaceImage,
        livenessScore: resultToUse?.livenessScore,
        fullImage: resultToUse?.fullImage,
      );
    }

    final isSpoof =
        _frameResults.where((r) => r).length >= _spoofPassThreshold;
    _frameResults.clear();

    return KycSpoofResult(
      isSpoof: isSpoof,
      clearnessScore: resultToUse?.clearnessScore,
      croppedFaceImage: resultToUse?.croppedFaceImage,
      livenessScore: resultToUse?.livenessScore,
      fullImage: resultToUse?.fullImage,
    );
  }

  Future<KycSpoofResult> _processSpoofModel(
    CameraImage cameraImage,
    Face face,
  ) async {
    if (!_isStarted || _modelBytes == null || _sendPort == null) {
      return KycSpoofResult.skipped();
    }

    // Skip if already processing
    if (_processingLock != null && !_processingLock!.isCompleted) {
      return KycSpoofResult.skipped();
    }

    _processingLock = Completer<void>();
    ReceivePort? responsePort;

    try {
      final image = convertCameraImageToImage(cameraImage);
      final fullImagePng = Uint8List.fromList(imglib.encodePng(image));

      final faceBox = _getTightFaceRect(face);
      final x = faceBox.left.toInt().clamp(0, image.width - 1);
      final y = faceBox.top.toInt().clamp(0, image.height - 1);
      final width = faceBox.width.toInt().clamp(1, image.width - x);
      final height = faceBox.height.toInt().clamp(1, image.height - y);

      final croppedFace =
          imglib.copyCrop(image, x: x, y: y, width: width, height: height);
      final croppedPng = Uint8List.fromList(imglib.encodePng(croppedFace));

      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        await _initCompleter!.future;
      }

      responsePort = ReceivePort();
      _sendPort!.send(
        _AntiSpoofingRequest(croppedFace, _modelBytes!, _config, responsePort.sendPort),
      );

      final result = await responsePort.first.timeout(
        _isolateResponseTimeout,
        onTimeout: () => _SpoofIsolateResult(isSpoof: true, shouldAddToHistory: false),
      ) as _SpoofIsolateResult;

      return KycSpoofResult(
        isSpoof: result.isSpoof,
        message: result.message,
        shouldAddToHistory: result.shouldAddToHistory,
        croppedFaceImage: croppedPng,
        fullImage: fullImagePng,
        clearnessScore: result.clearnessScore,
        livenessScore: result.livenessScore,
      );
    } catch (_) {
      return KycSpoofResult.skipped();
    } finally {
      responsePort?.close();
      _processingLock?.complete();
    }
  }

  /// Check if the overall session appears to be spoofed (>= 40% of steps flagged).
  bool isPossibleSpoof() {
    final filtered = Map<int, bool>.from(_stepsSpoofResult)
      ..removeWhere((key, _) => key <= KycFaceRecognitionStage.detectFace.step);
    final results = filtered.values.toList();
    if (results.isEmpty) return false;

    final spoofSteps = results.where((r) => r).length;
    final ratio = spoofSteps / results.length;
    return ratio >= 0.4;
  }

  /// Extract face images (full + cropped) and save to temp files.
  ///
  /// Pass [controller] so the image can be flipped correctly based on
  /// camera rotation (front-facing cameras on some devices).
  Future<Map<String, File>> faceToFileImage(
    Face face,
    CameraImage cameraImage,
    CameraController? controller,
  ) async {
    var image = convertCameraImageToImage(cameraImage);

    // Determine if we need to flip horizontally based on rotation
    final rotation = KycFaceKit.getImageRotation(controller);
    if (!KycFaceKit.shouldNotInvert(rotation)) {
      image = imglib.flipHorizontal(image);
    }

    final fullImagePng = Uint8List.fromList(imglib.encodePng(image));

    final rect = face.boundingBox;
    final topPadding = (rect.height * 0.3).toInt();
    final bottomPadding = (rect.height * 0.10).toInt();
    final sidePadding = (rect.width * 0.2).toInt();

    final x = (rect.left - sidePadding).toInt().clamp(0, image.width - 1);
    final y = (rect.top - topPadding).toInt().clamp(0, image.height - 1);
    final cropWidth =
        (rect.width + sidePadding * 2).toInt().clamp(1, image.width - x);
    final cropHeight =
        (rect.height + topPadding + bottomPadding).toInt().clamp(1, image.height - y);

    final croppedFace =
        imglib.copyCrop(image, x: x, y: y, width: cropWidth, height: cropHeight);
    final croppedPng = Uint8List.fromList(imglib.encodePng(croppedFace));

    final dir = await getTemporaryDirectory();

    final fullImageFile = File(
        path.join(dir.path, 'full_image_${DateTime.now().millisecondsSinceEpoch}.png'));
    await fullImageFile.writeAsBytes(fullImagePng);

    final croppedFaceFile = File(
        path.join(dir.path, 'face_crop_${DateTime.now().millisecondsSinceEpoch}.png'));
    await croppedFaceFile.writeAsBytes(croppedPng);

    return {
      'fullImage': fullImageFile,
      'croppedFace': croppedFaceFile,
    };
  }

  void resetState() {
    _frameResults.clear();
    _stepsSpoofResult.clear();
    _stepFrameHistory.clear();
    _processingLock = null;
    _lastValidSpoofResult = null;
    _isStarted = false;
  }

  void dispose() {
    if (!_config.isAntispoofingEnabled) return;

    _receivePort?.close();
    _receivePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    resetState();
    _sendPort = null;
    _initCompleter = null;
  }

  // ---------------------------------------------------------------------------
  // Per-step spoof tracking
  // ---------------------------------------------------------------------------

  void _processStepHistory(KycSpoofResult spoofResult, KycFaceRecognitionStage step) {
    const spoofStepsCheckCount = 3;
    if (!spoofResult.shouldAddToHistory) return;

    final results = _stepFrameHistory.putIfAbsent(step, () => []);

    if (results.length >= spoofStepsCheckCount) {
      results.removeAt(0);
    }

    results.add(spoofResult.isSpoof);

    if (results.length == spoofStepsCheckCount) {
      final spoofs = results.where((r) => r).length;
      final isStepSpoof = spoofs >= (spoofStepsCheckCount * 0.6);
      _stepsSpoofResult[step.step] = isStepSpoof;
    }
  }
}

// ---------------------------------------------------------------------------
// Camera image conversion utilities
// ---------------------------------------------------------------------------

imglib.Image convertCameraImageToImage(CameraImage cameraImage) {
  if (Platform.isAndroid) {
    if (cameraImage.format.group == ImageFormatGroup.nv21) {
      return _nv21SinglePlaneToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return _yuv420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return _bgra8888ToImage(cameraImage);
    } else {
      throw UnsupportedError(
        'Unsupported Android format: ${cameraImage.format.group}',
      );
    }
  } else if (Platform.isIOS) {
    if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return _bgra8888ToImage(cameraImage);
    } else {
      throw UnsupportedError(
        'Unsupported iOS format: ${cameraImage.format.group}',
      );
    }
  } else {
    throw UnsupportedError('Unsupported platform');
  }
}

imglib.Image _nv21SinglePlaneToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;
  final img = imglib.Image(width: width, height: height);
  final bytes = cameraImage.planes[0].bytes;
  final frameSize = width * height;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * width + x;
      final yValue = bytes[yIndex] & 0xff;

      final uvIndex = frameSize + (y >> 1) * width + (x & ~1);
      final vValue = bytes[uvIndex] & 0xff;
      final uValue = bytes[uvIndex + 1] & 0xff;

      int r = (yValue + 1.370705 * (vValue - 128)).round();
      int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).round();
      int b = (yValue + 1.732446 * (uValue - 128)).round();

      img.setPixelRgba(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255);
    }
  }

  return imglib.copyRotate(img, angle: -90);
}

imglib.Image _bgra8888ToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;
  final image = imglib.Image(width: width, height: height);
  final bytes = cameraImage.planes[0].bytes;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int pixelIndex = (y * width + x) * 4;
      final b = bytes[pixelIndex];
      final g = bytes[pixelIndex + 1];
      final r = bytes[pixelIndex + 2];
      final a = bytes[pixelIndex + 3];
      image.setPixelRgba(x, y, r, g, b, a);
    }
  }

  return image;
}

imglib.Image _yuv420ToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;
  final image = imglib.Image(width: width, height: height);

  if (cameraImage.planes.length < 3) {
    throw Exception('YUV420 image must have at least 3 planes');
  }

  final yPlane = cameraImage.planes[0].bytes;
  final uPlane = cameraImage.planes[1].bytes;
  final vPlane = cameraImage.planes[2].bytes;

  final yRowStride = cameraImage.planes[0].bytesPerRow;
  final uRowStride = cameraImage.planes[1].bytesPerRow;
  final vRowStride = cameraImage.planes[2].bytesPerRow;

  final yPixelStride = cameraImage.planes[0].bytesPerPixel ?? 1;
  final uPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
  final vPixelStride = cameraImage.planes[2].bytesPerPixel ?? 1;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final yIndex = y * yRowStride + x * yPixelStride;
      final yValue = yPlane[yIndex] & 0xff;

      final uvX = x ~/ 2;
      final uvY = y ~/ 2;
      final uIndex = uvY * uRowStride + uvX * uPixelStride;
      final vIndex = uvY * vRowStride + uvX * vPixelStride;

      final uValue = uPlane[uIndex] & 0xff;
      final vValue = vPlane[vIndex] & 0xff;

      int r = (yValue + 1.370705 * (vValue - 128)).round();
      int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).round();
      int b = (yValue + 1.732446 * (uValue - 128)).round();

      image.setPixelRgba(x, y, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255), 255);
    }
  }

  return image;
}

Rect _getTightFaceRect(Face face) {
  final landmarksPoints = [
    face.landmarks[FaceLandmarkType.leftEye]?.position,
    face.landmarks[FaceLandmarkType.rightEye]?.position,
    face.landmarks[FaceLandmarkType.noseBase]?.position,
    face.landmarks[FaceLandmarkType.leftCheek]?.position,
    face.landmarks[FaceLandmarkType.rightCheek]?.position,
    face.landmarks[FaceLandmarkType.bottomMouth]?.position,
  ];
  final landmarks = landmarksPoints
      .whereType<Point<int>>()
      .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
      .toList();

  if (landmarks.isEmpty) return face.boundingBox;

  final minX = landmarks.map((p) => p.dx).reduce((a, b) => a < b ? a : b) - 30;
  final maxX = landmarks.map((p) => p.dx).reduce((a, b) => a > b ? a : b) + 30;
  final maxY = landmarks.map((p) => p.dy).reduce((a, b) => a > b ? a : b) + 30;

  const double padding = 40;
  return Rect.fromLTRB(
    minX - padding,
    face.boundingBox.top,
    maxX + padding,
    maxY + padding,
  );
}
