import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'kyc_feedback.dart';

class KycDetectedFace {
  const KycDetectedFace({
    required this.face,
    required this.faceIsWellPositioned,
    required this.isSmiling,
    required this.isFrowning,
    required this.turnedLeft,
    required this.turnedRight,
    required this.lookingAway,
    required this.isBlinking,
    required this.isMouthOpen,
    required this.isNodding,
    required this.isFaceCloseEnough,
    required this.feedback,
  });

  factory KycDetectedFace.initial() => const KycDetectedFace(
        face: null,
        faceIsWellPositioned: false,
        isSmiling: false,
        isFrowning: false,
        turnedLeft: false,
        turnedRight: false,
        lookingAway: false,
        isBlinking: false,
        isMouthOpen: false,
        isNodding: false,
        isFaceCloseEnough: false,
        feedback: KycFeedback.none,
      );
  final Face? face;
  final bool faceIsWellPositioned;
  final bool isSmiling;
  final bool isFrowning;
  final bool turnedLeft;
  final bool turnedRight;
  final bool lookingAway;
  final bool isBlinking;
  final bool isMouthOpen;
  final bool isNodding;
  final bool isFaceCloseEnough;
  final KycFeedback feedback;

  KycDetectedFace copyWith({
    Face? face,
    bool? faceIsWellPositioned,
    bool? isSmiling,
    bool? isFrowning,
    bool? turnedLeft,
    bool? turnedRight,
    bool? lookingAway,
    bool? isBlinking,
    bool? isMouthOpen,
    bool? isNodding,
    bool? isFaceCloseEnough,
    KycFeedback? feedback,
  }) =>
      KycDetectedFace(
        face: face ?? this.face,
        faceIsWellPositioned: faceIsWellPositioned ?? this.faceIsWellPositioned,
        isSmiling: isSmiling ?? this.isSmiling,
        isFrowning: isFrowning ?? this.isFrowning,
        turnedLeft: turnedLeft ?? this.turnedLeft,
        turnedRight: turnedRight ?? this.turnedRight,
        lookingAway: lookingAway ?? this.lookingAway,
        isBlinking: isBlinking ?? this.isBlinking,
        isMouthOpen: isMouthOpen ?? this.isMouthOpen,
        isNodding: isNodding ?? this.isNodding,
        isFaceCloseEnough: isFaceCloseEnough ?? this.isFaceCloseEnough,
        feedback: feedback ?? this.feedback,
      );
}

extension KycDetectedFaceExtension on KycDetectedFace {
  bool get faceFound {
    return faceIsWellPositioned || isFrowning || isSmiling;
  }
}
