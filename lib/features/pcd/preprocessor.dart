import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import '../../screens/scanner_screen.dart';

class Preprocessor {
  // Dari CameraImage (YUV420)
  static Future<Float32List?> process(CameraImage cameraImage, int inputSize) async {
    try {
      final rgbImage = _convertYUV420toRGB(cameraImage);
      if (rgbImage == null) return null;
      final resized = img.copyResize(
        rgbImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );
      return _normalizeToFloat32(resized, inputSize);
    } catch (e) {
      print('Preprocessor error: $e');
      return null;
    }
  }

  static img.Image? convertToImage(CameraImage cameraImage) {
    return _convertYUV420toRGB(cameraImage);
  }

  // Dari img.Image (takePicture)
  static Float32List? processImage(img.Image image, int inputSize) {
    try {
      final resized = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );
      return _normalizeToFloat32(resized, inputSize);
    } catch (e) {
      print('processImage error: $e');
      return null;
    }
  }

  static img.Image? _convertYUV420toRGB(CameraImage cameraImage) {
    try {
      final width = cameraImage.width;
      final height = cameraImage.height;
      final yPlane = cameraImage.planes[0].bytes;
      final uPlane = cameraImage.planes[1].bytes;
      final vPlane = cameraImage.planes[2].bytes;
      final yRowStride = cameraImage.planes[0].bytesPerRow;
      final uRowStride = cameraImage.planes[1].bytesPerRow;
      final uPixelStride = cameraImage.planes[1].bytesPerPixel ?? 2;
      final output = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yValue = yPlane[y * yRowStride + x];
          final uvIndex = (y ~/ 2) * uRowStride + (x ~/ 2) * uPixelStride;
          final uValue = uPlane[uvIndex];
          final vValue = vPlane[uvIndex];
          int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
          int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
          output.setPixelRgb(x, y, r, g, b);
        }
      }
      return output;
    } catch (e) {
      print('YUV conversion error: $e');
      return null;
    }
  }

  static Float32List _normalizeToFloat32(img.Image image, int inputSize) {
    final tensor = Float32List(inputSize * inputSize * 3);
    int index = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        tensor[index++] = pixel.r / 255.0;
        tensor[index++] = pixel.g / 255.0;
        tensor[index++] = pixel.b / 255.0;
      }
    }
    return tensor;
  }

  static Future<Float32List?> processFrameData(CameraFrameData frameData, int inputSize) async {
    try {
      final rgbImage = _convertFrameDataToRGB(frameData);
      if (rgbImage == null) return null;

      final resized = img.copyResize(
        rgbImage,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      return _normalizeToFloat32(resized, inputSize);
    } catch (e) {
      print('processFrameData error: $e');
      return null;
    }
  }

  static img.Image? convertFrameData(CameraFrameData frameData) {
    return _convertFrameDataToRGB(frameData);
  }

  static img.Image? _convertFrameDataToRGB(CameraFrameData frameData) {
    try {
      final width = frameData.width;
      final height = frameData.height;
      final yPlane = frameData.planes[0].bytes;
      final uPlane = frameData.planes[1].bytes;
      final vPlane = frameData.planes[2].bytes;
      final yRowStride = frameData.planes[0].bytesPerRow;
      final uRowStride = frameData.planes[1].bytesPerRow;
      final uPixelStride = frameData.planes[1].bytesPerPixel ?? 2;

      const contrastFactor = 1.2;
      const brightnessOffset = 10;

      final output = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yValue = yPlane[y * yRowStride + x];
          final uvIndex = (y ~/ 2) * uRowStride + (x ~/ 2) * uPixelStride;
          final uValue = uPlane[uvIndex];
          final vValue = vPlane[uvIndex];

          int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
          int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          r = ((contrastFactor * (r - 128)) + 128 + brightnessOffset).round().clamp(0, 255);
          g = ((contrastFactor * (g - 128)) + 128 + brightnessOffset).round().clamp(0, 255);
          b = ((contrastFactor * (b - 128)) + 128 + brightnessOffset).round().clamp(0, 255);

          output.setPixelRgb(x, y, r, g, b);
        }
      }
      return output;
    } catch (e) {
      print('convertFrameDataToRGB error: $e');
      return null;
    }
  }
}
