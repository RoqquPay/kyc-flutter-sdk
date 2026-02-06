import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

KycConfig _makeConfig({
  int clearnessThreshold = 750,
  int clearnessLowerThreshold = 450,
  double livenessThreshold = 0.2,
  bool enableAntispoofing = true,
  int maxFrameCount = 3,
  double framePassPercentage = 0.6,
}) {
  return KycConfig(
    clearnessThreshold: clearnessThreshold,
    clearnessLowerThreshold: clearnessLowerThreshold,
    livenessThreshold: livenessThreshold,
    enableAntispoofing: enableAntispoofing,
    maxFrameCount: maxFrameCount,
    framePassPercentage: framePassPercentage,
    debugMode: false,
    kycTestEmails: [],
  );
}

void main() {
  group('KycSpoofResult', () {
    test('spoofDetected factory creates spoof result', () {
      final result = KycSpoofResult.spoofDetected();
      expect(result.isSpoof, true);
      expect(result.message, 'Possible spoofing detected');
      expect(result.shouldAddToHistory, true);
    });

    test('spoofDetected factory accepts custom message', () {
      final result = KycSpoofResult.spoofDetected(message: 'Custom message');
      expect(result.isSpoof, true);
      expect(result.message, 'Custom message');
    });

    test('genuine factory creates non-spoof result', () {
      final result = KycSpoofResult.genuine(
        clearnessScore: 900.0,
        livenessScore: 0.1,
      );
      expect(result.isSpoof, false);
      expect(result.clearnessScore, 900.0);
      expect(result.livenessScore, 0.1);
      expect(result.shouldAddToHistory, true);
    });

    test('skipped factory creates non-history result', () {
      final result = KycSpoofResult.skipped();
      expect(result.isSpoof, true);
      expect(result.shouldAddToHistory, false);
    });

    test('hasGoodQuality returns true above threshold', () {
      final good = KycSpoofResult.genuine(clearnessScore: 800.0);
      final bad = KycSpoofResult.genuine(clearnessScore: 500.0);
      final noScore = KycSpoofResult.genuine();

      expect(good.hasGoodQuality, true);
      expect(bad.hasGoodQuality, false);
      expect(noScore.hasGoodQuality, false);
    });

    test('equatable works correctly', () {
      final a = KycSpoofResult.spoofDetected(message: 'test');
      final b = KycSpoofResult.spoofDetected(message: 'test');
      expect(a, equals(b));
    });
  });

  group('KycAntiSpoofingIsolateService', () {
    test('disabled config returns isSpoof false immediately', () async {
      final config = _makeConfig(enableAntispoofing: false);
      final service = KycAntiSpoofingIsolateService(config);

      // isPossibleSpoof should return false with no data
      expect(service.isPossibleSpoof(), false);
    });

    test('frame counters start at zero', () {
      final config = _makeConfig();
      final service = KycAntiSpoofingIsolateService(config);

      expect(service.totalFrameCount, 0);
      expect(service.nonSpoofFrameCount, 0);
      expect(service.spoofFrameCount, 0);
    });

    test('resetState clears all history', () {
      final config = _makeConfig();
      final service = KycAntiSpoofingIsolateService(config);

      // Service starts clean
      expect(service.totalFrameCount, 0);
      expect(service.isPossibleSpoof(), false);

      service.resetState();

      expect(service.totalFrameCount, 0);
      expect(service.isPossibleSpoof(), false);
    });

    test('isPossibleSpoof returns false with no steps', () {
      final config = _makeConfig();
      final service = KycAntiSpoofingIsolateService(config);

      expect(service.isPossibleSpoof(), false);
    });
  });

  group('KycConfig anti-spoofing settings', () {
    test('enableAntispoofing defaults to false in fromJson', () {
      final config = KycConfig.fromJson({});
      expect(config.enableAntispoofing, false);
      expect(config.isAntispoofingEnabled, false);
    });

    test('isAntispoofingEnabled reflects enableAntispoofing', () {
      final enabled = _makeConfig(enableAntispoofing: true);
      final disabled = _makeConfig(enableAntispoofing: false);

      expect(enabled.isAntispoofingEnabled, true);
      expect(disabled.isAntispoofingEnabled, false);
    });

    test('canTestKyc enables antispoofing for test emails', () {
      final config = KycConfig(
        clearnessThreshold: 750,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.2,
        enableAntispoofing: false,
        maxFrameCount: 3,
        framePassPercentage: 0.6,
        debugMode: true,
        kycTestEmails: ['test@example.com'],
        userEmail: 'test@example.com',
      );

      expect(config.canTestKyc, true);
      expect(config.isAntispoofingEnabled, true);
    });

    test('threshold defaults are sensible', () {
      final config = KycConfig.fromJson({});
      expect(config.clearnessThreshold, 750);
      expect(config.clearnessLowerThreshold, 450);
      expect(config.livenessThreshold, 0.2);
      expect(config.maxFrameCount, 3);
      expect(config.framePassPercentage, 0.6);
    });

    test('custom thresholds from JSON', () {
      final config = KycConfig.fromJson({
        'clearness_threshold': 1000,
        'liveness_threshold': 0.3,
        'enable_antispoofing': true,
        'max_frame_count': 5,
        'frame_pass_percentage': 0.7,
      });

      expect(config.clearnessThreshold, 1000);
      expect(config.livenessThreshold, 0.3);
      expect(config.enableAntispoofing, true);
      expect(config.maxFrameCount, 5);
      expect(config.framePassPercentage, 0.7);
    });
  });
}
