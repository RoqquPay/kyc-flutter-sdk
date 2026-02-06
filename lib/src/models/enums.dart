enum KycFaceRecognitionStage {
  initial(0),
  detectFace(1),
  tiltLeft(2),
  tiltRight(3),
  smile(4),
  mouthOpen(5),
  stayStill(6),
  done(7);

  const KycFaceRecognitionStage(this.step);

  final int step;

  static KycFaceRecognitionStage? getNextStep(int currentStep) {
    const values = KycFaceRecognitionStage.values;
    final nextStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) + 1;
    return nextStepIndex < values.length ? values[nextStepIndex] : null;
  }

  static KycFaceRecognitionStage getPreviousStep(int currentStep) {
    const values = KycFaceRecognitionStage.values;
    final previousStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) - 1;
    return previousStepIndex >= 0 ? values[previousStepIndex] : values.first;
  }
}

enum KycUploadMethod {
  upload(),
  capture();

  const KycUploadMethod();
}

enum KycRequiredId {
  bvn,
  govId;

  static KycRequiredId byValue(String? id) {
    switch (id?.toLowerCase()) {
      case 'bvn':
        return KycRequiredId.bvn;
      case 'id':
        return KycRequiredId.govId;
      default:
        return KycRequiredId.govId;
    }
  }
}

extension KycFaceRecognitionStageExtension on KycFaceRecognitionStage {
  double get progress {
    const totalSteps = 5;
    if (this == KycFaceRecognitionStage.initial) return 0;
    if (this == KycFaceRecognitionStage.stayStill) return 1;
    if (this == KycFaceRecognitionStage.done) return 1;
    final currentIndex = KycFaceRecognitionStage.values.indexOf(this) - 2;
    return (currentIndex / totalSteps).clamp(0.0, 1.0);
  }

  bool get showFaceLandMark {
    if (this == KycFaceRecognitionStage.initial) return true;
    if (this == KycFaceRecognitionStage.detectFace) return true;
    return false;
  }

  bool get isStayStill => this == KycFaceRecognitionStage.stayStill;

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

enum KycVerStatus {
  verified(),
  awaitingApproval(),
  ongoing(),
  faceMatchFailed(),
  rejected(),
  awaitingFacialComparison();

  const KycVerStatus();

  static KycVerStatus byValue(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return KycVerStatus.verified;
      case 'awaiting_approval':
        return KycVerStatus.awaitingApproval;
      case 'ongoing':
        return KycVerStatus.ongoing;
      case 'rejected':
        return KycVerStatus.rejected;
      case 'facematch_failed':
        return KycVerStatus.faceMatchFailed;
      case 'awaiting_facial_comparison':
        return KycVerStatus.awaitingFacialComparison;
      default:
        return KycVerStatus.ongoing;
    }
  }
}

enum KycAllowedId {
  ninSlip('NIN Slip', 'nin', 0.9, 0.3),
  nationalId('National ID', 'national-id', 0.9, 0.5),
  driversLicense("Driver's License", 'driver-license', 0.9, 0.5),
  votersCard("Voter's Card", 'voter-card', 0.9, 0.5),
  internationalPassport('International Passport', 'passport', 0.9, 0.3);

  const KycAllowedId(this.title, this.key, this.width, this.height);

  final String title;
  final String key;
  final double width;
  final double height;

  static KycAllowedId? fromKey(String key) {
    return KycAllowedId.values.firstWhere(
      (element) => element.key == key,
      orElse: () => throw ArgumentError('Invalid key: $key'),
    );
  }
}

enum KycVerificationState {
  checking(0),
  preparing(1),
  transmitting(2),
  matching(3),
  awaiting(4),
  finalized(5);

  const KycVerificationState(this.step);

  final int step;

  static KycVerificationState? getNextStep(int currentStep) {
    const values = KycVerificationState.values;
    final nextStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) + 1;
    return nextStepIndex < values.length ? values[nextStepIndex] : null;
  }

  static KycVerificationState getPreviousStep(int currentStep) {
    const values = KycVerificationState.values;
    final previousStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) - 1;
    return previousStepIndex >= 0 ? values[previousStepIndex] : values.first;
  }

  static KycVerificationState updatePassedStep(int currentStep) {
    const values = KycVerificationState.values;
    final previousStepIndex =
        values.indexWhere((stage) => stage.step == currentStep) - 1;
    return previousStepIndex >= 0 ? values[previousStepIndex] : values.first;
  }
}

enum KycVerStepStatus { completed, inProgress, notStarted }

List<KycVerificationState> getKycVerificationStates(KycRequiredId id) =>
    switch (id) {
      KycRequiredId.bvn => [
          KycVerificationState.checking,
          KycVerificationState.preparing,
          KycVerificationState.transmitting,
          KycVerificationState.matching,
          KycVerificationState.awaiting,
          KycVerificationState.finalized,
        ],
      KycRequiredId.govId => [
          KycVerificationState.checking,
          KycVerificationState.preparing,
          KycVerificationState.transmitting,
        ],
    };

enum KycRequiredStepStatus { pending, ongoing, completed, rejected, submitted }

extension KycRequiredStepStatusString on KycRequiredStepStatus {
  static KycRequiredStepStatus fromString(String string) {
    if (string == 'pending') return KycRequiredStepStatus.pending;
    if (string == 'ongoing') return KycRequiredStepStatus.ongoing;
    if (string == 'completed') return KycRequiredStepStatus.completed;
    if (string == 'rejected') return KycRequiredStepStatus.rejected;
    if (string == 'submitted') return KycRequiredStepStatus.submitted;
    return KycRequiredStepStatus.pending;
  }
}

enum KycSelfieFlow { useVideo, useImage }
