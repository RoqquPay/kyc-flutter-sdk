import 'dart:io';

import '../models/detected_face.dart';
import '../models/enums.dart';
import '../models/kyc_feedback.dart';
import '../models/spoof_result.dart';

/// Immutable snapshot of the liveness verification pipeline at a point in time.
///
/// Emitted by [KycEngine.stateStream] on every processed frame. Contains
/// everything the UI layer needs to render feedback, progress, and results.
///
/// ```dart
/// engine.stateStream.listen((state) {
///   if (state.isComplete) {
///     final selfie = state.capturedImage;
///     // upload selfie...
///   }
///   updateUI(state.currentStep, state.progress, state.feedback);
/// });
/// ```
class KycLivenessState {
  const KycLivenessState({
    required this.currentStep,
    this.detectedFace,
    this.spoofResult,
    this.feedback = KycFeedback.none,
    this.progress = 0.0,
    this.isComplete = false,
    this.capturedImage,
    this.isCameraReady = false,
    this.isTimedOut = false,
  });

  /// Creates the initial state before the engine has started processing.
  factory KycLivenessState.initial() => const KycLivenessState(
        currentStep: KycFaceRecognitionStage.initial,
      );

  /// The current liveness challenge step being evaluated.
  final KycFaceRecognitionStage currentStep;

  /// The latest face detection result, or `null` if no face was found
  /// in the most recent frame.
  final KycDetectedFace? detectedFace;

  /// The latest anti-spoofing inference result, or `null` if anti-spoofing
  /// is disabled or hasn't run yet.
  final KycSpoofResult? spoofResult;

  /// Actionable feedback for the user (e.g., move closer, face not centered).
  final KycFeedback feedback;

  /// Overall completion progress from 0.0 (not started) to 1.0 (done).
  final double progress;

  /// Whether all liveness challenges have been completed successfully.
  final bool isComplete;

  /// The captured selfie image file, taken when the configured [KycConfig.captureStep]
  /// completes (defaults to `detectFace`, but can be set to e.g. `smile`).
  final File? capturedImage;

  /// Whether the camera is initialized and streaming frames.
  final bool isCameraReady;

  /// Whether the current challenge step has exceeded its allowed duration.
  /// The consumer can use this to show a timeout message or trigger a retry.
  final bool isTimedOut;

  KycLivenessState copyWith({
    KycFaceRecognitionStage? currentStep,
    KycDetectedFace? detectedFace,
    KycSpoofResult? spoofResult,
    KycFeedback? feedback,
    double? progress,
    bool? isComplete,
    File? capturedImage,
    bool? isCameraReady,
    bool? isTimedOut,
  }) {
    return KycLivenessState(
      currentStep: currentStep ?? this.currentStep,
      detectedFace: detectedFace ?? this.detectedFace,
      spoofResult: spoofResult ?? this.spoofResult,
      feedback: feedback ?? this.feedback,
      progress: progress ?? this.progress,
      isComplete: isComplete ?? this.isComplete,
      capturedImage: capturedImage ?? this.capturedImage,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      isTimedOut: isTimedOut ?? this.isTimedOut,
    );
  }
}
