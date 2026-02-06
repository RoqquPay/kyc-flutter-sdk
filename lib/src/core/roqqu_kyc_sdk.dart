part of '../../roqqu_kyc.dart';

class RoqquKycSdk {
  static final RoqquKycSdk _instance = RoqquKycSdk._internal();
  factory RoqquKycSdk() => _instance;
  RoqquKycSdk._internal();

  KycConfig _config = KycConfig(
    clearnessThreshold: 750,
    clearnessLowerThreshold: 450,
    livenessThreshold: 0.2,
    enableAntispoofing: true,
    maxFrameCount: 3,
    framePassPercentage: 0.6,
    debugMode: false,
    kycTestEmails: [],
  );
  KycApiClient? _apiClient; // Optional injected client

  /// Initialize the SDK with configuration
  void initialize({
    required KycConfig config,
    KycApiClient? apiClient,
  }) {
    _config = config;
    _apiClient = apiClient;
  }

  /// Start the verification flow
  void startVerification(
    BuildContext context, {
    required KycDelegate delegate,
    KycSession? session,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KycVerificationFlow(
          config: _config,
          delegate: delegate,
          apiClient: _apiClient,
          session: session,
        ),
      ),
    );
  }
}
