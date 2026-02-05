part of '../../roqqu_kyc.dart';

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

  Future<KycDetectedFace> processImage(
    InputImage inputImage,
    KycConfig config,
  ) async {
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

      return _analyzeFace(face, config, inputImage.metadata?.size);
    } catch (e) {
      // Return initial state if detection fails
      return KycDetectedFace.initial();
    }
  }

  KycDetectedFace _analyzeFace(Face face, KycConfig config, Size? imageSize) {
    // 1. Position Analysis
    bool faceIsWellPositioned = true;
    bool isFaceCloseEnough = true;

    if (imageSize != null) {
      final faceWidth = face.boundingBox.width;
      final imageWidth = imageSize.width;

      // Face close enough: width > 25% of image width
      isFaceCloseEnough = faceWidth > (imageWidth * 0.25);

      // Well positioned: Center of face within 20% deviation from image center
      final faceCenter = face.boundingBox.center;
      final imageCenter = Offset(imageSize.width / 2, imageSize.height / 2);
      final distanceFromCenter = (faceCenter - imageCenter).distance;
      final maxDeviation = min(imageSize.width, imageSize.height) * 0.2;

      faceIsWellPositioned = distanceFromCenter < maxDeviation;
    }

    // 2. Head Pose (Rotation)
    final rotY = face.headEulerAngleY ?? 0; // Yaw (Left/Right)
    final rotX = face.headEulerAngleX ?? 0; // Pitch (Up/Down)

    final turnedLeft = rotY > _faceTurnThreshold;
    final turnedRight = rotY < -_faceTurnThreshold;

    // Looking away if rotation exceeds 30 degrees in any significant direction
    // (excluding slight natural tilt)
    final lookingAway = rotY.abs() > 30 || rotX.abs() > 30;

    // 3. Facial Expressions
    final isSmiling = (face.smilingProbability ?? 0) > 0.5;

    // Blinking: Both eyes closed
    final leftOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightOpen = face.rightEyeOpenProbability ?? 1.0;
    final isBlinking = leftOpen < 0.3 && rightOpen < 0.3;

    // Mouth Open analysis using landmarks
    // Mouth Open analysis using contours (matching original implementation)
    // Uses the distance between the bottom of the upper lip and top of the lower lip
    bool isMouthOpen = false;
    final upperLip = face.contours[FaceContourType.upperLipBottom]?.points;
    final lowerLip = face.contours[FaceContourType.lowerLipTop]?.points;

    if (upperLip != null &&
        lowerLip != null &&
        upperLip.isNotEmpty &&
        lowerLip.isNotEmpty) {
      // Use the middle points of the lips
      final upperMid = upperLip[upperLip.length ~/ 2];
      final lowerMid = lowerLip[lowerLip.length ~/ 2];

      final lipDistance = (lowerMid.y - upperMid.y).abs();

      // Normalize by face height
      final faceHeight = face.boundingBox.height;
      final normalizedDistance = lipDistance / faceHeight;

      if (normalizedDistance >= 0.07) {
        // ~7% of face height
        isMouthOpen = true;
      }
    }

    // Nodding detection (Stub for single frame analysis)
    // Would require stateful tracking of rotX history
    final isNodding = false;

    return KycDetectedFace(
      face: face,
      faceIsWellPositioned: faceIsWellPositioned,
      isSmiling: isSmiling,
      isFrowning: false, // Not detected by standard ML Kit
      turnedLeft: turnedLeft,
      turnedRight: turnedRight,
      lookingAway: lookingAway,
      isBlinking: isBlinking,
      isMouthOpen: isMouthOpen,
      isNodding: isNodding,
      isFaceCloseEnough: isFaceCloseEnough,
    );
  }
}
