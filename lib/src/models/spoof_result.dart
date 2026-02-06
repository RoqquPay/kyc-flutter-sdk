import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Result of anti-spoofing inference on a single camera frame.
///
/// Contains the spoof/genuine classification along with quality metrics
/// (clearness and liveness scores) and optional face images. Use the
/// named constructors [spoofDetected], [genuine], and [skipped] for
/// common cases.
class KycSpoofResult extends Equatable {
  const KycSpoofResult({
    required this.isSpoof,
    this.message,
    this.croppedFaceImage,
    this.fullImage,
    this.clearnessScore,
    this.livenessScore,
    this.shouldAddToHistory = true,
  });

  factory KycSpoofResult.spoofDetected({String? message}) => KycSpoofResult(
        isSpoof: true,
        message: message ?? 'Possible spoofing detected',
      );

  factory KycSpoofResult.genuine({
    Uint8List? croppedFaceImage,
    Uint8List? fullImage,
    double? clearnessScore,
    double? livenessScore,
  }) =>
      KycSpoofResult(
        isSpoof: false,
        croppedFaceImage: croppedFaceImage,
        fullImage: fullImage,
        clearnessScore: clearnessScore,
        livenessScore: livenessScore,
      );

  factory KycSpoofResult.skipped() => const KycSpoofResult(
        isSpoof: true,
        shouldAddToHistory: false,
      );

  final bool isSpoof;
  final String? message;
  final Uint8List? croppedFaceImage;
  final Uint8List? fullImage;
  final double? clearnessScore;
  final double? livenessScore;
  final bool shouldAddToHistory;

  bool get hasGoodQuality => clearnessScore != null && clearnessScore! > 750;

  @override
  List<Object?> get props => [
        isSpoof,
        message,
        clearnessScore,
        livenessScore,
        shouldAddToHistory,
      ];

  @override
  String toString() {
    return 'KycSpoofResult(isSpoof: $isSpoof, clearness: $clearnessScore, liveness: $livenessScore)';
  }
}
