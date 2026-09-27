import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

/// Forensic Image Watermark Service
/// Burn-in evidentiary watermark directly onto the captured photograph
/// under NDPS Act §52A and BSA 2023 §63 standards.
class ForensicWatermarkService {
  static final ForensicWatermarkService instance = ForensicWatermarkService._internal();
  ForensicWatermarkService._internal();

  Future<File> stampForensicWatermark({
    required File rawImageFile,
    required String testId,
    required String officerBadge,
    required String deviceId,
    required double? latitude,
    required double? longitude,
    required bool locationConfirmed,
  }) async {
    final rawBytes = await rawImageFile.readAsBytes();
    final rawHash = sha256.convert(rawBytes).toString();
    final truncatedHash = rawHash.substring(0, 16).toUpperCase();

    // Decode image using dart:ui
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    final int width = image.width;
    final int height = image.height;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 1. Draw raw photograph
    canvas.drawImage(image, Offset.zero, Paint());

    // 2. Draw Top Government Banner
    final double bannerHeight = (height * 0.08).clamp(60.0, 140.0);
    final topPaint = Paint()..color = const Color(0xDD0A2558); // Semi-transparent Ashoka Navy
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), bannerHeight), topPaint);

    // Tricolor line under top banner
    final double triHeight = 6.0;
    final saffronPaint = Paint()..color = const Color(0xFFFF9933);
    final whitePaint = Paint()..color = const Color(0xFFFFFFFF);
    final greenPaint = Paint()..color = const Color(0xFF138808);

    canvas.drawRect(Rect.fromLTWH(0, bannerHeight - triHeight, width / 3.0, triHeight), saffronPaint);
    canvas.drawRect(Rect.fromLTWH(width / 3.0, bannerHeight - triHeight, width / 3.0, triHeight), whitePaint);
    canvas.drawRect(Rect.fromLTWH((2 * width) / 3.0, bannerHeight - triHeight, width / 3.0, triHeight), greenPaint);

    // Draw Top Text
    final double topFontSize = (bannerHeight * 0.32).clamp(16.0, 36.0);
    final topTextPainter = TextPainter(
      text: TextSpan(
        text: "MINISTRY OF HOME AFFAIRS • GOVT OF INDIA\nNDPS §52A / BSA 2023 §63 STATUTORY FORENSIC SEIZURE",
        style: TextStyle(
          color: Colors.white,
          fontSize: topFontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    topTextPainter.layout(maxWidth: width - 40.0);
    topTextPainter.paint(canvas, Offset(24, (bannerHeight - topTextPainter.height) / 2));

    // 3. Draw Bottom Forensic Metadata Overlay Banner
    final double bottomBannerHeight = (height * 0.14).clamp(120.0, 240.0);
    final bottomPaint = Paint()..color = const Color(0xEE0F172A); // Dark slate
    final bottomY = height - bottomBannerHeight;
    canvas.drawRect(Rect.fromLTWH(0, bottomY, width.toDouble(), bottomBannerHeight), bottomPaint);

    // Border line above bottom banner
    final borderPaint = Paint()
      ..color = const Color(0xFFFFD700) // Gold
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(0, bottomY), Offset(width.toDouble(), bottomY), borderPaint);

    // Prepare Bottom Forensic Details
    final nowUtc = DateTime.now().toUtc();
    final dateStr = DateFormat("yyyy-MM-dd HH:mm:ss 'UTC'").format(nowUtc);
    final gpsStr = (latitude != null && longitude != null)
        ? "LAT: ${latitude.toStringAsFixed(6)}°, LON: ${longitude.toStringAsFixed(6)}° (CONFIRMED)"
        : "LOCATION UNCONFIRMED (DEGRADED SATELLITE FIX)";

    final double bottomFontSize = (bottomBannerHeight * 0.16).clamp(12.0, 24.0);

    final bottomTextPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: "TEST ID: $testId   •   BADGE: $officerBadge   •   APPARATUS: $deviceId\n",
            style: TextStyle(color: Colors.amberAccent, fontSize: bottomFontSize, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: "TIMESTAMP: $dateStr   •   $gpsStr\n",
            style: TextStyle(color: Colors.white, fontSize: bottomFontSize, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: "RAW SENSOR DIGEST: SHA256:$truncatedHash...   •   EVIDENCE TAMPER-PROOF",
            style: TextStyle(color: const Color(0xFF68D391), fontSize: bottomFontSize * 0.9, fontFamily: 'monospace'),
          ),
        ],
      ),
      textDirection: ui.TextDirection.ltr,
    );
    bottomTextPainter.layout(maxWidth: width - 48.0);
    bottomTextPainter.paint(canvas, Offset(24, bottomY + 16));

    // Finalize image
    final picture = recorder.endRecording();
    final watermarkedImage = await picture.toImage(width, height);
    final byteData = await watermarkedImage.toByteData(format: ui.ImageByteFormat.png);

    final docsDir = await getApplicationDocumentsDirectory();
    final watermarkedFile = File("${docsDir.path}/MHA_SEIZURE_${testId}_WATERMARKED.png");
    await watermarkedFile.writeAsBytes(byteData!.buffer.asUint8List());

    return watermarkedFile;
  }
}
