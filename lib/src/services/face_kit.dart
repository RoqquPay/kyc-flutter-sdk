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
      var rotationCompensation =
      _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return (null, null);
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
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
        format = InputImageFormat.nv21;
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
        ? Platform.isAndroid && image.format.group.name.toLowerCase() != 'nv21'
        ? image.getNv21Uint8List()
        : image.planes.first.bytes
        : _concatenatePlanes(image);

    if (Platform.isAndroid) {
      format = InputImageFormat.nv21;
    }

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
      var rotationCompensation =
      _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
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
    if (Platform.isAndroid && image.format.group.name.toLowerCase() != 'nv21') {
      return image.getNv21Uint8List();
    }

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

/// Converts this [CameraImage] (expected to be in YUV_420_888 format,
/// with 3 planes: Y, U, V) into an NV21 (YYYYVU) byte buffer.
///
/// Throws [Nv21ConversionException] if the image doesn't have the
/// expected shape (wrong plane count, zero/negative dimensions,
/// missing pixel/row stride info, or plane buffers too small to
/// satisfy the computed strides).
extension Nv21Converter on CameraImage {
  Uint8List getNv21Uint8List() {
    final width = this.width;
    final height = this.height;

    if (width <= 0 || height <= 0) {
      throw Nv21ConversionException(
        'Invalid image dimensions: ${width}x$height',
      );
    }

    if (planes.length < 3) {
      throw Nv21ConversionException(
        'Expected 3 planes (Y, U, V) but got ${planes.length}. '
            'Is this image in YUV_420_888 format?',
      );
    }

    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;

    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    if (yRowStride <= 0 || uvRowStride <= 0) {
      throw Nv21ConversionException(
        'Invalid row stride: y=$yRowStride, uv=$uvRowStride',
      );
    }

    if (yPixelStride <= 0 || uvPixelStride <= 0) {
      throw Nv21ConversionException(
        'Invalid pixel stride: y=$yPixelStride, uv=$uvPixelStride',
      );
    }

    if (uBuffer.length != vBuffer.length) {
      throw Nv21ConversionException(
        'U and V plane buffer sizes differ (${uBuffer.length} vs '
            '${vBuffer.length}); cannot safely interleave.',
      );
    }

    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;

    final maxYIndex = (height - 1) * yRowStride + (width - 1) * yPixelStride;
    if (maxYIndex >= yBuffer.length) {
      throw Nv21ConversionException(
        'Y plane buffer too small: needs at least ${maxYIndex + 1} bytes, '
            'has ${yBuffer.length}.',
      );
    }

    if (uvWidth > 0 && uvHeight > 0) {
      final maxUvIndex =
          (uvHeight - 1) * uvRowStride + (uvWidth - 1) * uvPixelStride;
      if (maxUvIndex >= uBuffer.length || maxUvIndex >= vBuffer.length) {
        throw Nv21ConversionException(
          'U/V plane buffer too small: needs at least ${maxUvIndex + 1} '
              'bytes, has u=${uBuffer.length}, v=${vBuffer.length}.',
        );
      }
    }

    final numPixels = width * height + 2 * (uvWidth * uvHeight);
    final nv21 = Uint8List(numPixels);

    int idY = 0;
    int idUV = width * height;

    try {
      for (int y = 0; y < height; ++y) {
        final uvOffset = y * uvRowStride;
        final yOffset = y * yRowStride;

        for (int x = 0; x < width; ++x) {
          nv21[idY++] = yBuffer[yOffset + x * yPixelStride];

          if (y < uvHeight && x < uvWidth) {
            final bufferIndex = uvOffset + (x * uvPixelStride);
            nv21[idUV++] = vBuffer[bufferIndex];
            nv21[idUV++] = uBuffer[bufferIndex];
          }
        }
      }
    } on RangeError catch (e) {
      throw Nv21ConversionException(
        'Unexpected out-of-range access while converting to NV21: $e',
      );
    }

    return nv21;
  }
}

/// Thrown when a [CameraImage] cannot be converted to NV21 format.
class Nv21ConversionException implements Exception {
  Nv21ConversionException(this.message);
  final String message;

  @override
  String toString() => 'Nv21ConversionException: $message';
}
