import 'package:flutter_test/flutter_test.dart';
import 'package:kyc_engine/kyc_engine.dart';

void main() {
  group('LivenessSession', () {
    late LivenessSession session;

    setUp(() {
      session = LivenessSession(
        config: KycConfig(shuffleChallenges: false, gestureConfirmations: 1),
      );
    });

    test('start initializes properly', () {
      session.start();
      expect(session.currentStage, KycFaceRecognitionStage.initial);
      expect(session.sequence.length, 4);

      expect(session.sequence[0], KycFaceRecognitionStage.tiltLeft);
      expect(session.sequence[1], KycFaceRecognitionStage.tiltRight);
      expect(session.sequence[2], KycFaceRecognitionStage.smile);
      expect(session.sequence[3], KycFaceRecognitionStage.mouthOpen);
    });

    test('initial stage auto-progresses after 1 step', () {
      session.start();
      final face = KycDetectedFace.initial();
      final result = session.process(face);
      expect(result.stage, KycFaceRecognitionStage.detectFace);
    });

    test('detectFace progresses only on valid non-spoof face', () {
      session.start();
      session.process(KycDetectedFace.initial());

      final validFace = KycDetectedFace.initial().copyWith(
        faceIsWellPositioned: true,
        isBlinking: false,
        lookingAway: false,
      );

      final result = session.process(validFace);
      expect(result.stage, session.sequence.first);
    });

    test('completes all challenges in linear order', () {
      session.start();
      // -> detectFace
      session.process(KycDetectedFace.initial());
      // -> Challenge 1
      final validFace = KycDetectedFace.initial().copyWith(
        faceIsWellPositioned: true,
        isBlinking: false,
        lookingAway: false,
      );
      session.process(validFace);

      final sequence = [
        KycFaceRecognitionStage.tiltLeft,
        KycFaceRecognitionStage.tiltRight,
        KycFaceRecognitionStage.smile,
        KycFaceRecognitionStage.mouthOpen,
      ];

      for (final stage in sequence) {
        expect(session.currentStage, stage);
        final winningFace = _getWinningFace(stage);
        session.process(winningFace); // Step 1
        session.process(winningFace); // Step 2 -> Advance
      }

      expect(session.currentStage, KycFaceRecognitionStage.done);
    });

    test('process returns isComplete when done', () {
      session.start();
      session.process(KycDetectedFace.initial());

      final validFace = KycDetectedFace.initial().copyWith(
        faceIsWellPositioned: true,
        isBlinking: false,
        lookingAway: false,
      );
      session.process(validFace);

      late LivenessStepResult lastResult;
      for (final stage in session.sequence) {
        final winningFace = _getWinningFace(stage);
        session.process(winningFace);
        lastResult = session.process(winningFace);
      }

      expect(lastResult.isComplete, true);
    });

    test('custom challenges are respected', () {
      final customSession = LivenessSession(
        config: KycConfig(
          challenges: [KycFaceRecognitionStage.smile],
          shuffleChallenges: false,
        ),
      );
      customSession.start();

      expect(customSession.sequence, [KycFaceRecognitionStage.smile]);
    });
  });
}

KycDetectedFace _getWinningFace(KycFaceRecognitionStage stage) {
  final base = KycDetectedFace.initial();
  switch (stage) {
    case KycFaceRecognitionStage.smile:
      return base.copyWith(isSmiling: true);
    case KycFaceRecognitionStage.mouthOpen:
      return base.copyWith(isMouthOpen: true);
    case KycFaceRecognitionStage.tiltLeft:
      return base.copyWith(turnedLeft: true);
    case KycFaceRecognitionStage.tiltRight:
      return base.copyWith(turnedRight: true);
    default:
      return base;
  }
}
