import '../api/kyc_api_client.dart';
import 'config.dart';

class RoqquKycSdk {
  RoqquKycSdk({required this.config, this.apiClient});

  KycConfig config;
  KycApiClient? apiClient;

  /// Optional convenience singleton for apps that only need one instance.
  static RoqquKycSdk? _instance;

  static RoqquKycSdk get instance {
    assert(_instance != null, 'RoqquKycSdk.initialize() must be called first.');
    return _instance!;
  }

  static void initialize({
    required KycConfig config,
    KycApiClient? apiClient,
  }) {
    _instance = RoqquKycSdk(config: config, apiClient: apiClient);
  }

}
