import 'package:roqqu_kyc/roqqu_kyc.dart';

class MockKycApiClient implements KycApiClient {
  @override
  Future<KycSession> createSession(
      {required String email, required String userId}) async {
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network
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
}
