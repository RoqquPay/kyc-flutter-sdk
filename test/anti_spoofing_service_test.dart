import 'package:flutter_test/flutter_test.dart';
import 'package:kyc_engine/kyc_engine.dart';

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
    test('disabled config returns isPossibleSpoof false', () {
      final config = KycConfig(enableAntispoofing: false);
      final service = KycAntiSpoofingIsolateService(config);

      expect(service.isPossibleSpoof(), false);
    });

    test('frame counters start at zero', () {
      final config = KycConfig(enableAntispoofing: true);
      final service = KycAntiSpoofingIsolateService(config);

      expect(service.totalFrameCount, 0);
      expect(service.nonSpoofFrameCount, 0);
      expect(service.spoofFrameCount, 0);
    });

    test('resetState clears all history', () {
      final config = KycConfig(enableAntispoofing: true);
      final service = KycAntiSpoofingIsolateService(config);

      expect(service.totalFrameCount, 0);
      expect(service.isPossibleSpoof(), false);

      service.resetState();

      expect(service.totalFrameCount, 0);
      expect(service.isPossibleSpoof(), false);
    });
  });
}
