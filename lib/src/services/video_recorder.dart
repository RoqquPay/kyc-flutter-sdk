import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'face_kit.dart';

/// Records the liveness session into a short H.264 mp4 for compliance.
///
/// Frames are handed to the platform's hardware encoder, which keeps only
/// the most recent [maxDuration] of encoded video in memory. Recording starts
/// once [arm] is called (the engine does this when a face first appears) and
/// never throws: on failure the recorder disables itself, reports through
/// [onError], and [take] returns `null`.
class KycVideoRecorder {
  KycVideoRecorder({required this.onError});

  static const Duration maxDuration = Duration(seconds: 20);
  static const int _fps = 15;
  static const int _bitrate = 700000;
  static const int _maxBytes = 4 * 1024 * 1024;
  static const Duration _finishTimeout = Duration(seconds: 5);
  static const MethodChannel _channel = MethodChannel('kyc_engine/video');

  final void Function(Object error, StackTrace stackTrace) onError;

  final Stopwatch _clock = Stopwatch()..start();
  int? _id;
  bool _disabled = false;
  bool _armed = false;
  int? _lastFrameUs;
  Future<void>? _pending;

  void arm() => _armed = true;

  void addFrame(CameraImage image, CameraController? controller) {
    if (_disabled || !_armed || _pending != null) return;
    final now = _clock.elapsedMicroseconds;
    final last = _lastFrameUs;
    if (last != null && now - last < Duration.microsecondsPerSecond ~/ _fps) {
      return;
    }
    _lastFrameUs = now;
    _pending = _send(image, controller, now).whenComplete(() => _pending = null);
  }

  Future<File?> take() async {
    _armed = false;
    _lastFrameUs = null;
    await _pending;
    final id = _id;
    if (_disabled || id == null) return null;
    try {
      final directory = await getTemporaryDirectory();
      final path = p.join(
        directory.path,
        'kyc_liveness_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      final written = await _channel
          .invokeMethod<bool>('finish', {'id': id, 'path': path})
          .timeout(_finishTimeout);
      if (written != true) return null;
      final file = File(path);
      final size = await file.length();
      if (size > _maxBytes) {
        await file.delete();
        onError(
          StateError('Liveness video was $size bytes, over the $_maxBytes cap'),
          StackTrace.current,
        );
        return null;
      }
      return file;
    } catch (e, stack) {
      onError(e, stack);
      return null;
    }
  }

  Future<void> dispose() async {
    _disabled = true;
    await _pending;
    final id = _id;
    _id = null;
    if (id == null) return;
    try {
      await _channel.invokeMethod<void>('release', {'id': id});
    } catch (e, stack) {
      onError(e, stack);
    }
  }

  Future<void> _send(
    CameraImage image,
    CameraController? controller,
    int timestampUs,
  ) async {
    try {
      final id = _id ??= await _start(image, controller);
      final plane = image.planes.first;
      await _channel.invokeMethod<void>('frame', {
        'id': id,
        'bytes': plane.bytes,
        'bytesPerRow': plane.bytesPerRow,
        'timestampUs': timestampUs,
      });
    } catch (e, stack) {
      _fail(e, stack);
    }
  }

  Future<int> _start(CameraImage image, CameraController? controller) async {
    final expected =
        Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888;
    if (image.format.group != expected || image.planes.length != 1) {
      throw UnsupportedError(
        'Liveness video needs single-plane ${expected.name} frames, '
        'got ${image.format.group.name} with ${image.planes.length} planes',
      );
    }
    final rotation = Platform.isAndroid
        ? KycFaceKit.getImageRotation(controller)?.rawValue ?? 0
        : 0;
    final id = await _channel.invokeMethod<int>('start', {
      'format': Platform.isAndroid ? 'nv21' : 'bgra',
      'width': image.width,
      'height': image.height,
      'rotation': rotation,
      'fps': _fps,
      'bitrate': _bitrate,
      'maxDurationUs': maxDuration.inMicroseconds,
    });
    if (id == null) throw StateError('Video recorder did not start');
    return id;
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_disabled) return;
    _disabled = true;
    onError(error, stackTrace);
    final id = _id;
    _id = null;
    if (id != null) {
      _channel.invokeMethod<void>('release', {'id': id}).catchError((_) {});
    }
  }
}
