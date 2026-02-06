import 'dart:async';

import 'package:camera/camera.dart';

/// Internal camera lifecycle manager used by [KycEngine].
///
/// Handles front camera initialization, image streaming, and cleanup.
/// Not exported publicly — consumers interact with the camera through
/// [KycEngine.cameraController] and [KycEngine.startWithStream].
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final StreamController<CameraImage> _imageStreamController =
      StreamController<CameraImage>.broadcast();

  /// The active camera controller, or `null` if not initialized.
  CameraController? get controller => _controller;

  /// All available cameras on the device.
  List<CameraDescription> get cameras => _cameras;

  /// Stream of raw camera frames from the image stream.
  Stream<CameraImage> get imageStream => _imageStreamController.stream;

  /// Whether the camera is initialized and actively streaming.
  bool get isReady =>
      _controller != null && _controller!.value.isInitialized;

  /// Initializes the front-facing camera and starts the image stream.
  ///
  /// Selects the first front-facing camera available. If none exists,
  /// falls back to the first available camera.
  ///
  /// Throws [CameraException] if camera permissions are denied or the
  /// camera is unavailable. The consumer must request camera permissions
  /// before calling this method.
  Future<void> initialize({
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      throw CameraException(
        e.code,
        'Failed to enumerate cameras. Ensure camera permission is granted. '
        'Original error: ${e.description}',
      );
    }

    if (_cameras.isEmpty) {
      throw CameraException(
        'noCameras',
        'No cameras available on this device.',
      );
    }

    final frontCamera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
    } on CameraException catch (e) {
      throw CameraException(
        e.code,
        'Camera initialization failed. If permission was denied, grant camera '
        'access in device settings. Original error: ${e.description}',
      );
    }

    await _controller!.startImageStream(_onImageAvailable);
  }

  /// Stops the image stream without disposing the controller.
  Future<void> stopStream() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller?.stopImageStream();
    }
  }

  /// Resumes the image stream after it was stopped.
  Future<void> resumeStream() async {
    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isStreamingImages) {
      await _controller!.startImageStream(_onImageAvailable);
    }
  }

  /// Fully disposes the camera controller and closes the image stream.
  Future<void> dispose() async {
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    await _imageStreamController.close();
  }

  void _onImageAvailable(CameraImage image) {
    if (!_imageStreamController.isClosed) {
      _imageStreamController.add(image);
    }
  }
}
