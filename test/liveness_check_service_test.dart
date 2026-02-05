import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

void main() {
  group('LivenessCheckService', () {
    late LivenessCheckService service;

    setUp(() {
      service = LivenessCheckService();
    });

    test('start initializes properly', () {
      service.start();
      expect(service.currentStage, KycFaceRecognitionStage.initial);
      expect(service.sequence.length, 4);

      // Verify sequence is specific linear order
      expect(service.sequence[0], KycFaceRecognitionStage.tiltLeft);
      expect(service.sequence[1], KycFaceRecognitionStage.tiltRight);
      expect(service.sequence[2], KycFaceRecognitionStage.smile);
      expect(service.sequence[3], KycFaceRecognitionStage.mouthOpen);
    });

    test('initial stage auto-progresses after 1 step', () {
      service.start();
      final face = KycDetectedFace.initial();
      var stage = service.process(face, false);
      expect(stage, KycFaceRecognitionStage.detectFace);
    });

    test('detectFace progresses only on valid non-spoof face', () {
      service.start();
      service.process(KycDetectedFace.initial(), false);

      final validFace = KycDetectedFace.initial().copyWith(
        faceIsWellPositioned: true,
        isBlinking: false,
        lookingAway: false,
      );

      final stage = service.process(validFace, false);
      expect(stage, service.sequence.first); // Should be tiltLeft
    });

    test('Completes all challenges in linear order', () {
      service.start();
      // -> detectFace
      service.process(KycDetectedFace.initial(), false);
      // -> Challenge 1 (Tilt Left)
      var validFace = KycDetectedFace.initial().copyWith(
          faceIsWellPositioned: true, isBlinking: false, lookingAway: false);
      service.process(validFace, false);

      final sequence = [
        KycFaceRecognitionStage.tiltLeft,
        KycFaceRecognitionStage.tiltRight,
        KycFaceRecognitionStage.smile,
        KycFaceRecognitionStage.mouthOpen,
      ];

      for (final stage in sequence) {
        expect(service.currentStage, stage);
        final winningFace = _getWinningFace(stage);
        service.process(winningFace, false); // Step 1
        service.process(winningFace, false); // Step 2 -> Advance
      }

      expect(service.currentStage, KycFaceRecognitionStage.done);
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
