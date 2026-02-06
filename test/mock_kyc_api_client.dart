import 'package:roqqu_kyc/roqqu_kyc.dart';

class MockKycApiClient implements KycApiClient {
  @override
  Future<KycSession> createSession(
      {required String email, required String userId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return KycSession(
      sessionId: 'mock_session_123',
      token: 'mock_token_abc',
      expiry: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<bool> verifySession(KycSession session) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return session.isValid;
  }

  @override
  Future<KycRequiredMetaData> getKycMetadata({
    required String token,
    required int level,
  }) async {
    return const KycRequiredMetaData(required: ['bvn', 'facematch']);
  }

  @override
  Future<String> createVerificationIdentifier({
    required String token,
    KycRequiredMetaData? metadata,
  }) async {
    return 'mock_vid_456';
  }

  @override
  Future<KycVerStatus> checkVerificationStatus({required String vid}) async {
    return KycVerStatus.ongoing;
  }

  @override
  Future<void> validateBvn({
    required String bvn,
    required String vid,
    required String firstName,
    required String lastName,
  }) async {}

  @override
  Future<List<KycDoc>> getAllowedDocuments({required String countryCode}) async {
    return const [
      KycDoc(title: 'NIN Slip', key: 'nin'),
      KycDoc(title: 'National ID', key: 'national-id'),
    ];
  }

  @override
  Future<void> uploadDocument({
    required String vid,
    required String docType,
    required String filePath,
  }) async {}

  @override
  Future<void> uploadFaceMatch({
    required String vid,
    required String filePath,
    String? videoTimestamp,
  }) async {}

  @override
  Future<List<KycTierLevel>> getTierLevels({required String token}) async {
    return [
      KycTierLevel.fromJson({
        'level': 1,
        'steps': [
          {'key': 'bvn', 'title': 'BVN Verification', 'status': 'pending'},
        ],
      }),
    ];
  }

  @override
  Future<void> reportSpoof({required String vid}) async {}

  @override
  Future<void> resetVerification({required String vid}) async {}
}
