part of '../../roqqu_kyc.dart';

/// Delegate for handling KYC flow callbacks
abstract class KycDelegate {
  /// Called when verification is completed successfully
  void onVerified(KycSession session);

  /// Called when an error occurs
  void onError(Object error);

  /// Called when user cancels or pending state is reached
  void onPending(String message);
}
