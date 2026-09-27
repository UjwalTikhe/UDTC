import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/location_service.dart';
import 'processing_screen.dart';

/// Screen 7: Optical Capture Screen
/// High-stakes field evidence capture with real-time quality gating, ArUco reticle,
/// 4-frame burst with specular highlight rejection, and fail-closed GPS binding.
class CameraCaptureScreen extends StatefulWidget {
  final User currentUser;
  final KitType selectedKit;
  final String reagentBatch;
  final String cardSerial;

  const CameraCaptureScreen({
    super.key,
    required this.currentUser,
    this.selectedKit = KitType.nddk,
    this.reagentBatch = "NCB-BATCH-2026-09B",
    this.cardSerial = "NCBCARD-2026-DEL-0491",
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  // Quality check metrics
  bool _cardDetected = true;
  double _laplacianVariance = 128.5; // Threshold >= 100.0
  double _exposureScore = 0.88; // 0.0 to 1.0 (Optimal: 0.2 to 0.95)
  bool _isCapturing = false;

  // Selected sample for forensic evaluation
  String _sampleType = 'positive'; // 'positive', 'negative', 'inconclusive'

  Timer? _qualityCheckTimer;

  @override
  void initState() {
    super.initState();
    _startQualityMonitor();
  }

  @override
  void dispose() {
    _qualityCheckTimer?.cancel();
    super.dispose();
  }

  void _startQualityMonitor() {
    // Periodic check every 250ms
    _qualityCheckTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (mounted && !_isCapturing) {
        setState(() {
          // Dynamic jitter simulating live optical sensor readings
          if (_cardDetected) {
            _laplacianVariance = 120.0 + (timer.tick % 5) * 4.0;
            _exposureScore = 0.85 + (timer.tick % 3) * 0.02;
          }
        });
      }
    });
  }

  bool get _isBlurPass => _laplacianVariance >= 100.0;
  bool get _isExposurePass => _exposureScore >= 0.20 && _exposureScore <= 0.95;
  bool get _allQualityPass => _cardDetected && _isBlurPass && _isExposurePass;

  String? get _qualityFailureReason {
    if (!_cardDetected) return "Card not fully in frame (ArUco markers missing)";
    if (!_isBlurPass) return "Image too blurry (Laplacian ${_laplacianVariance.toStringAsFixed(1)} < 100)";
    if (!_isExposurePass) return "Exposure clipped (Histogram extreme)";
    return null;
  }

  Future<void> _handleBurstCapture() async {
    if (!_allQualityPass || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // 1. Fetch Geolocation with fail-closed timeout
      GeoPoint? geoPoint;
      bool locationConfirmed = false;
      try {
        final pos = await LocationService.instance.getCurrentPosition().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (pos != null && pos.latitude != null && pos.longitude != null) {
          geoPoint = GeoPoint(latitude: pos.latitude!, longitude: pos.longitude!);
          locationConfirmed = true;
        }
      } catch (_) {
        locationConfirmed = false;
      }

      // 2. Simulate 4-burst frame capture over 400ms & best-frame selection
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            currentUser: widget.currentUser,
            selectedKit: widget.selectedKit,
            reagentBatch: widget.reagentBatch,
            cardSerial: widget.cardSerial,
            sampleType: _sampleType,
            location: geoPoint,
            locationConfirmed: locationConfirmed,
            laplacianVariance: _laplacianVariance,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Capture Error: $e"),
            backgroundColor: GovTheme.alertPositiveText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failureReason = _qualityFailureReason;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Minimal Chrome Top Bar (48x48dp touch targets)
            Container(
              height: 56,
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "OPTICAL CAPTURE — ${widget.selectedKit.name.toUpperCase()}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          "Card: ${widget.cardSerial} • Lot: ${widget.reagentBatch}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Demo sample selector toggle
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.science_outlined, color: Colors.amberAccent),
                    tooltip: "Select Demo Test Sample",
                    onSelected: (val) => setState(() => _sampleType = val),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'positive', child: Text("Simulate Positive (Heroin/Purple)")),
                      PopupMenuItem(value: 'negative', child: Text("Simulate Negative (Clear/Beige)")),
                      PopupMenuItem(value: 'inconclusive', child: Text("Simulate Inconclusive (Borderline)")),
                    ],
                  ),
                ],
              ),
            ),

            // Live Camera Viewfinder with Quality CustomPainter Overlay
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Sensor Stream Placeholder
                  Container(
                    color: const Color(0xFF131A26),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.center_focus_strong,
                            size: 140,
                            color: _allQualityPass
                                ? GovTheme.alertNegativeText.withOpacity(0.4)
                                : GovTheme.alertPositiveText.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Forensic Camera Stream Active",
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ArUco Card Alignment Reticle Frame
                  CustomPaint(
                    size: const Size(290, 240),
                    painter: _ReticlePainter(isPass: _allQualityPass),
                  ),

                  // Real-time Status Overlay Pill (Top Center)
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _allQualityPass
                            ? GovTheme.alertNegativeBg
                            : GovTheme.alertPositiveBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _allQualityPass
                              ? GovTheme.alertNegativeText
                              : GovTheme.alertPositiveText,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _allQualityPass ? Icons.check_circle : Icons.warning_amber_rounded,
                            size: 16,
                            color: _allQualityPass
                                ? GovTheme.alertNegativeText
                                : GovTheme.alertPositiveText,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _allQualityPass ? "CARD ALIGNED & SHARP" : failureReason ?? "ALIGNING",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _allQualityPass
                                  ? GovTheme.alertNegativeText
                                  : GovTheme.alertPositiveText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Optical Quality Diagnostics HUD (Bottom Left)
                  Positioned(
                    bottom: 120,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Laplacian Variance: ${_laplacianVariance.toStringAsFixed(1)} (>=100)",
                            style: TextStyle(
                              fontSize: 10,
                              color: _isBlurPass ? Colors.greenAccent : Colors.redAccent,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Exposure Score: ${(_exposureScore * 100).toStringAsFixed(0)}% (Optimal)",
                            style: TextStyle(
                              fontSize: 10,
                              color: _isExposurePass ? Colors.greenAccent : Colors.amberAccent,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Sample Mode: ${_sampleType.toUpperCase()}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Gated Shutter Button (72dp diameter, 32dp clearance above bottom)
                  Positioned(
                    bottom: 32,
                    child: InkWell(
                      onTap: _allQualityPass && !_isCapturing ? _handleBurstCapture : null,
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        width: GovTheme.shutterDiameter, // 72dp
                        height: GovTheme.shutterDiameter, // 72dp
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _allQualityPass ? Colors.white : Colors.grey.shade700,
                          border: Border.all(
                            color: _allQualityPass
                                ? GovTheme.alertNegativeText
                                : Colors.grey.shade500,
                            width: 4,
                          ),
                          boxShadow: _allQualityPass
                              ? [
                                  BoxShadow(
                                    color: GovTheme.alertNegativeText.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _isCapturing
                              ? const SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: GovTheme.primary,
                                  ),
                                )
                              : Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _allQualityPass
                                        ? GovTheme.primary
                                        : Colors.grey.shade600,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter drawing the 4-corner ArUco reticle frame
class _ReticlePainter extends CustomPainter {
  final bool isPass;
  _ReticlePainter({required this.isPass});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isPass ? GovTheme.alertNegativeText : GovTheme.alertPositiveText
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final double w = size.width;
    final double h = size.height;
    const double cornerLen = 32.0;

    // Top-Left Corner
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLen), paint);

    // Top-Right Corner
    canvas.drawLine(Offset(w, 0), Offset(w - cornerLen, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, cornerLen), paint);

    // Bottom-Left Corner
    canvas.drawLine(Offset(0, h), Offset(cornerLen, h), paint);
    canvas.drawLine(Offset(0, h), Offset(0, h - cornerLen), paint);

    // Bottom-Right Corner
    canvas.drawLine(Offset(w, h), Offset(w - cornerLen, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - cornerLen), paint);

    // Subtle reaction zone target circle in center
    final centerPaint = Paint()
      ..color = (isPass ? GovTheme.alertNegativeText : Colors.white).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(w / 2, h / 2), 34, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) => oldDelegate.isPass != isPass;
}
