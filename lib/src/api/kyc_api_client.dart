import '../models/doc.dart';
import '../models/enums.dart';
import '../models/required_metadata.dart';
import '../models/session.dart';
import '../models/tier_level.dart';

abstract class KycApiClient {
  // Session management
  Future<KycSession> createSession({
    required String email,
    required String userId,
  });

  Future<bool> verifySession(KycSession session);

  // KYC metadata & verification
  Future<KycRequiredMetaData> getKycMetadata({
    required String token,
    required int level,
  });

  Future<String> createVerificationIdentifier({
    required String token,
    KycRequiredMetaData? metadata,
  });

  Future<KycVerStatus> checkVerificationStatus({required String vid});

  // BVN
  Future<void> validateBvn({
    required String bvn,
    required String vid,
    required String firstName,
    required String lastName,
  });

  // Documents
  Future<List<KycDoc>> getAllowedDocuments({required String countryCode});

  Future<void> uploadDocument({
    required String vid,
    required String docType,
    required String filePath,
  });

  // Face match
  Future<void> uploadFaceMatch({
    required String vid,
    required String filePath,
    String? videoTimestamp,
  });

  // Tiers
  Future<List<KycTierLevel>> getTierLevels({required String token});

  // Spoofing report
  Future<void> reportSpoof({required String vid});

  // Reset verification
  Future<void> resetVerification({required String vid});
}
