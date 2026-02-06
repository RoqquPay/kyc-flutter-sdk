class KycConfig {
  KycConfig({
    required this.clearnessThreshold,
    required this.clearnessLowerThreshold,
    required this.livenessThreshold,
    required this.enableAntispoofing,
    required this.maxFrameCount,
    required this.framePassPercentage,
    required this.debugMode,
    required this.kycTestEmails,
    this.userEmail,
  });

  factory KycConfig.fromJson(Map<String, dynamic> json) {
    List<String> parseEmails(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) {
        return value.split(',').map((e) => e.trim()).toList();
      }
      return [];
    }

    return KycConfig(
      clearnessThreshold: (json['clearness_threshold'] as num?)?.toInt() ?? 750,
      clearnessLowerThreshold:
          (json['clearness_lower_threshold'] as num?)?.toInt() ?? 450,
      livenessThreshold:
          (json['liveness_threshold'] as num?)?.toDouble() ?? 0.2,
      enableAntispoofing: json['enable_antispoofing'] as bool? ?? false,
      maxFrameCount: (json['max_frame_count'] as num?)?.toInt() ?? 3,
      framePassPercentage:
          (json['frame_pass_percentage'] as num?)?.toDouble() ?? 0.6,
      debugMode: json['debug_mode'] as bool? ?? false,
      kycTestEmails: parseEmails(json['kyc_test_emails']),
    );
  }

  final int clearnessThreshold;
  final int clearnessLowerThreshold;
  final double livenessThreshold;
  final bool enableAntispoofing;
  final bool debugMode;
  final int maxFrameCount;
  final double framePassPercentage;
  final List<String> kycTestEmails;
  final String? userEmail;

  bool get isAntispoofingEnabled => enableAntispoofing || canTestKyc;

  bool get canTestKyc {
    if (userEmail == null) {
      return false;
    }

    return debugMode &&
        kycTestEmails
            .map((email) => email.toLowerCase().trim())
            .contains(userEmail!.toLowerCase().trim());
  }

  KycConfig copyWith({
    int? clearnessThreshold,
    int? clearnessLowerThreshold,
    double? livenessThreshold,
    bool? enableAntispoofing,
    bool? debugMode,
    int? maxFrameCount,
    double? framePassPercentage,
    List<String>? kycTestEmails,
  }) {
    return KycConfig(
      clearnessThreshold: clearnessThreshold ?? this.clearnessThreshold,
      clearnessLowerThreshold:
          clearnessLowerThreshold ?? this.clearnessLowerThreshold,
      livenessThreshold: livenessThreshold ?? this.livenessThreshold,
      enableAntispoofing: enableAntispoofing ?? this.enableAntispoofing,
      maxFrameCount: maxFrameCount ?? this.maxFrameCount,
      framePassPercentage: framePassPercentage ?? this.framePassPercentage,
      debugMode: debugMode ?? this.debugMode,
      kycTestEmails: kycTestEmails ?? this.kycTestEmails,
    );
  }

  Map<String, dynamic> toJson() => {
        'clearness_threshold': clearnessThreshold,
        'liveness_threshold': livenessThreshold,
        'enable_antispoofing': enableAntispoofing,
        'max_frame_count': maxFrameCount,
        'frame_pass_percentage': framePassPercentage,
        'debug_mode': debugMode,
        'kyc_test_emails': kycTestEmails,
      };

  @override
  String toString() {
    return '$clearnessThreshold, $livenessThreshold, $enableAntispoofing, $maxFrameCount, $framePassPercentage, $debugMode, $kycTestEmails';
  }
}
