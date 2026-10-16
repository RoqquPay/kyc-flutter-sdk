import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import '../core/config.dart';
import '../models/enums.dart';
import '../services/anti_spoofing_service.dart';
import '../services/face_detection_service.dart';
import '../services/face_kit.dart';
import '../services/liveness_session.dart';
import '../services/video_recorder.dart';
import 'camera_service.dart';
import 'liveness_state.dart';

/// Signature for the error callback invoked when the engine encounters
/// a non-fatal error during frame processing.
typedef KycErrorCallback = void Function(Object error, StackTrace stackTrace);

/// The main orchestrator for camera-based face liveness verification.
///
/// Composes [CameraService], [KycFaceDetectionService],
/// [KycAntiSpoofingIsolateService], and [LivenessSession] into a single
/// pipeline. Feed it camera frames (or let it manage its own camera) and
/// it emits [KycLivenessState] snapshots on every processed frame.
///
/// **SDK-managed camera:**
/// ```dart
/// final engine = KycEngine(config: KycConfig());
/// await engine.start();
///
/// engine.stateStream.listen((state) {
///   // update UI with state.currentStep, state.progress, etc.
///   if (state.isComplete) {
///     final selfie = state.capturedImage;
///   }
/// });
///
/// // When done:
/// await engine.dispose();
/// ```
///
/// **Bring-your-own camera:**
/// ```dart
/// final engine = KycEngine(config: KycConfig());
/// await engine.startWithStream(myImageStream, myController, myCameras);
/// ```
///
/// **Error handling:**
/// ```dart
/// final engine = KycEngine(
///   config: KycConfig(),
///   onError: (error, stack) => print('KYC error: $error'),
/// );
/// ```
class KycEngine {
  KycEngine({required this.config, this.onError});

  /// The configuration driving thresholds, timeouts, and challenge selection.
  final KycConfig config;

  /// Optional callback invoked when the engine encounters a non-fatal error
  /// during frame processing (e.g., face detection failure, image conversion
  /// error, selfie capture failure). If not set, errors are silently dropped
  /// and the engine moves on to the next frame.
  final KycErrorCallback? onError;

  final CameraService _cameraService = CameraService();
  late final KycFaceDetectionService _faceDetectionService =
      KycFaceDetectionService();
  late final KycAntiSpoofingIsolateService _antiSpoofingService =
      KycAntiSpoofingIsolateService(config);
  late final LivenessSession _livenessSession = LivenessSession(config: config);
  late final KycVideoRecorder? _videoRecorder = config.recordVideo
      ? KycVideoRecorder(
          onError: (e, stack) => _reportError('Liveness video failed', e, stack),
        )
      : null;

  final StreamController<KycLivenessState> _stateController =
      StreamController<KycLivenessState>.broadcast();

  StreamSubscription<CameraImage>? _imageSubscription;
  Timer? _scanTimer;
  bool _isProcessing = false;
  bool _ownsCamera = false;
  bool _detectFacePassed = false;
  File? _capturedImage;

  CameraImage? _latestFrame;
  bool _isForeground = true;
  _EngineLifecycleObserver? _lifecycleObserver;
  CameraController? _externalController;
  List<CameraDescription> _externalCameras = [];

  /// Stream of liveness state snapshots, emitted on every processed frame.
  Stream<KycLivenessState> get stateStream => _stateController.stream;

  /// The active camera controller. Available after [start] or
  /// [startWithStream] is called.
  CameraController? get cameraController =>
      _ownsCamera ? _cameraService.controller : _externalController;

  /// The available cameras. Populated after [start] or passed via
  /// [startWithStream].
  List<CameraDescription> get cameras =>
      _ownsCamera ? _cameraService.cameras : _externalCameras;

  /// The current liveness session instance, for direct access if needed.
  LivenessSession get livenessSession => _livenessSession;

  /// Starts the engine with an SDK-managed front camera.
  ///
  /// Initializes the camera, starts the image stream, boots anti-spoofing
  /// (if enabled), and begins the liveness challenge sequence.
  Future<void> start() async {
    _ownsCamera = true;
    await _cameraService.initialize();

    _emitState(KycLivenessState.initial().copyWith(isCameraReady: true));

    if (config.enableAntispoofing) {
      await _antiSpoofingService.start();
    }

    _livenessSession.start();
    _listenToFrames(_cameraService.imageStream);
  }

  /// Starts the engine using an externally managed camera stream.
  ///
  /// Use this when you want full control over camera initialization.
  /// The engine will process frames from [imageStream] using [controller]
  /// for rotation metadata.
  Future<void> startWithStream(
    Stream<CameraImage> imageStream,
    CameraController controller,
    List<CameraDescription> cameras,
  ) async {
    _ownsCamera = false;
    _externalController = controller;
    _externalCameras = cameras;

    _emitState(KycLivenessState.initial().copyWith(isCameraReady: true));

    if (config.enableAntispoofing) {
      await _antiSpoofingService.start();
    }

    _livenessSession.start();
    _listenToFrames(imageStream);
  }

  /// Resets the liveness session while keeping the camera active.
  ///
  /// Clears all challenge progress and anti-spoofing state, then restarts
  /// the challenge sequence. Useful for retry flows.
  Future<void> reset() async {
    _capturedImage = null;
    _detectFacePassed = false;
    _antiSpoofingService.resetState();

    if (config.enableAntispoofing) {
      await _antiSpoofingService.start();
    }

    _livenessSession.start();
    _emitState(KycLivenessState.initial().copyWith(isCameraReady: true));
  }

  /// Returns the liveness video recorded since the previous call, or `null`.
  ///
  /// Requires [KycConfig.recordVideo]. The clip starts when a face first
  /// appeared, keeps at most the last 20 seconds, and ends now; a fresh clip
  /// begins afterwards. Never throws: if recording failed or was unavailable
  /// it returns `null` and the cause is passed to [onError].
  Future<File?> takeVideo() async => await _videoRecorder?.take();

  /// Fully disposes the engine, releasing all resources.
  ///
  /// Stops the camera (if SDK-managed), closes the face detector,
  /// kills the anti-spoofing isolate, and closes the state stream.
  Future<void> dispose() async {
    _scanTimer?.cancel();
    final observer = _lifecycleObserver;
    if (observer != null) WidgetsBinding.instance.removeObserver(observer);
    await _imageSubscription?.cancel();
    await _videoRecorder?.dispose();
    _antiSpoofingService.dispose();
    await _faceDetectionService.dispose();

    if (_ownsCamera) {
      await _cameraService.dispose();
    }

    await _stateController.close();
  }

  void _listenToFrames(Stream<CameraImage> stream) {
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed;
    if (_lifecycleObserver == null) {
      final observer = _EngineLifecycleObserver(_onLifecycleChanged);
      WidgetsBinding.instance.addObserver(observer);
      _lifecycleObserver = observer;
    }

    _imageSubscription = stream.listen((image) {
      if (!_isForeground) return;
      _latestFrame = image;
      _videoRecorder?.addFrame(image, cameraController);
    });

    _scanTimer = Timer.periodic(config.scanInterval, (_) {
      _processLatestFrame();
    });
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) _latestFrame = null;
  }

  Future<void> _processLatestFrame() async {
    if (!_isForeground || _isProcessing || _latestFrame == null) return;
    if (_stateController.isClosed) return;

    final currentStage = _livenessSession.currentStage;
    if (currentStage == KycFaceRecognitionStage.done) return;

    _isProcessing = true;

    try {
      final frame = _latestFrame!;
      _latestFrame = null;
      final controller = cameraController;

      // 1. Convert camera frame to InputImage
      final (inputImage, rotation) = KycFaceKit.inputImageFromCameraImage(
        frame,
        controller,
        cameras,
      );

      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      // 2. Run face detection
      final detectedFace = await _faceDetectionService.processImage(
        inputImage,
        config,
        rotation: rotation,
      );
      if (detectedFace.face != null) _videoRecorder?.arm();

      // 3. Run anti-spoofing if enabled and on detectFace step
      var spoofResult = _antiSpoofingService.lastValidResult;
      bool isSpoof = false;

      if (config.enableAntispoofing &&
          currentStage == KycFaceRecognitionStage.detectFace &&
          detectedFace.face != null &&
          detectedFace.faceIsWellPositioned) {
        spoofResult = await _antiSpoofingService.runInference(
          frame,
          detectedFace.face!,
          step: currentStage,
        );
        isSpoof = spoofResult.isSpoof;
      }

      // 4. Feed into liveness session
      final result = _livenessSession.process(
        detectedFace,
        isSpoof: isSpoof,
      );

      if (result.stepCompleted &&
          currentStage == KycFaceRecognitionStage.detectFace) {
        _detectFacePassed = true;
      }

      // 5. Capture selfie when the configured step passes
      final captureAt =
          config.captureStep ?? KycFaceRecognitionStage.detectFace;
      if (result.stepCompleted &&
          currentStage == captureAt &&
          _detectFacePassed &&
          _capturedImage == null &&
          detectedFace.face != null) {
        try {
          final files = await _antiSpoofingService.faceToFileImage(
            detectedFace.face!,
            frame,
            controller,
          );
          _capturedImage = files['fullImage'];
        } catch (e, stack) {
          _reportError('Selfie capture failed', e, stack);
        }
      }

      // 6. Emit state
      _emitState(KycLivenessState(
        currentStep: result.stage,
        detectedFace: detectedFace,
        spoofResult: spoofResult,
        feedback: detectedFace.feedback,
        progress: _computeProgress(result.stage),
        isComplete: result.isComplete,
        capturedImage: _capturedImage,
        isCameraReady: true,
        isTimedOut: result.isTimedOut,
      ));
    } catch (e, stack) {
      _reportError('Frame processing failed', e, stack);
    } finally {
      _isProcessing = false;
    }
  }

  double _computeProgress(KycFaceRecognitionStage stage) {
    if (stage == KycFaceRecognitionStage.initial ||
        stage == KycFaceRecognitionStage.detectFace) {
      return 0;
    }
    if (stage == KycFaceRecognitionStage.done) { return 1; }

    final sequence = _livenessSession.sequence;
    final total = sequence.length + 1;
    final challengeIndex = sequence.indexOf(stage);
    if (challengeIndex == -1) return 0;

    return (challengeIndex + 1) / total;
  }

  void _reportError(String context, Object error, StackTrace stack) {
    onError?.call(error, stack);
  }

  void _emitState(KycLivenessState state) {
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}

class _EngineLifecycleObserver with WidgetsBindingObserver {
  _EngineLifecycleObserver(this.onChanged);

  final ValueChanged<AppLifecycleState> onChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => onChanged(state);
}
