import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:kyc_engine/kyc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Demonstrates the full KycEngine liveness verification flow.
///
/// The engine manages the camera, runs face detection + anti-spoofing,
/// and advances through gesture challenges automatically. This screen
/// subscribes to the state stream and renders the UI accordingly.
class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  late final KycEngine _engine;
  KycLivenessState _state = KycLivenessState.initial();
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _engine = KycEngine(
      config: KycConfig(
        enableAntispoofing: false,
        shuffleChallenges: true,
        gestureConfirmations: 2,
      ),
      onError: (error, stack) {
        debugPrint('KycEngine error: $error');
      },
    );
    _requestPermissionAndStart();
  }

  Future<void> _requestPermissionAndStart() async {
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      if (mounted) {
        setState(() => _error = 'Camera permission is required for liveness '
            'verification. Please grant camera access in your device settings.');
      }
      return;
    }

    await _startEngine();
  }

  Future<void> _startEngine() async {
    try {
      await _engine.start();
      _engine.stateStream.listen((state) {
        if (mounted) setState(() => _state = state);
      });
      if (mounted) setState(() => _starting = false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _reset() async {
    setState(() => _state = KycLivenessState.initial());
    await _engine.reset();
  }

  @override
  void dispose() {
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liveness Verification'),
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
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
              if (_error!.contains('permission') || _error!.contains('Permission'))
                FilledButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Open Settings'),
                ),
            ],
          ),
        ),
      );
    }

    if (_starting) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Camera preview in oval clip
        Expanded(
          flex: 3,
          child: _buildCameraPreview(),
        ),

        // Challenge instruction + progress
        Expanded(
          flex: 1,
          child: _buildStatusPanel(),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final controller = _engine.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: Text('Initializing camera...'));
    }

    // Show completed state with captured selfie
    if (_state.isComplete && _state.capturedImage != null) {
      return _buildCompletionView(_state.capturedImage!);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background
        Container(color: Colors.black),

        // Oval-clipped camera preview
        ClipOval(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.45,
            child: OverflowBox(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? 300,
                  height: controller.value.previewSize?.width ?? 400,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),
        ),

        // Oval border indicating progress
        Container(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.45,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _state.isTimedOut
                  ? Colors.red
                  : _state.isComplete
                      ? Colors.green
                      : Colors.white.withValues(alpha: 0.5),
              width: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionView(File image) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.file(
            image,
            width: 200,
            height: 250,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const SizedBox(height: 8),
        const Text(
          'Verification Complete!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _state.progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 16),

          // Current instruction
          Text(
            _getInstructionText(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Feedback message
          if (_state.feedback != KycFeedback.none)
            Text(
              _getFeedbackText(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange.shade700,
              ),
            ),

          // Timeout warning
          if (_state.isTimedOut)
            const Text(
              'Step timed out — tap refresh to retry',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
        ],
      ),
    );
  }

  String _getInstructionText() {
    switch (_state.currentStep) {
      case KycFaceRecognitionStage.initial:
        return 'Position your face in the frame';
      case KycFaceRecognitionStage.detectFace:
        return 'Detecting your face...';
      case KycFaceRecognitionStage.tiltLeft:
        return 'Turn your head left';
      case KycFaceRecognitionStage.tiltRight:
        return 'Turn your head right';
      case KycFaceRecognitionStage.smile:
        return 'Now smile!';
      case KycFaceRecognitionStage.mouthOpen:
        return 'Open your mouth';
      case KycFaceRecognitionStage.stayStill:
        return 'Hold still...';
      case KycFaceRecognitionStage.done:
        return 'Verification complete!';
    }
  }

  String _getFeedbackText() {
    switch (_state.feedback) {
      case KycFeedback.noFaceDetected:
        return 'No face detected';
      case KycFeedback.faceTooFar:
      case KycFeedback.moveCloser:
        return 'Move closer to the camera';
      case KycFeedback.faceNotCentered:
        return 'Center your face in the frame';
      case KycFeedback.faceRotated:
        return 'Look straight at the camera';
      case KycFeedback.keepStill:
        return 'Hold still';
      case KycFeedback.multipleFaces:
        return 'Only one face should be visible';
      case KycFeedback.none:
        return '';
    }
  }
}
