import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:kyc_engine/kyc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Demonstrates using KycFaceDetectionService independently (Layer 1),
/// without the full KycEngine pipeline.
///
/// This shows how to manage your own camera and feed frames to the
/// face detection service directly — useful when you only need face
/// analysis without the liveness challenge flow.
class StandaloneDetectionScreen extends StatefulWidget {
  const StandaloneDetectionScreen({super.key});

  @override
  State<StandaloneDetectionScreen> createState() =>
      _StandaloneDetectionScreenState();
}

class _StandaloneDetectionScreenState extends State<StandaloneDetectionScreen> {
  CameraController? _controller;
  final KycFaceDetectionService _detector = KycFaceDetectionService();
  final KycConfig _config = KycConfig();

  KycDetectedFace? _lastResult;
  bool _isProcessing = false;
  bool _isInitialized = false;
  String? _error;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndInit();
  }

  Future<void> _requestPermissionAndInit() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _error = 'Camera permission is required. '
            'Please grant camera access in your device settings.');
      }
      return;
    }
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found');
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      CameraImage? latestFrame;
      await _controller!.startImageStream((image) {
        latestFrame = image;
      });

      // Process frames at a fixed interval
      _scanTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
        if (_isProcessing || latestFrame == null || _controller == null) return;
        _isProcessing = true;

        try {
          final cameras = await availableCameras();
          final (inputImage, rotation) = KycFaceKit.inputImageFromCameraImage(
            latestFrame!,
            _controller,
            cameras,
          );

          if (inputImage != null) {
            final result = await _detector.processImage(
              inputImage,
              _config,
              rotation: rotation,
            );
            if (mounted) setState(() => _lastResult = result);
          }
        } catch (e) {
          debugPrint('StandaloneDetection: Frame processing error — $e');
        } finally {
          _isProcessing = false;
        }
      });

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _controller?.dispose();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standalone Detection')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              if (_error!.contains('permission') ||
                  _error!.contains('Permission'))
                FilledButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
            ],
          ),
        ),
      );
    }
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: CameraPreview(_controller!),
        ),
        Expanded(
          flex: 1,
          child: _buildResults(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final r = _lastResult;
    if (r == null) {
      return const Center(child: Text('Waiting for face...'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.faceFound ? 'Face Found' : 'No Face',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: r.faceFound ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          _row('Well Positioned', r.faceIsWellPositioned),
          _row('Close Enough', r.isFaceCloseEnough),
          _row('Smiling', r.isSmiling),
          _row('Mouth Open', r.isMouthOpen),
          _row('Turned Left', r.turnedLeft),
          _row('Turned Right', r.turnedRight),
          _row('Blinking', r.isBlinking),
          _row('Looking Away', r.lookingAway),
          const SizedBox(height: 8),
          Text(
            'Feedback: ${r.feedback.name}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: value ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}
