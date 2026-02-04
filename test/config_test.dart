import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

void main() {
  group('KycConfig', () {
    KycConfig createDefaultConfig({String? userEmail}) {
      return KycConfig(
        clearnessThreshold: 750,
        clearnessLowerThreshold: 450,
        livenessThreshold: 0.2,
        enableAntispoofing: true,
        maxFrameCount: 3,
        framePassPercentage: 0.6,
        debugMode: false,
        kycTestEmails: [],
        userEmail: userEmail,
      );
    }

    test('constructor creates instance with provided values', () {
      final config = createDefaultConfig();

      expect(config.clearnessThreshold, 750);
      expect(config.clearnessLowerThreshold, 450);
      expect(config.livenessThreshold, 0.2);
      expect(config.maxFrameCount, 3);
      expect(config.framePassPercentage, 0.6);
      expect(config.enableAntispoofing, true);
      expect(config.debugMode, false);
      expect(config.kycTestEmails, isEmpty);
    });

    test('copyWith creates new instance with updated values', () {
      final original = createDefaultConfig();

      final updated = original.copyWith(
        clearnessThreshold: 800,
        livenessThreshold: 0.3,
        debugMode: true,
      );

      expect(updated.clearnessThreshold, 800);
      expect(updated.livenessThreshold, 0.3);
      expect(updated.debugMode, true);

      expect(updated.maxFrameCount, original.maxFrameCount);
      expect(updated.framePassPercentage, original.framePassPercentage);
    });

    test('copyWith with no arguments returns equivalent config', () {
      final original = createDefaultConfig();
      final copy = original.copyWith();

      expect(copy.clearnessThreshold, original.clearnessThreshold);
      expect(copy.livenessThreshold, original.livenessThreshold);
      expect(copy.maxFrameCount, original.maxFrameCount);
    });

    test('fromJson parses configuration correctly', () {
      final json = {
        'clearness_threshold': 900,
        'clearness_lower_threshold': 500,
        'liveness_threshold': 0.25,
        'max_frame_count': 5,
        'frame_pass_percentage': 0.7,
        'enable_antispoofing': false,
        'debug_mode': true,
        'kyc_test_emails': ['test@example.com'],
      };

      final config = KycConfig.fromJson(json);

      expect(config.clearnessThreshold, 900);
      expect(config.clearnessLowerThreshold, 500);
      expect(config.livenessThreshold, 0.25);
      expect(config.maxFrameCount, 5);
      expect(config.framePassPercentage, 0.7);
      expect(config.enableAntispoofing, false);
      expect(config.debugMode, true);
      expect(config.kycTestEmails, ['test@example.com']);
    });

    test('fromJson uses defaults for missing keys', () {
      final json = <String, dynamic>{};
      final config = KycConfig.fromJson(json);

      expect(config.clearnessThreshold, 750);
      expect(config.clearnessLowerThreshold, 450);
      expect(config.livenessThreshold, 0.2);
      expect(config.maxFrameCount, 3);
    });

    test('fromJson handles null values gracefully', () {
      final json = {
        'clearness_threshold': null,
        'liveness_threshold': null,
      };

      final config = KycConfig.fromJson(json);

      expect(config.clearnessThreshold, 750);
      expect(config.livenessThreshold, 0.2);
    });

    test('fromJson parses emails from comma-separated string', () {
      final json = {
        'clearness_threshold': 750,
        'clearness_lower_threshold': 450,
        'liveness_threshold': 0.2,
        'enable_antispoofing': true,
        'max_frame_count': 3,
        'frame_pass_percentage': 0.6,
        'debug_mode': false,
        'kyc_test_emails': 'a@test.com, b@test.com',
      };

      final config = KycConfig.fromJson(json);

      expect(config.kycTestEmails, ['a@test.com', 'b@test.com']);
    });

    group('canTestKyc', () {
      test('returns false when userEmail is null', () {
        final config = KycConfig(
          clearnessThreshold: 750,
          clearnessLowerThreshold: 450,
          livenessThreshold: 0.2,
          enableAntispoofing: false,
          maxFrameCount: 3,
          framePassPercentage: 0.6,
          debugMode: true,
          kycTestEmails: ['test@example.com'],
          userEmail: null,
        );

        expect(config.canTestKyc, false);
      });

      test('returns false when debugMode is false', () {
        final config = KycConfig(
          clearnessThreshold: 750,
          clearnessLowerThreshold: 450,
          livenessThreshold: 0.2,
          enableAntispoofing: false,
          maxFrameCount: 3,
          framePassPercentage: 0.6,
          debugMode: false,
          kycTestEmails: ['test@example.com'],
          userEmail: 'test@example.com',
        );

        expect(config.canTestKyc, false);
      });

      test('returns true when debugMode is true and email matches', () {
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
      });

      test('email matching is case insensitive', () {
        final config = KycConfig(
          clearnessThreshold: 750,
          clearnessLowerThreshold: 450,
          livenessThreshold: 0.2,
          enableAntispoofing: false,
          maxFrameCount: 3,
          framePassPercentage: 0.6,
          debugMode: true,
          kycTestEmails: ['TEST@EXAMPLE.COM'],
          userEmail: 'test@example.com',
        );

        expect(config.canTestKyc, true);
      });
    });

    group('isAntispoofingEnabled', () {
      test('returns true when enableAntispoofing is true', () {
        final config = createDefaultConfig();
        expect(config.isAntispoofingEnabled, true);
      });

      test('returns true when canTestKyc is true', () {
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

        expect(config.isAntispoofingEnabled, true);
      });
    });

    test('toJson serializes correctly', () {
      final config = KycConfig(
        clearnessThreshold: 800,
        clearnessLowerThreshold: 500,
        livenessThreshold: 0.3,
        enableAntispoofing: true,
        maxFrameCount: 5,
        framePassPercentage: 0.7,
        debugMode: true,
        kycTestEmails: ['test@example.com'],
      );

      final json = config.toJson();

      expect(json['clearness_threshold'], 800);
      expect(json['liveness_threshold'], 0.3);
      expect(json['enable_antispoofing'], true);
      expect(json['max_frame_count'], 5);
      expect(json['frame_pass_percentage'], 0.7);
      expect(json['debug_mode'], true);
      expect(json['kyc_test_emails'], ['test@example.com']);
    });
  });
}
