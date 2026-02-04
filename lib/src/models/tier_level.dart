part of '../../roqqu_kyc.dart';

class KycTierLevel {
  const KycTierLevel({
    required this.level,
    required this.steps,
  });

  factory KycTierLevel.fromJson(Map<String, dynamic> map) {
    return KycTierLevel(
      level: map['level'] as int,
      steps: List<KycRequiredTierStep>.from(
        (map['steps'] as List<dynamic>).map<KycRequiredTierStep>(
          (x) => KycRequiredTierStep.fromJson(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  final int level;
  final List<KycRequiredTierStep> steps;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'level': level,
      'steps': steps.map((x) => x.toJson()).toList(),
    };
  }
}

class KycRequiredTierStep {
  const KycRequiredTierStep({
    required this.title,
    required this.status,
    required this.key,
    this.vid,
  });

  factory KycRequiredTierStep.fromJson(Map<String, dynamic> map) {
    return KycRequiredTierStep(
      key: map['key'] as String,
      vid: map['vid'] as String?,
      title: map['title'] as String,
      status: KycRequiredStepStatusString.fromString(map['status']),
    );
  }

  final String key;
  final String title;
  final String? vid;
  final KycRequiredStepStatus status;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'vid': vid,
      'title': title,
      'status': status.name,
    };
  }

  @override
  String toString() =>
      'KycRequiredStep(title: $title, status: $status, key: $key)';
}

enum KycTierRequirementKey { names, bvn, facemap, facematch, doc }

extension KycTierRequirementKeyString on KycTierRequirementKey {
  static KycTierRequirementKey fromString(String string) {
    if (string == 'names') return KycTierRequirementKey.names;
    if (string == 'bvn') return KycTierRequirementKey.bvn;
    if (string == 'facemap') return KycTierRequirementKey.facemap;
    if (string == 'facematch') return KycTierRequirementKey.facematch;
    if (string == 'doc') return KycTierRequirementKey.doc;
    return KycTierRequirementKey.doc;
  }
}

enum KycTierAction { startAction, redoAction, continueAction }

extension KycTierLevelState on KycTierLevel {
  bool get allStepsPending =>
      steps.every((step) => step.status == KycRequiredStepStatus.pending);

  bool get hasPendingStatus => steps.any(
        (step) =>
            step.status == KycRequiredStepStatus.pending &&
            step.status != KycRequiredStepStatus.rejected,
      );

  bool get hasRejectedStatus =>
      steps.any((step) => step.status == KycRequiredStepStatus.rejected);

  int getNextStepNumber() {
    return steps.indexWhere(
      (step) =>
          step.status != KycRequiredStepStatus.completed &&
          step.status != KycRequiredStepStatus.submitted,
    );
  }

  KycTierAction getAction() {
    if (allStepsPending) return KycTierAction.startAction;
    if (hasPendingStatus) return KycTierAction.continueAction;
    if (hasRejectedStatus) return KycTierAction.redoAction;
    return KycTierAction.startAction;
  }
}
