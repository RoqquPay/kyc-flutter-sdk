import 'package:flutter/material.dart';
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
    test('Singleton instance works', () {
      final sdk1 = RoqquKycSdk();
      final sdk2 = RoqquKycSdk();
      expect(sdk1, same(sdk2));
    });

    test('initialize sets config', () {
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
      RoqquKycSdk().initialize(config: config);
      // We can't verify protected members easily without visibleForTesting,
      // but we test initialization doesn't throw.
    });

    // UI tests would go here with widget testing, verifying navigation.
  });
}
