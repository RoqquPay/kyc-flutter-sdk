import 'package:roqqu_kyc/roqqu_kyc.dart';

class MockKycApiClient implements KycApiClient {
  @override
  Future<KycSession> createSession({
    required String email,
    required String userId,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return KycSession(
      sessionId: 'mock_session_${DateTime.now().millisecondsSinceEpoch}',
      token: 'mock_token',
      expiry: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<bool> verifySession(KycSession session) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return session.isValid;
  }

  @override
  Future<KycRequiredMetaData> getKycMetadata({
    required String token,
    required int level,
  }) async {
    throw UnimplementedError('Mock: getKycMetadata not implemented');
  }

  @override
  Future<String> createVerificationIdentifier({
    required String token,
    KycRequiredMetaData? metadata,
  }) async {
    throw UnimplementedError('Mock: createVerificationIdentifier not implemented');
  }

  @override
  Future<KycVerStatus> checkVerificationStatus({required String vid}) async {
    throw UnimplementedError('Mock: checkVerificationStatus not implemented');
  }

  @override
  Future<void> validateBvn({
    required String bvn,
    required String vid,
    required String firstName,
    required String lastName,
  }) async {
    throw UnimplementedError('Mock: validateBvn not implemented');
  }

  @override
  Future<List<KycDoc>> getAllowedDocuments({required String countryCode}) async {
    throw UnimplementedError('Mock: getAllowedDocuments not implemented');
  }

  @override
  Future<void> uploadDocument({
    required String vid,
    required String docType,
    required String filePath,
  }) async {
    throw UnimplementedError('Mock: uploadDocument not implemented');
  }

  @override
  Future<void> uploadFaceMatch({
    required String vid,
    required String filePath,
    String? videoTimestamp,
  }) async {
    throw UnimplementedError('Mock: uploadFaceMatch not implemented');
  }

  @override
  Future<List<KycTierLevel>> getTierLevels({required String token}) async {
    throw UnimplementedError('Mock: getTierLevels not implemented');
  }

  @override
  Future<void> reportSpoof({required String vid}) async {
    throw UnimplementedError('Mock: reportSpoof not implemented');
  }

  @override
  Future<void> resetVerification({required String vid}) async {
    throw UnimplementedError('Mock: resetVerification not implemented');
  }
}
