part of '../../roqqu_kyc.dart';

/// Interface for backend communication
abstract class KycApiClient {
  /// Create a verification session
  Future<KycSession> createSession({
    required String email,
    required String userId,
  });

  /// Verify session validity
  Future<bool> verifySession(KycSession session);
}
