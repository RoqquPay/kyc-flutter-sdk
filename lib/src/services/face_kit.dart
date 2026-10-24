import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Utility class for converting [CameraImage] frames into ML Kit [InputImage]
/// objects, and for computing the correct image rotation per platform and
/// camera lens direction.
class KycFaceKit {
  KycFaceKit._();

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Convert a [CameraImage] into an ML Kit [InputImage].
  ///
  /// Returns a record of `(InputImage?, InputImageRotation?)`.
  /// Either element may be `null` when the format / rotation is unsupported.
  static (InputImage?, InputImageRotation?) inputImageFromCameraImage(
    CameraImage image,
    CameraController? controller,
    List<CameraDescription> cameras,
  ) {
    if (controller == null) return (null, null);

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return (null, null);
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return (null, null);

    // Determine image format
    InputImageFormat? format;

    if (Platform.isAndroid) {
      final formatGroupName = image.format.group.name.toLowerCase();
      if (formatGroupName == 'yuv420') {
        format = InputImageFormat.yuv_420_888;
      } else if (formatGroupName == 'nv21') {
        format = InputImageFormat.nv21;
      } else if (formatGroupName == 'bgra8888' || formatGroupName == 'jpeg') {
        return (null, null);
      } else {
        format = InputImageFormat.yuv_420_888;
      }
    } else if (Platform.isIOS) {
      final formatGroupName = image.format.group.name.toLowerCase();
      if (formatGroupName == 'bgra8888') {
        format = InputImageFormat.bgra8888;
      } else {
        return (null, null);
      }
    } else {
      return (null, null);
    }

    final androidSupportedFormats = [
      InputImageFormat.nv21,
      InputImageFormat.yv12,
      InputImageFormat.yuv_420_888,
    ];

    if ((Platform.isAndroid && !androidSupportedFormats.contains(format)) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return (null, null);
    }

    final Uint8List bytes = image.planes.length == 1
        ? image.planes.first.bytes
        : _concatenatePlanes(image);

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    return (inputImage, rotation);
  }

  /// Get the [InputImageRotation] for the current camera orientation.
  ///
  /// This is needed to determine if images should be horizontally flipped
  /// (e.g. for front-facing cameras) when saving selfie files.
  static InputImageRotation? getImageRotation(CameraController? controller) {
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }

    return rotation;
  }

  /// Whether the image should NOT be horizontally inverted given the rotation.
  ///
  /// When `true`, the image is already in the correct orientation.
  /// When `false`, a horizontal flip is needed (typically rotation270deg on
  /// front-facing cameras).
  static bool shouldNotInvert(InputImageRotation? rotation) {
    return rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation0deg ||
        rotation == InputImageRotation.rotation180deg;
  }

  static Uint8List _concatenatePlanes(CameraImage image) {
    int length = 0;
    for (final Plane p in image.planes) {
      length += p.bytes.length;
    }

    final Uint8List bytes = Uint8List(length);
    int offset = 0;
    for (final Plane p in image.planes) {
      bytes.setRange(offset, offset + p.bytes.length, p.bytes);
      offset += p.bytes.length;
    }
    return bytes;
  }
}
