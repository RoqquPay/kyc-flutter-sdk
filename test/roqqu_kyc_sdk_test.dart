import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

// Mock Delegate
class MockKycDelegate implements KycDelegate {
  bool verified = false;
  Object? error;

  @override
  void onError(Object error) {
    this.error = error;
  }

  @override
  void onPending(String message) {}

  @override
  void onVerified(KycSession session) {
    verified = true;
  }
}

void main() {
  group('RoqquKycSdk', () {
    test('can create instance with config', () {
      final config = KycConfig(
        clearnessThreshold: 750,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.2,
        enableAntispoofing: true,
        maxFrameCount: 3,
        framePassPercentage: 0.6,
        debugMode: true,
        kycTestEmails: [],
      );

      final sdk = RoqquKycSdk(config: config);
      expect(sdk.config.clearnessThreshold, 750);
      expect(sdk.config.debugMode, true);
    });

    test('static initialize sets instance', () {
      final config = KycConfig(
        clearnessThreshold: 800,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.3,
        enableAntispoofing: false,
        maxFrameCount: 5,
        framePassPercentage: 0.7,
        debugMode: false,
        kycTestEmails: [],
      );

      RoqquKycSdk.initialize(config: config);

      expect(RoqquKycSdk.instance.config.clearnessThreshold, 800);
      expect(RoqquKycSdk.instance.config.enableAntispoofing, false);
      expect(RoqquKycSdk.instance.config.maxFrameCount, 5);
    });

    test('instance accepts optional apiClient', () {
      final config = KycConfig(
        clearnessThreshold: 750,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.2,
        enableAntispoofing: true,
        maxFrameCount: 3,
        framePassPercentage: 0.6,
        debugMode: false,
        kycTestEmails: [],
      );

      final sdk = RoqquKycSdk(config: config);
      expect(sdk.apiClient, isNull);
    });

    test('config can be updated after creation', () {
      final config = KycConfig(
        clearnessThreshold: 750,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.2,
        enableAntispoofing: true,
        maxFrameCount: 3,
        framePassPercentage: 0.6,
        debugMode: false,
        kycTestEmails: [],
      );

      final sdk = RoqquKycSdk(config: config);
      expect(sdk.config.debugMode, false);

      sdk.config = config.copyWith(debugMode: true);
      expect(sdk.config.debugMode, true);
    });
  });
}
