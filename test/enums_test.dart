import 'package:flutter_test/flutter_test.dart';
import 'package:kyc_engine/kyc_engine.dart';

void main() {
  group('KycFaceRecognitionStage', () {
    test('has correct step order', () {
      expect(KycFaceRecognitionStage.initial.step, 0);
      expect(KycFaceRecognitionStage.detectFace.step, 1);
      expect(KycFaceRecognitionStage.tiltLeft.step, 2);
      expect(KycFaceRecognitionStage.tiltRight.step, 3);
      expect(KycFaceRecognitionStage.smile.step, 4);
      expect(KycFaceRecognitionStage.mouthOpen.step, 5);
      expect(KycFaceRecognitionStage.stayStill.step, 6);
      expect(KycFaceRecognitionStage.done.step, 7);
    });

    test('showFaceLandMark returns true only for initial stages', () {
      expect(KycFaceRecognitionStage.initial.showFaceLandMark, true);
      expect(KycFaceRecognitionStage.detectFace.showFaceLandMark, true);
      expect(KycFaceRecognitionStage.smile.showFaceLandMark, false);
      expect(KycFaceRecognitionStage.mouthOpen.showFaceLandMark, false);
      expect(KycFaceRecognitionStage.done.showFaceLandMark, false);
    });

    test('getNextStep returns correct next state', () {
      expect(
        KycFaceRecognitionStage.getNextStep(0),
        KycFaceRecognitionStage.detectFace,
      );
      expect(
        KycFaceRecognitionStage.getNextStep(6),
        KycFaceRecognitionStage.done,
      );
      expect(
        KycFaceRecognitionStage.getNextStep(7),
        null,
      );
    });

    test('getPreviousStep returns correct previous state', () {
      expect(
        KycFaceRecognitionStage.getPreviousStep(1),
        KycFaceRecognitionStage.initial,
      );
      expect(
        KycFaceRecognitionStage.getPreviousStep(0),
        KycFaceRecognitionStage.initial,
      );
    });

    test('progress returns correct values', () {
      expect(KycFaceRecognitionStage.initial.progress, 0);
      expect(KycFaceRecognitionStage.done.progress, 1);
      expect(KycFaceRecognitionStage.stayStill.progress, 1);
    });

    test('isStayStill is correct', () {
      expect(KycFaceRecognitionStage.stayStill.isStayStill, true);
      expect(KycFaceRecognitionStage.smile.isStayStill, false);
    });

    test('label returns non-empty string for all stages', () {
      for (final stage in KycFaceRecognitionStage.values) {
        expect(stage.label, isNotEmpty);
      }
    });
  });
}
