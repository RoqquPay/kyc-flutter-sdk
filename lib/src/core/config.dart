import '../models/enums.dart';

class KycConfig {
  KycConfig({
    this.challenges = const [
      KycFaceRecognitionStage.tiltLeft,
      KycFaceRecognitionStage.tiltRight,
      KycFaceRecognitionStage.smile,
      KycFaceRecognitionStage.mouthOpen,
    ],
    this.shuffleChallenges = true,
    this.enableAntispoofing = false,
    this.clearnessThreshold = 750,
    this.clearnessLowerThreshold = 450,
    this.livenessThreshold = 0.2,
    this.maxFrameCount = 3,
    this.framePassPercentage = 0.6,
    this.scanInterval = const Duration(milliseconds: 500),
    this.stepTimeout = const Duration(seconds: 20),
    this.detectFaceTimeout = const Duration(seconds: 60),
    this.gestureConfirmations = 2,
    this.captureStep,
    this.customModelPath,
  });

  /// The gesture challenges to present during liveness verification.
  ///
  /// Controls which face gestures the user must perform. Each stage maps to a
  /// specific action (tilt left, tilt right, smile, open mouth). The engine
  /// will cycle through these in order (or shuffled, if [shuffleChallenges]
  /// is true) after the initial face detection step.
  ///
  /// Defaults to all four gestures: tiltLeft, tiltRight, smile, mouthOpen.
  final List<KycFaceRecognitionStage> challenges;

  /// Whether to randomize the order of [challenges] each session.
  ///
  /// Shuffling makes it harder for pre-recorded videos to pass liveness
  /// checks, since the gesture order is unpredictable. The shuffle happens
  /// once when the engine starts or resets.
  ///
  /// Defaults to `true`.
  final bool shuffleChallenges;

  /// Whether to run TFLite anti-spoofing inference during face detection.
  ///
  /// When enabled, the engine runs a lightweight neural network on each
  /// frame during the `detectFace` step to estimate whether the face is
  /// from a live person or a photo/screen replay. Results are available
  /// in [KycLivenessState.spoofResult].
  ///
  /// Requires a bundled or custom TFLite model (see [customModelPath]).
  /// Defaults to `false`.
  final bool enableAntispoofing;

  /// Minimum image clarity score to consider a frame "clear enough" for
  /// anti-spoofing analysis.
  ///
  /// Higher values reject more blurry frames. The clearness score is
  /// computed from Laplacian variance of the cropped face region.
  /// Frames below this threshold are skipped for spoof evaluation.
  ///
  /// Defaults to `750`.
  final int clearnessThreshold;

  /// Lower bound for the clearness score.
  ///
  /// Frames with clarity below this value are considered too blurry to
  /// process at all — they won't contribute to spoof frame counting.
  /// Should be lower than [clearnessThreshold].
  ///
  /// Defaults to `450`.
  final int clearnessLowerThreshold;

  /// Minimum liveness confidence score (0.0 – 1.0) to classify a frame
  /// as "not spoofed".
  ///
  /// The TFLite model outputs a liveness probability. Frames scoring above
  /// this threshold count toward the [maxFrameCount] needed to pass.
  /// Lower values are more lenient; higher values are stricter.
  ///
  /// Defaults to `0.2`.
  final double livenessThreshold;

  /// Number of non-spoof frames required to pass anti-spoofing verification.
  ///
  /// During the `detectFace` step, the engine accumulates frames that pass
  /// both clearness and liveness checks. Once [maxFrameCount] qualifying
  /// frames are collected (subject to [framePassPercentage]), face detection
  /// is considered successful.
  ///
  /// Defaults to `3`.
  final int maxFrameCount;

  /// Minimum ratio of non-spoof frames to total analyzed frames required
  /// to pass anti-spoofing (0.0 – 1.0).
  ///
  /// Even if [maxFrameCount] good frames are collected, the overall pass
  /// rate must exceed this percentage. Helps catch intermittent spoofing
  /// where only some frames appear live.
  ///
  /// Defaults to `0.6` (60%).
  final double framePassPercentage;

  /// How often the engine processes a new camera frame for face analysis.
  ///
  /// Shorter intervals give faster feedback but use more CPU. On lower-end
  /// devices, increasing this can reduce heat and battery drain.
  ///
  /// Defaults to 500ms.
  final Duration scanInterval;

  /// Maximum time allowed for each gesture challenge step before it
  /// times out.
  ///
  /// If the user doesn't complete a gesture within this duration, the
  /// engine emits a timed-out state. The consumer can then decide to
  /// retry or abort.
  ///
  /// Defaults to 20 seconds.
  final Duration stepTimeout;

  /// Maximum time allowed specifically for the initial face detection
  /// step.
  ///
  /// Face detection typically needs more time than gesture steps since
  /// the user may need to adjust position, lighting, and distance.
  ///
  /// Defaults to 60 seconds.
  final Duration detectFaceTimeout;

  /// Number of consecutive frames where a gesture must be detected before
  /// the engine considers the step completed.
  ///
  /// Higher values reduce false positives (e.g., accidental smiles) but
  /// require the user to hold the gesture longer. A value of 1 means a
  /// single detection is enough.
  ///
  /// Defaults to `2`.
  final int gestureConfirmations;

  /// Which challenge step to capture the selfie image on.
  ///
  /// By default (`null`), the selfie is captured when the `detectFace` step
  /// passes. Set this to a gesture stage (e.g., [KycFaceRecognitionStage.smile])
  /// to capture the selfie at that moment instead — for example, a smiling
  /// photo makes a better impression.
  ///
  /// The step must be present in [challenges] or be `detectFace`, otherwise
  /// no selfie will be captured.
  ///
  /// Defaults to `null` (capture during `detectFace`).
  final KycFaceRecognitionStage? captureStep;

  /// Path to a custom TFLite anti-spoofing model file.
  ///
  /// When `null`, the engine uses the bundled `anti_spoof.tflite` model
  /// from the package assets. Provide a path to override with your own
  /// model — it must accept a 256x256x3 float32 input tensor and output
  /// a single float32 liveness probability.
  final String? customModelPath;

  KycConfig copyWith({
    List<KycFaceRecognitionStage>? challenges,
    bool? shuffleChallenges,
    bool? enableAntispoofing,
    int? clearnessThreshold,
    int? clearnessLowerThreshold,
    double? livenessThreshold,
    int? maxFrameCount,
    double? framePassPercentage,
    Duration? scanInterval,
    Duration? stepTimeout,
    Duration? detectFaceTimeout,
    int? gestureConfirmations,
    KycFaceRecognitionStage? captureStep,
    String? customModelPath,
  }) {
    return KycConfig(
      challenges: challenges ?? this.challenges,
      shuffleChallenges: shuffleChallenges ?? this.shuffleChallenges,
      enableAntispoofing: enableAntispoofing ?? this.enableAntispoofing,
      clearnessThreshold: clearnessThreshold ?? this.clearnessThreshold,
      clearnessLowerThreshold:
          clearnessLowerThreshold ?? this.clearnessLowerThreshold,
      livenessThreshold: livenessThreshold ?? this.livenessThreshold,
      maxFrameCount: maxFrameCount ?? this.maxFrameCount,
      framePassPercentage: framePassPercentage ?? this.framePassPercentage,
      scanInterval: scanInterval ?? this.scanInterval,
      stepTimeout: stepTimeout ?? this.stepTimeout,
      detectFaceTimeout: detectFaceTimeout ?? this.detectFaceTimeout,
      gestureConfirmations: gestureConfirmations ?? this.gestureConfirmations,
      captureStep: captureStep ?? this.captureStep,
      customModelPath: customModelPath ?? this.customModelPath,
    );
  }

  @override
  String toString() {
    return 'KycConfig(challenges: ${challenges.length}, antispoofing: $enableAntispoofing, '
        'clearness: $clearnessThreshold/$clearnessLowerThreshold, '
        'liveness: $livenessThreshold, frames: $maxFrameCount)';
  }
}
