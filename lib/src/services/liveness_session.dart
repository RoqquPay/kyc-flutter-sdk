import 'dart:math';

import '../core/config.dart';
import '../models/detected_face.dart';
import '../models/enums.dart';

/// Result returned by [LivenessSession.process] for each frame.
///
/// Contains the current stage, whether the step was just completed,
/// and whether the session has timed out or fully completed.
class LivenessStepResult {
  const LivenessStepResult({
    required this.stage,
    required this.stepCompleted,
    required this.isTimedOut,
    required this.isComplete,
  });

  /// The current liveness challenge stage after processing.
  final KycFaceRecognitionStage stage;

  /// Whether this frame caused the current step to advance.
  final bool stepCompleted;

  /// Whether the current step exceeded its allowed duration.
  final bool isTimedOut;

  /// Whether all challenges have been completed.
  final bool isComplete;
}

/// Manages the liveness challenge state machine.
///
/// Tracks which gesture challenge is active, validates face detections
/// against the expected gesture, and advances through the challenge
/// sequence. Works independently of any camera or UI — just feed it
/// [KycDetectedFace] results and it returns [LivenessStepResult].
///
/// ```dart
/// final session = LivenessSession(config: KycConfig());
/// session.start();
///
/// // On each processed frame:
/// final result = session.process(detectedFace, isSpoof: false);
/// if (result.isComplete) { /* all challenges passed */ }
/// ```
class LivenessSession {
  LivenessSession({required this.config});

  /// Configuration controlling challenges, timeouts, and confirmations.
  final KycConfig config;

  late List<KycFaceRecognitionStage> _challengeSequence;

  KycFaceRecognitionStage _currentStage = KycFaceRecognitionStage.initial;
  int _challengeIndex = 0;
  int _stepCounter = 0;
  int _gestureCount = 0;
  DateTime? _lastStepStartTime;

  /// The current challenge stage.
  KycFaceRecognitionStage get currentStage => _currentStage;

  /// The ordered list of challenge gestures for this session.
  List<KycFaceRecognitionStage> get sequence =>
      List.unmodifiable(_challengeSequence);

  /// Initializes (or resets) the session, optionally shuffling challenges.
  void start() {
    _challengeSequence = List.of(config.challenges);
    if (config.shuffleChallenges) {
      _challengeSequence.shuffle(Random());
    }

    _currentStage = KycFaceRecognitionStage.initial;
    _stepCounter = 0;
    _gestureCount = 0;
    _challengeIndex = 0;
    _lastStepStartTime = DateTime.now();
  }

  /// Processes a single frame's face detection result against the current
  /// challenge step.
  ///
  /// [face] is the detected face data for this frame.
  /// [isSpoof] indicates whether anti-spoofing flagged this frame as fake.
  ///
  /// Returns a [LivenessStepResult] describing the outcome — whether the
  /// step advanced, timed out, or the full sequence completed.
  LivenessStepResult process(KycDetectedFace face, {bool isSpoof = false}) {
    final now = DateTime.now();
    _lastStepStartTime ??= now;

    // Check timeout
    final timeout = _maxStepDuration(_currentStage);
    final isTimedOut = now.difference(_lastStepStartTime!) > timeout;

    if (isTimedOut) {
      return LivenessStepResult(
        stage: _currentStage,
        stepCompleted: false,
        isTimedOut: true,
        isComplete: false,
      );
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
      if (_gestureCount < config.gestureConfirmations &&
          _challengeSequence.contains(_currentStage)) {
        return LivenessStepResult(
          stage: _currentStage,
          stepCompleted: false,
          isTimedOut: false,
          isComplete: false,
        );
      }

      _gestureCount = 0;
      _stepCounter++;

      if (_stepCounter >= _stepCounterCount(_currentStage)) {
        _advanceStage();
        _stepCounter = 0;
        _lastStepStartTime = DateTime.now();
      }
    }

    return LivenessStepResult(
      stage: _currentStage,
      stepCompleted: stepCompleted,
      isTimedOut: false,
      isComplete: _currentStage == KycFaceRecognitionStage.done,
    );
  }

  void _advanceStage() {
    if (_currentStage == KycFaceRecognitionStage.initial) {
      _currentStage = KycFaceRecognitionStage.detectFace;
    } else if (_currentStage == KycFaceRecognitionStage.detectFace) {
      if (_challengeSequence.isNotEmpty) {
        _currentStage = _challengeSequence[_challengeIndex];
        _challengeIndex++;
      } else {
        _currentStage = KycFaceRecognitionStage.done;
      }
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
        KycFaceRecognitionStage.initial => config.detectFaceTimeout,
        KycFaceRecognitionStage.detectFace => config.detectFaceTimeout,
        _ => config.stepTimeout,
      };
}
