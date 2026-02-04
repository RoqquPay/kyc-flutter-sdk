import 'package:flutter_test/flutter_test.dart';
import 'package:roqqu_kyc/roqqu_kyc.dart';

void main() {
  group('KycTierLevel', () {
    test('fromJson parses correctly', () {
      final json = {
        'level': 1,
        'steps': [
          {
            'title': 'BVN Verification',
            'status': 'pending',
            'key': 'bvn',
            'vid': '123'
          }
        ]
      };

      final tier = KycTierLevel.fromJson(json);
      expect(tier.level, 1);
      expect(tier.steps.length, 1);
      expect(tier.steps.first.title, 'BVN Verification');
      expect(tier.steps.first.status, KycRequiredStepStatus.pending);
    });

    test('getAction returns correct action', () {
      // All pending -> startAction
      final startTier = KycTierLevel(level: 1, steps: [
        KycRequiredTierStep(
            title: 'A', status: KycRequiredStepStatus.pending, key: 'a'),
        KycRequiredTierStep(
            title: 'B', status: KycRequiredStepStatus.pending, key: 'b'),
      ]);
      expect(startTier.getAction(), KycTierAction.startAction);

      // Mixed/Ongoing -> continueAction
      final continueTier = KycTierLevel(level: 1, steps: [
        KycRequiredTierStep(
            title: 'A', status: KycRequiredStepStatus.completed, key: 'a'),
        KycRequiredTierStep(
            title: 'B', status: KycRequiredStepStatus.pending, key: 'b'),
      ]);
      expect(continueTier.getAction(), KycTierAction.continueAction);

      // Rejected -> redoAction
      final redoTier = KycTierLevel(level: 1, steps: [
        KycRequiredTierStep(
            title: 'A', status: KycRequiredStepStatus.rejected, key: 'a'),
      ]);
      expect(redoTier.getAction(), KycTierAction.redoAction);
    });

    test('getNextStepNumber marks first non-complete step', () {
      final tier = KycTierLevel(level: 1, steps: [
        KycRequiredTierStep(
            title: 'A', status: KycRequiredStepStatus.completed, key: 'a'),
        KycRequiredTierStep(
            title: 'B', status: KycRequiredStepStatus.submitted, key: 'b'),
        KycRequiredTierStep(
            title: 'C', status: KycRequiredStepStatus.pending, key: 'c'),
      ]);
      // Should find index 2 (C)
      expect(tier.getNextStepNumber(), 2);
    });
  });

  group('KycDoc', () {
    test('serialization works', () {
      final doc = KycDoc(title: 'Passport', key: 'pp');
      final json = doc.toJson();
      expect(json['title'], 'Passport');

      final parsed = KycDoc.fromJson(json);
      expect(parsed, doc);
    });
  });

  group('KycRequiredMetaData', () {
    test('extractQueryParams parses required and metadata', () {
      const url =
          'https://kyc.roqqu.com?required=bvn,id&metadata=%7B%22identifier%22%3A%22user123%22%2C%22tier%22%3A%221%22%7D';

      final data = extractQueryParams(url);
      expect(data['required'], ['bvn', 'id']);
      expect(data['metadata']['identifier'], 'user123');
      expect(data['metadata']['tier'], '1');
    });

    test('fromJson validates structure', () {
      final json = {
        'required': ['bvn'],
        'metadata': {'identifier': '123', 'tier': '2'}
      };

      final meta = KycRequiredMetaData.fromJson(json);
      expect(meta.required, ['bvn']);
      expect(meta.metadata?.identifier, '123');
    });
  });
}
