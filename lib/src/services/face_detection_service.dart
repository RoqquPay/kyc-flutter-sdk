import 'dart:math';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/config.dart';
import '../models/detected_face.dart';
import '../models/kyc_feedback.dart';

class KycFaceDetectionService {
  KycFaceDetectionService({FaceDetector? detector})
      : _detector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                enableLandmarks: true,
                enableClassification: true,
                enableContours: true,
                performanceMode: FaceDetectorMode.accurate,
                enableTracking: true,
              ),
            );

  final FaceDetector _detector;

  static const double _faceTurnThreshold = 12.0;

  Future<void> dispose() async {
    await _detector.close();
  }

  /// Process an [InputImage] and return a [KycDetectedFace] with analysis.
  ///
  /// [rotation] is used to determine if left/right turn detection should
  /// be inverted (required on some device/camera rotation combos).
  Future<KycDetectedFace> processImage(
    InputImage inputImage,
    KycConfig config, {
    InputImageRotation? rotation,
  }) async {
    try {
      final faces = await _detector.processImage(inputImage);

      if (faces.isEmpty) {
        return KycDetectedFace.initial();
      }

      // Select the most prominent face (largest bounding box)
      final face = faces.reduce((curr, next) {
        final currArea = curr.boundingBox.width * curr.boundingBox.height;
        final nextArea = next.boundingBox.width * next.boundingBox.height;
        return currArea > nextArea ? curr : next;
      });

      return _analyzeFace(face, config, inputImage.metadata?.size, rotation);
    } catch (e) {
      return KycDetectedFace.initial();
    }
  }

  KycDetectedFace _analyzeFace(
    Face face,
    KycConfig config,
    Size? imageSize,
    InputImageRotation? rotation,
  ) {
    bool faceIsWellPositioned = true;
    bool isFaceCloseEnough = true;

    if (imageSize != null) {
      isFaceCloseEnough = _isFaceCloseEnough(face, imageSize);

      final faceCenter = face.boundingBox.center;
      final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
      final distanceFromCenter = (faceCenter - imageCenter).distance;
      final maxDeviation = min(imageSize.width, imageSize.height) * 0.2;

      faceIsWellPositioned = distanceFromCenter < maxDeviation;
    }

    // Check essential landmarks are present
    final hasEssentialLandmarks = face.landmarks[FaceLandmarkType.leftEar] != null &&
        face.landmarks[FaceLandmarkType.rightEar] != null &&
        face.landmarks[FaceLandmarkType.bottomMouth] != null &&
        face.landmarks[FaceLandmarkType.rightMouth] != null &&
        face.landmarks[FaceLandmarkType.leftMouth] != null &&
        face.landmarks[FaceLandmarkType.noseBase] != null;

    if (!hasEssentialLandmarks) {
      faceIsWellPositioned = false;
    }

    // Check head rotation for well-positioned
    if ((face.headEulerAngleY ?? 0).abs() > 2 ||
        (face.headEulerAngleZ ?? 0).abs() > 2) {
      faceIsWellPositioned = false;
    }

    // Check eyes open for well-positioned
    if (face.leftEyeOpenProbability != null && face.leftEyeOpenProbability! < 0.5) {
      faceIsWellPositioned = false;
    }
    if (face.rightEyeOpenProbability != null && face.rightEyeOpenProbability! < 0.5) {
      faceIsWellPositioned = false;
    }

    // Determine left/right turn with rotation-aware inversion
    final double eulerY = face.headEulerAngleY ?? 0;
    final bool shouldInvert = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation0deg ||
        rotation == InputImageRotation.rotation180deg;

    final bool turnedLeft = shouldInvert
        ? (eulerY < -_faceTurnThreshold)
        : (eulerY > _faceTurnThreshold);

    final bool turnedRight = shouldInvert
        ? (eulerY > _faceTurnThreshold)
        : (eulerY < -_faceTurnThreshold);

    final lookingAway = (face.headEulerAngleZ ?? 0).abs() > 5;

    final bool isFrowning =
        face.smilingProbability != null && face.smilingProbability! < 0.3;

    // Eye blink detection
    bool isBlinking = false;
    final leftProb = face.leftEyeOpenProbability;
    final rightProb = face.rightEyeOpenProbability;
    if ((leftProb != null && leftProb < 0.4) ||
        (rightProb != null && rightProb < 0.4)) {
      isBlinking = true;
    }

    // Gate smile behind isFaceInFrame (with eye landmarks)
    final bool isSmiling = _isFaceInFrame(
              face,
              extraLandmarks: [FaceLandmarkType.leftEye, FaceLandmarkType.rightEye],
            ) &&
        (face.smilingProbability ?? 0) > 0.5;

    // Gate mouth open behind isFaceInFrame (with eye landmarks)
    bool isMouthOpen = false;
    if (_isFaceInFrame(
      face,
      extraLandmarks: [FaceLandmarkType.leftEye, FaceLandmarkType.rightEye],
    )) {
      isMouthOpen = _detectMouthOpen(face);
    }

    // Gate turnedLeft/Right behind isFaceInFrame (with relaxed yaw)
    final bool guardedTurnedLeft =
        _isFaceInFrame(face, maxYaw: 60) && turnedLeft;
    final bool guardedTurnedRight =
        _isFaceInFrame(face, maxYaw: 60) && turnedRight;

    final isNodding = false;

    KycFeedback feedback = KycFeedback.none;

    if (!isFaceCloseEnough) {
      feedback = KycFeedback.moveCloser;
    } else if (!faceIsWellPositioned) {
      feedback = KycFeedback.faceNotCentered;
    } else if (guardedTurnedLeft || guardedTurnedRight || lookingAway) {
      feedback = KycFeedback.faceRotated;
    }

    return KycDetectedFace(
      face: face,
      faceIsWellPositioned: faceIsWellPositioned,
      isSmiling: isSmiling,
      isFrowning: isFrowning,
      turnedLeft: guardedTurnedLeft,
      turnedRight: guardedTurnedRight,
      lookingAway: lookingAway,
      isBlinking: isBlinking,
      isMouthOpen: isMouthOpen,
      isNodding: isNodding,
      isFaceCloseEnough: isFaceCloseEnough,
      feedback: feedback,
    );
  }

  /// Check if face occupies enough of the frame (matching roqqu thresholds).
  bool _isFaceCloseEnough(Face face, Size imageSize) {
    final box = face.boundingBox;
    final x = box.left.toInt().clamp(0, imageSize.width.toInt() - 1);
    final y = box.top.toInt().clamp(0, imageSize.height.toInt() - 1);
    final width = box.width.toInt().clamp(1, imageSize.width.toInt() - x);
    final height = box.height.toInt().clamp(1, imageSize.height.toInt() - y);

    final faceWidthRatio = width / imageSize.width;
    final faceHeightRatio = height / imageSize.height;

    return faceWidthRatio > 0.45 && faceHeightRatio > 0.43;
  }

  /// Validate that a face is properly in-frame before reporting gesture
  /// detection. Checks essential landmarks and yaw/pitch/roll bounds.
  bool _isFaceInFrame(
    Face face, {
    List<FaceLandmarkType>? extraLandmarks,
    int? maxYaw,
  }) {
    final defaultLandmarks = [
      FaceLandmarkType.noseBase,
      FaceLandmarkType.bottomMouth,
      ...?extraLandmarks,
    ];

    for (final landmark in defaultLandmarks) {
      if (face.landmarks[landmark] == null) return false;
    }

    const maxPitch = 25;
    const maxRoll = 20;
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;
    final roll = face.headEulerAngleZ ?? 0;

    if (yaw.abs() > (maxYaw ?? 30) || pitch.abs() > maxPitch || roll.abs() > maxRoll) {
      return false;
    }

    return true;
  }

  /// Detect mouth open using lip contour distances, normalized by face height.
  bool _detectMouthOpen(Face face) {
    final upperLip = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipTop]?.points;

    if (upperLip == null || lowerLip == null) return false;

    final upperMid = upperLip[upperLip.length ~/ 2];
    final lowerMid = lowerLip[lowerLip.length ~/ 2];

    final lipDistance = (lowerMid.y - upperMid.y).abs();

    final faceHeight = face.boundingBox.height;
    final normalizedDistance = lipDistance / faceHeight;

    return normalizedDistance >= 0.07;
  }
}
