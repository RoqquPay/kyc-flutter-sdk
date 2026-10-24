import 'package:flutter_test/flutter_test.dart';
import 'package:kyc_engine/kyc_engine.dart';

void main() {
  group('KycConfig', () {
    test('constructor uses sensible defaults', () {
      final config = KycConfig();

      expect(config.clearnessThreshold, 750);
      expect(config.clearnessLowerThreshold, 450);
      expect(config.livenessThreshold, 0.2);
      expect(config.maxFrameCount, 3);
      expect(config.framePassPercentage, 0.6);
      expect(config.enableAntispoofing, false);
      expect(config.shuffleChallenges, true);
      expect(config.gestureConfirmations, 2);
      expect(config.scanInterval, const Duration(milliseconds: 500));
      expect(config.stepTimeout, const Duration(seconds: 20));
      expect(config.detectFaceTimeout, const Duration(seconds: 60));
      expect(config.customModelPath, isNull);
      expect(config.challenges, hasLength(4));
    });

    test('constructor accepts custom values', () {
      final config = KycConfig(
        clearnessThreshold: 800,
        enableAntispoofing: true,
        maxFrameCount: 5,
        shuffleChallenges: false,
        gestureConfirmations: 3,
        challenges: [KycFaceRecognitionStage.smile],
      );

      expect(config.clearnessThreshold, 800);
      expect(config.enableAntispoofing, true);
      expect(config.maxFrameCount, 5);
      expect(config.shuffleChallenges, false);
      expect(config.gestureConfirmations, 3);
      expect(config.challenges, [KycFaceRecognitionStage.smile]);
    });

    test('copyWith creates new instance with updated values', () {
      final original = KycConfig();

      final updated = original.copyWith(
        clearnessThreshold: 800,
        livenessThreshold: 0.3,
        enableAntispoofing: true,
      );

      expect(updated.clearnessThreshold, 800);
      expect(updated.livenessThreshold, 0.3);
      expect(updated.enableAntispoofing, true);

      // Unchanged values
      expect(updated.maxFrameCount, original.maxFrameCount);
      expect(updated.framePassPercentage, original.framePassPercentage);
      expect(updated.shuffleChallenges, original.shuffleChallenges);
    });

    test('copyWith with no arguments returns equivalent config', () {
      final original = KycConfig();
      final copy = original.copyWith();

      expect(copy.clearnessThreshold, original.clearnessThreshold);
      expect(copy.livenessThreshold, original.livenessThreshold);
      expect(copy.maxFrameCount, original.maxFrameCount);
      expect(copy.enableAntispoofing, original.enableAntispoofing);
    });

    test('default challenges include all four gestures', () {
      final config = KycConfig();

      expect(config.challenges, contains(KycFaceRecognitionStage.tiltLeft));
      expect(config.challenges, contains(KycFaceRecognitionStage.tiltRight));
      expect(config.challenges, contains(KycFaceRecognitionStage.smile));
      expect(config.challenges, contains(KycFaceRecognitionStage.mouthOpen));
    });

    test('toString provides useful summary', () {
      final config = KycConfig();
      final str = config.toString();

      expect(str, contains('KycConfig'));
      expect(str, contains('challenges: 4'));
      expect(str, contains('antispoofing: false'));
    });
  });
}
