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
}
