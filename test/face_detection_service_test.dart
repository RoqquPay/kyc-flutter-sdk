import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:kyc_engine/kyc_engine.dart';

class MockFaceDetector implements FaceDetector {
  final List<Face> _facesToReturn;

  MockFaceDetector(this._facesToReturn);

  @override
  Future<List<Face>> processImage(InputImage inputImage) async {
    return _facesToReturn;
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KycFaceDetectionService', () {
    late KycFaceDetectionService service;
    late KycConfig config;

    setUp(() {
      config = KycConfig(enableAntispoofing: true);
    });

    test('processImage returns initial state when no faces found', () async {
      final detector = MockFaceDetector([]);
      service = KycFaceDetectionService(detector: detector);

      final inputImage = InputImage.fromFilePath('test_path');
      final result = await service.processImage(inputImage, config);

      expect(result, KycDetectedFace.initial());
      expect(result.faceFound, false);
    });

    test('processImage analyzes attributes correctly', () async {
      final landmarks = <FaceLandmarkType, FaceLandmark>{
        FaceLandmarkType.noseBase: FaceLandmark(
          type: FaceLandmarkType.noseBase,
          position: const Point<int>(100, 100),
        ),
        FaceLandmarkType.bottomMouth: FaceLandmark(
          type: FaceLandmarkType.bottomMouth,
          position: const Point<int>(100, 150),
        ),
        FaceLandmarkType.leftEye: FaceLandmark(
          type: FaceLandmarkType.leftEye,
          position: const Point<int>(80, 80),
        ),
        FaceLandmarkType.rightEye: FaceLandmark(
          type: FaceLandmarkType.rightEye,
          position: const Point<int>(120, 80),
        ),
      };

      final face = Face(
        boundingBox: const Rect.fromLTWH(0, 0, 200, 200),
        landmarks: landmarks,
        contours: {},
        smilingProbability: 0.9,
        leftEyeOpenProbability: 0.1,
        rightEyeOpenProbability: 0.1,
        headEulerAngleY: 20.0,
        headEulerAngleX: 0,
        headEulerAngleZ: 0,
      );

      final detector = MockFaceDetector([face]);
      service = KycFaceDetectionService(detector: detector);

      final inputImage = InputImage.fromFilePath('test_path');
      final result = await service.processImage(inputImage, config);

      expect(result.faceFound, true);
      expect(result.isSmiling, true);
      expect(result.isBlinking, true);
      expect(result.turnedLeft, true);
      expect(result.turnedRight, false);
    });
  });
}
