part of '../../roqqu_kyc.dart';

class LivenessCheckService {
  LivenessCheckService({
    this.gestureThreshold = 1,
  });

  /// Threshold for gestures to be considered valid (frames count)
  final int gestureThreshold;

  final List<KycFaceRecognitionStage> _challengeSequence = [
    KycFaceRecognitionStage.tiltLeft,
    KycFaceRecognitionStage.tiltRight,
    KycFaceRecognitionStage.smile,
    KycFaceRecognitionStage.mouthOpen,
  ];

  KycFaceRecognitionStage _currentStage = KycFaceRecognitionStage.initial;
  int _challengeIndex = 0;

  // Counters
  int _stepCounter = 0;
  int _gestureCount = 0;
  DateTime? _lastSuccessfulStepScanTime;

  // Getters
  KycFaceRecognitionStage get currentStage => _currentStage;
  List<KycFaceRecognitionStage> get sequence =>
      List.unmodifiable(_challengeSequence);

  void start() {
    _currentStage = KycFaceRecognitionStage.initial;
    _stepCounter = 0;
    _gestureCount = 0;
    _challengeIndex = 0;
    _lastSuccessfulStepScanTime = DateTime.now();
  }

  /// Process a frame result and return the updated stage
  /// Returns null if no change in stage, or the same stage if progress updated
  KycFaceRecognitionStage process(
    KycDetectedFace face,
    bool isSpoof,
  ) {
    final now = DateTime.now();
    _lastSuccessfulStepScanTime ??= now;

    // Check timeout
    if (now.difference(_lastSuccessfulStepScanTime!) >
        _maxStepDuration(_currentStage)) {
      // Timeout handling
    }

    bool stepCompleted = false;

    switch (_currentStage) {
      case KycFaceRecognitionStage.initial:
        stepCompleted = true;
        break;
      case KycFaceRecognitionStage.detectFace:
        if (!isSpoof &&
            face.faceIsWellPositioned &&
            !face.isBlinking &&
            !face.lookingAway) {
          stepCompleted = true;
        }
        break;
      case KycFaceRecognitionStage.tiltLeft:
        stepCompleted = face.turnedLeft;
        break;
      case KycFaceRecognitionStage.tiltRight:
        stepCompleted = face.turnedRight;
        break;
      case KycFaceRecognitionStage.smile:
        stepCompleted = face.isSmiling;
        break;
      case KycFaceRecognitionStage.mouthOpen:
        stepCompleted = face.isMouthOpen;
        break;
      case KycFaceRecognitionStage.stayStill:
      case KycFaceRecognitionStage.done:
        break;
    }

    if (stepCompleted) {
      _gestureCount++;
      if (_gestureCount < gestureThreshold &&
          _challengeSequence.contains(_currentStage)) {
        return _currentStage; // Waiting for more frames of gesture
      }

      _gestureCount = 0;
      _stepCounter++;

      if (_stepCounter >= _stepCounterCount(_currentStage)) {
        _advanceStage();
        _stepCounter = 0;
        _lastSuccessfulStepScanTime = DateTime.now();
      }
    }

    return _currentStage;
  }

  void _advanceStage() {
    if (_currentStage == KycFaceRecognitionStage.initial) {
      _currentStage = KycFaceRecognitionStage.detectFace;
    } else if (_currentStage == KycFaceRecognitionStage.detectFace) {
      _currentStage = _challengeSequence[_challengeIndex];
      _challengeIndex++;
    } else if (_challengeSequence.contains(_currentStage)) {
      if (_challengeIndex < _challengeSequence.length) {
        _currentStage = _challengeSequence[_challengeIndex];
        _challengeIndex++;
      } else {
        _currentStage = KycFaceRecognitionStage.done;
      }
    }
  }

  int _stepCounterCount(KycFaceRecognitionStage stage) => switch (stage) {
        KycFaceRecognitionStage.detectFace => 1,
        KycFaceRecognitionStage.initial => 1,
        _ => 2,
      };

  Duration _maxStepDuration(KycFaceRecognitionStage stage) => switch (stage) {
        KycFaceRecognitionStage.initial => const Duration(seconds: 60),
        KycFaceRecognitionStage.detectFace => const Duration(seconds: 60),
        _ => const Duration(seconds: 20),
      };
}
