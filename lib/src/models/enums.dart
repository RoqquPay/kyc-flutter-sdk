/// Represents each stage in the face liveness verification flow.
///
/// The engine progresses through these stages sequentially:
/// [initial] → [detectFace] → gesture challenges (e.g., [tiltLeft],
/// [smile]) → [done]. Which gestures are included and their order
/// is controlled by [KycConfig.challenges].
enum KycFaceRecognitionStage {
  /// Entry state before any processing begins.
  initial(0),

  /// Detecting and validating a well-positioned face in the frame.
  detectFace(1),

  /// User should tilt their head to the left.
  tiltLeft(2),

  /// User should tilt their head to the right.
  tiltRight(3),

  /// User should smile.
  smile(4),

  /// User should open their mouth.
  mouthOpen(5),

  /// User should hold still (used for selfie capture).
  stayStill(6),

  /// All challenges completed successfully.
  done(7);

  const KycFaceRecognitionStage(this.step);

  /// Numeric index for this stage, used for ordering and navigation.
  final int step;

  /// Returns the stage after [currentStep], or `null` if it's the last one.
  static KycFaceRecognitionStage? getNextStep(int currentStep) {
    const values = KycFaceRecognitionStage.values;
    final nextStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) + 1;
    return nextStepIndex < values.length ? values[nextStepIndex] : null;
  }

  /// Returns the stage before [currentStep], or the first stage if already
  /// at the beginning.
  static KycFaceRecognitionStage getPreviousStep(int currentStep) {
    const values = KycFaceRecognitionStage.values;
    final previousStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) - 1;
    return previousStepIndex >= 0 ? values[previousStepIndex] : values.first;
  }
}

/// Convenience getters for [KycFaceRecognitionStage].
extension KycFaceRecognitionStageExtension on KycFaceRecognitionStage {
  /// Overall completion progress from 0.0 to 1.0 based on this stage's
  /// position in the challenge sequence.
  double get progress {
    const totalSteps = 5;
    if (this == KycFaceRecognitionStage.initial) return 0;
    if (this == KycFaceRecognitionStage.stayStill) return 1;
    if (this == KycFaceRecognitionStage.done) return 1;
    final currentIndex = KycFaceRecognitionStage.values.indexOf(this) - 2;
    return (currentIndex / totalSteps).clamp(0.0, 1.0);
  }

  /// Whether the UI should display a face landmark overlay at this stage.
  /// Typically true only during [initial] and [detectFace].
  bool get showFaceLandMark {
    if (this == KycFaceRecognitionStage.initial) return true;
    if (this == KycFaceRecognitionStage.detectFace) return true;
    return false;
  }

  /// Whether this is the stay-still stage (for countdown UI).
  bool get isStayStill => this == KycFaceRecognitionStage.stayStill;

  /// A machine-readable label for this stage, useful as a localization key.
  String get label {
    switch (this) {
      case KycFaceRecognitionStage.initial:
        return 'face_within';
      case KycFaceRecognitionStage.detectFace:
        return 'detecting_face';
      case KycFaceRecognitionStage.tiltLeft:
        return 'move_face_left';
      case KycFaceRecognitionStage.tiltRight:
        return 'move_face_right';
      case KycFaceRecognitionStage.smile:
        return 'now_smile';
      case KycFaceRecognitionStage.mouthOpen:
        return 'open_mouth';
      case KycFaceRecognitionStage.stayStill:
        return 'stay_still';
      case KycFaceRecognitionStage.done:
        return 'done';
    }
  }
}
