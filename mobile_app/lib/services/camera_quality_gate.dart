import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraQualityMetrics {
  final double laplacianVariance;
  final bool fourFiducialsVisible;

  const CameraQualityMetrics({
    required this.laplacianVariance,
    required this.fourFiducialsVisible,
  });

  bool get passed => laplacianVariance >= 100 && fourFiducialsVisible;
}

/// Lightweight native-camera gate. It uses the camera Y plane for live
/// sharpness and checks the four printed fiducial regions before shutter.
/// The final frame still goes through the full isolate colorimetry pipeline.
class CameraQualityGate {
  static CameraQualityMetrics fromCameraImage(CameraImage frame) {
    final plane = frame.planes.first;
    final bytes = plane.bytes;
    if (bytes.isEmpty || frame.width < 8 || frame.height < 8) {
      return const CameraQualityMetrics(laplacianVariance: 0, fourFiducialsVisible: false);
    }
    final variance = _laplacianVariance(
      bytes,
      frame.width,
      frame.height,
      plane.bytesPerRow,
      plane.bytesPerPixel ?? 1,
    );
    final fiducials = _fourDarkCornerRegions(
      bytes,
      frame.width,
      frame.height,
      plane.bytesPerRow,
      plane.bytesPerPixel ?? 1,
    );
    return CameraQualityMetrics(
      laplacianVariance: variance,
      fourFiducialsVisible: fiducials,
    );
  }

  static double fromEncodedImage(List<int> bytes) {
    final decoded = img.decodeImage(Uint8List.fromList(bytes));
    if (decoded == null) return 0;
    final yPlane = Uint8List(decoded.width * decoded.height);
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        yPlane[y * decoded.width + x] = decoded.getPixel(x, y).luminance.toInt().clamp(0, 255);
      }
    }
    return _laplacianVariance(yPlane, decoded.width, decoded.height, decoded.width, 1);
  }

  static double _laplacianVariance(
    Uint8List bytes,
    int width,
    int height,
    int rowStride,
    int pixelStride,
  ) {
    final step = (width > 640 ? 3 : 2);
    var sum = 0.0;
    var sumSquared = 0.0;
    var count = 0;
    for (var y = step; y < height - step; y += step) {
      for (var x = step; x < width - step; x += step) {
        int sample(int sx, int sy) => bytes[sy * rowStride + sx * pixelStride];
        final lap = sample(x - step, y) +
            sample(x + step, y) +
            sample(x, y - step) +
            sample(x, y + step) -
            4 * sample(x, y);
        sum += lap;
        sumSquared += lap * lap;
        count++;
      }
    }
    if (count == 0) return 0;
    final mean = sum / count;
    return (sumSquared / count - mean * mean).clamp(0, double.infinity);
  }

  static bool _fourDarkCornerRegions(
    Uint8List bytes,
    int width,
    int height,
    int rowStride,
    int pixelStride,
  ) {
    final regions = <(int, int)>[
      (width ~/ 8, height ~/ 8),
      (width - width ~/ 8, height ~/ 8),
      (width ~/ 8, height - height ~/ 8),
      (width - width ~/ 8, height - height ~/ 8),
    ];
    var detected = 0;
    for (final (cx, cy) in regions) {
      var dark = 0;
      var samples = 0;
      for (var dy = -height ~/ 16; dy <= height ~/ 16; dy += 2) {
        for (var dx = -width ~/ 16; dx <= width ~/ 16; dx += 2) {
          final x = (cx + dx).clamp(0, width - 1);
          final y = (cy + dy).clamp(0, height - 1);
          if (bytes[y * rowStride + x * pixelStride] < 80) dark++;
          samples++;
        }
      }
      if (samples > 0 && dark / samples > 0.12) detected++;
    }
    return detected == 4;
  }
}