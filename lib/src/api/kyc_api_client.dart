part of '../../roqqu_kyc.dart';

abstract class KycApiClient {
  Future<KycSession> createSession({
    required String email,
    required String userId,
  });

  Future<bool> verifySession(KycSession session);
}
