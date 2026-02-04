import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

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

    test('has descriptive labels', () {
      expect(KycFaceRecognitionStage.initial.label, 'face_within');
      expect(KycFaceRecognitionStage.smile.label, 'now_smile');
      expect(KycFaceRecognitionStage.done.label, 'done');
    });

    test('showFaceLandMark returns true only for initial stages', () {
      expect(KycFaceRecognitionStage.initial.showFaceLandMark, true);
      expect(KycFaceRecognitionStage.detectFace.showFaceLandMark, true);
      expect(KycFaceRecognitionStage.smile.showFaceLandMark, false);
      expect(KycFaceRecognitionStage.mouthOpen.showFaceLandMark, false);
      expect(KycFaceRecognitionStage.done.showFaceLandMark, false);
    });
  });

  group('KycVerStatus', () {
    test('byValue parses valid statuses', () {
      expect(KycVerStatus.byValue('verified'), KycVerStatus.verified);
      expect(KycVerStatus.byValue('awaiting_approval'),
          KycVerStatus.awaitingApproval);
      expect(KycVerStatus.byValue('ongoing'), KycVerStatus.ongoing);
      expect(KycVerStatus.byValue('facematch_failed'),
          KycVerStatus.faceMatchFailed);
      expect(KycVerStatus.byValue('rejected'), KycVerStatus.rejected);
    });

    test('byValue handles case insensitivity', () {
      expect(KycVerStatus.byValue('VERIFIED'), KycVerStatus.verified);
      expect(KycVerStatus.byValue('Ongoing'), KycVerStatus.ongoing);
    });

    test('byValue defaults to ongoing for unknown values', () {
      expect(KycVerStatus.byValue('unknown'), KycVerStatus.ongoing);
      expect(KycVerStatus.byValue(''), KycVerStatus.ongoing);
    });
  });

  group('KycAllowedId', () {
    test('fromKey parses document types', () {
      expect(
          KycAllowedId.fromKey('passport'), KycAllowedId.internationalPassport);
      expect(
          KycAllowedId.fromKey('driver-license'), KycAllowedId.driversLicense);
      expect(KycAllowedId.fromKey('national-id'), KycAllowedId.nationalId);
    });

    test('throws ArgumentError for unknown key', () {
      expect(() => KycAllowedId.fromKey('unknown'), throwsArgumentError);
    });

    test('has correct dimensions', () {
      expect(KycAllowedId.internationalPassport.width, 0.9);
      expect(KycAllowedId.internationalPassport.height, 0.3);
      expect(KycAllowedId.nationalId.height, 0.5);
    });
  });

  group('KycVerificationState', () {
    test('has correct step mapping', () {
      expect(KycVerificationState.checking.step, 0);
      expect(KycVerificationState.finalized.step, 5);
    });

    test('getNextStep returns correct next state', () {
      expect(
        KycVerificationState.getNextStep(0),
        KycVerificationState.preparing,
      );
      expect(
        KycVerificationState.getNextStep(4),
        KycVerificationState.finalized,
      );
      expect(
        KycVerificationState.getNextStep(5),
        null,
      );
    });

    test('getPreviousStep returns correct previous state', () {
      expect(
        KycVerificationState.getPreviousStep(1),
        KycVerificationState.checking,
      );
      expect(
        KycVerificationState.getPreviousStep(0),
        KycVerificationState.checking, // Returns first if at start
      );
    });
  });

  group('KycRequiredStepStatus', () {
    test('fromString parses statuses correctly', () {
      expect(
        KycRequiredStepStatusString.fromString('pending'),
        KycRequiredStepStatus.pending,
      );
      expect(
        KycRequiredStepStatusString.fromString('completed'),
        KycRequiredStepStatus.completed,
      );
      expect(
        KycRequiredStepStatusString.fromString('unknown'),
        KycRequiredStepStatus.pending,
      );
    });
  });
}
