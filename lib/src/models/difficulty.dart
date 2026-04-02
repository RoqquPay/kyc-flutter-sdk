import 'dart:math';

/// Controls how strictly the face detection and positioning checks are applied
/// during liveness verification.
///
/// Difficulty affects only the **detection sensitivity** — how forgiving or
/// strict the engine is when validating face position, eye state, and gesture
/// recognition. Session structure (which challenges to run, how many gesture
/// confirmations to require, anti-spoofing settings) is controlled separately
/// via [KycConfig].
///
/// The difficulty primarily targets the **initial `detectFace` step**, which
/// is where most users struggle. Gesture challenges (smile, tilt, mouth open)
/// are also adjusted, but more lightly.
///
/// Usage:
/// ```dart
/// KycEngine(
///   config: KycConfig(
///     difficulty: KycDifficulty.easy,
///   ),
/// );
/// ```
enum KycDifficulty {
  /// Maximum leniency for accessibility or assisted use cases.
  ///
  /// Designed for users who find the standard detection too strict — e.g.,
  /// elderly users, users with facial differences, or low-end devices with
  /// laggy ML inference.
  ///
  /// Changes from [normal]:
  /// - **Ear landmarks not required** — common blocker on front cameras.
  /// - **Much looser head rotation** — up to 20° yaw/roll before failing
  ///   the positioned check (vs 12°). Gestures tolerate up to 35°/30° pitch/roll.
  /// - **Face can be farther away** — minimum face size drops from 35%/33%
  ///   to 22%/20% of the frame.
  /// - **Eyes don't need to be fully open** — threshold drops from 50% to 30%.
  /// - **Blink detection is softer** — threshold 22% vs 40%.
  /// - **Weaker smiles accepted** — 38% probability vs 50%.
  /// - **Smaller mouth open accepted** — 5% lip gap vs 7% of face height.
  /// - **Looser center deviation** — face can be 32% off-center vs 20%.
  /// - **Looser looking-away check** — 28° roll vs 15°.
  veryEasy,

  /// Relaxed detection, suitable for a general consumer audience where
  /// completion rate matters more than strict liveness proof.
  ///
  /// Changes from [normal]:
  /// - **Ear landmarks not required** — same as [veryEasy].
  /// - **Looser head rotation** — 16° yaw/roll for positioned check; 28°/24°
  ///   pitch/roll for gesture detection.
  /// - **Face size minimum lowered** to 27%/25% of frame.
  /// - **Eye open threshold** drops to 40%.
  /// - **Blink threshold** drops to 30%.
  /// - **Smile threshold** drops to 44%.
  /// - **Mouth open threshold** drops to 6% lip gap.
  /// - **Center deviation** loosened to 26%.
  /// - **Looking-away threshold** raised to 22°.
  easy,

  /// The default mode. Matches the original hardcoded thresholds.
  ///
  /// - Head rotation: 12° yaw/roll for positioned check; 25°/20° pitch/roll
  ///   for gestures.
  /// - Face size: 35% width / 33% height minimum.
  /// - Eye open: 50% probability minimum.
  /// - Blink: fails if either eye below 40%.
  /// - Smile: 50% probability.
  /// - Mouth open: 7% lip gap / face height.
  /// - Center deviation: 20%.
  /// - Looking-away: 15° roll.
  /// - Ear landmark: at least one required.
  normal,

  /// Strictest mode. Useful for high-assurance verification flows or testing.
  ///
  /// Changes from [normal]:
  /// - **Both ear landmarks required** — face must be clearly facing forward.
  /// - **Tighter head rotation** — 8° yaw/roll for positioned check; 18°/13°
  ///   pitch/roll for gestures.
  /// - **Face must be close** — 42% width / 40% height minimum.
  /// - **Eyes must be clearly open** — 62% threshold.
  /// - **Blink threshold** tightened to 50%.
  /// - **Strong smile required** — 64% probability.
  /// - **Larger mouth opening required** — 9% lip gap.
  /// - **Tighter center deviation** — 14%.
  /// - **Stricter looking-away** — 10° roll.
  hard,
}

/// Internal preset values derived from [KycDifficulty].
///
/// Not exported from the public API — consumed only by [KycFaceDetectionService].
class KycDifficultySettings {
  const KycDifficultySettings({
    required this.maxYawForPositioned,
    required this.maxRollForPositioned,
    required this.maxDeviation,
    required this.lookingAwayThreshold,
    required this.faceWidthRatio,
    required this.faceHeightRatio,
    required this.eyeOpenProbability,
    required this.blinkThreshold,
    required this.smilingProbability,
    required this.mouthOpenThreshold,
    required this.minEarsRequired,
    required this.maxPitch,
    required this.maxRoll,
  });

  factory KycDifficultySettings.fromDifficulty(KycDifficulty difficulty) {
    return switch (difficulty) {
      KycDifficulty.veryEasy => const KycDifficultySettings(
          maxYawForPositioned: 20,
          maxRollForPositioned: 20,
          maxDeviation: 0.32,
          lookingAwayThreshold: 28,
          faceWidthRatio: 0.22,
          faceHeightRatio: 0.20,
          eyeOpenProbability: 0.30,
          blinkThreshold: 0.22,
          smilingProbability: 0.38,
          mouthOpenThreshold: 0.05,
          minEarsRequired: 0,
          maxPitch: 35,
          maxRoll: 30,
        ),
      KycDifficulty.easy => const KycDifficultySettings(
          maxYawForPositioned: 16,
          maxRollForPositioned: 16,
          maxDeviation: 0.26,
          lookingAwayThreshold: 22,
          faceWidthRatio: 0.27,
          faceHeightRatio: 0.25,
          eyeOpenProbability: 0.40,
          blinkThreshold: 0.30,
          smilingProbability: 0.44,
          mouthOpenThreshold: 0.06,
          minEarsRequired: 0,
          maxPitch: 28,
          maxRoll: 24,
        ),
      KycDifficulty.normal => const KycDifficultySettings(
          maxYawForPositioned: 12,
          maxRollForPositioned: 12,
          maxDeviation: 0.20,
          lookingAwayThreshold: 15,
          faceWidthRatio: 0.35,
          faceHeightRatio: 0.33,
          eyeOpenProbability: 0.50,
          blinkThreshold: 0.40,
          smilingProbability: 0.50,
          mouthOpenThreshold: 0.07,
          minEarsRequired: 1,
          maxPitch: 25,
          maxRoll: 20,
        ),
      KycDifficulty.hard => const KycDifficultySettings(
          maxYawForPositioned: 8,
          maxRollForPositioned: 8,
          maxDeviation: 0.14,
          lookingAwayThreshold: 10,
          faceWidthRatio: 0.42,
          faceHeightRatio: 0.40,
          eyeOpenProbability: 0.62,
          blinkThreshold: 0.50,
          smilingProbability: 0.64,
          mouthOpenThreshold: 0.09,
          minEarsRequired: 2,
          maxPitch: 18,
          maxRoll: 13,
        ),
    };
  }

  /// Max head yaw (left/right) to be considered well-positioned for detectFace.
  final double maxYawForPositioned;

  /// Max head roll (tilt) to be considered well-positioned for detectFace.
  final double maxRollForPositioned;

  /// Max face-center offset as a fraction of the shortest frame dimension.
  final double maxDeviation;

  /// Min roll angle to trigger the "looking away" flag.
  final double lookingAwayThreshold;

  /// Min face bounding box width as a fraction of the frame width.
  final double faceWidthRatio;

  /// Min face bounding box height as a fraction of the frame height.
  final double faceHeightRatio;

  /// Min eye-open probability for each eye to pass the positioned check.
  final double eyeOpenProbability;

  /// Max eye-open probability before an eye is considered blinking.
  final double blinkThreshold;

  /// Min smile probability to detect the smile gesture.
  final double smilingProbability;

  /// Min normalized lip gap (lip distance / face height) to detect open mouth.
  final double mouthOpenThreshold;

  /// How many ear landmarks must be detected for the face to be well-positioned.
  /// 0 = no ears required, 1 = at least one, 2 = both.
  final int minEarsRequired;

  /// Max pitch (up/down) for the gesture-step in-frame check.
  final double maxPitch;

  /// Max roll (tilt) for the gesture-step in-frame check.
  final double maxRoll;

  /// Whether the ear landmark requirement is satisfied given detected ear counts.
  bool earsAreSatisfied({required bool hasLeft, required bool hasRight}) {
    final count = (hasLeft ? 1 : 0) + (hasRight ? 1 : 0);
    return count >= min(minEarsRequired, 2);
  }
}
