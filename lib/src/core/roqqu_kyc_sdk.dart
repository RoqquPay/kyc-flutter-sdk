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

  /// Current Configuration
  KycConfig get config => _config;

  /// Current API Client
  KycApiClient? get apiClient => _apiClient;
}
