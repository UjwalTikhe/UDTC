import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'reaction_timer_screen.dart';

/// Screen 5: Reference Card QR Scan Screen
/// Validates genuine MHA Reference Card issuance via 3-frame debounced QR reading.
class CardScanScreen extends StatefulWidget {
  final User currentUser;
  final KitType selectedKit;
  final String reagentBatch;

  const CardScanScreen({
    super.key,
    required this.currentUser,
    required this.selectedKit,
    required this.reagentBatch,
  });

  @override
  State<CardScanScreen> createState() => _CardScanScreenState();
}

class _CardScanScreenState extends State<CardScanScreen> {
  bool _isTorchOn = false;
  bool _isScanning = true;
  String? _detectedSerial;
  int _consecutiveReads = 0;
  String _lastPayload = "";
  bool _showTorchHint = false;
  Timer? _torchHintTimer;
  String _scanStatus = "Align Card QR code within reticle frame...";

  @override
  void initState() {
    super.initState();
    // 3-second torch reminder if not detected
    _torchHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _detectedSerial == null) {
        setState(() => _showTorchHint = true);
      }
    });
  }

  @override
  void dispose() {
    _torchHintTimer?.cancel();
    super.dispose();
  }

  void _simulateFrameScan(String payload) {
    if (!_isScanning) return;

    if (payload == _lastPayload) {
      _consecutiveReads++;
    } else {
      _lastPayload = payload;
      _consecutiveReads = 1;
    }

    setState(() {
      _scanStatus = "Detected payload (Frame $_consecutiveReads/3): $payload";
    });

    // 3-frame debounce rule
    if (_consecutiveReads >= 3) {
      _isScanning = false;
      _validateAndProceed(payload);
    }
  }

  void _validateAndProceed(String payload) {
    // Validate format: must start with "MHACARD-"
    if (!payload.startsWith("MHACARD-")) {
      setState(() {
        _isScanning = true;
        _consecutiveReads = 0;
        _scanStatus = "INVALID CARD FORMAT: Must contain official 'MHACARD-' prefix.";
      });
      return;
    }

    final serial = payload.trim();
    setState(() {
      _detectedSerial = serial;
      _scanStatus = "CARD VALIDATED: $serial (Issued to ${widget.currentUser.badgeNumber})";
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReactionTimerScreen(
            currentUser: widget.currentUser,
            selectedKit: widget.selectedKit,
            reagentBatch: widget.reagentBatch,
            cardSerial: serial,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Reference Card"),
        backgroundColor: GovTheme.ashokaNavy,
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off, color: Colors.amberAccent),
            tooltip: "Toggle Flashlight",
            onPressed: () {
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "STEP 2 OF 6: CARD ISSUANCE AUTHENTICATION",
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera Simulation / Mock Background
                  Container(
                    color: const Color(0xFF1E293B),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 160,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Live Card Scanning Viewfinder",
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Viewfinder Reticle Overlay
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _detectedSerial != null
                            ? GovTheme.alertNegativeText
                            : GovTheme.tricolorSaffron,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black54,
                            child: Text(
                              "MHACARD QR ZONE",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (_detectedSerial != null)
                          const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: GovTheme.alertNegativeText,
                              size: 64,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Torch Hint Banner
                  if (_showTorchHint && _detectedSerial == null)
                    Positioned(
                      top: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lightbulb, size: 16, color: Colors.black87),
                            SizedBox(width: 6),
                            Text(
                              "Low light? Try toggling the flashlight above",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Simulation scan buttons for quick testing
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            _scanStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GovTheme.primary,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                onPressed: () {
                                  // Send 3 consecutive frame triggers of valid card
                                  _simulateFrameScan("MHACARD-2026-DEL-0491");
                                  _simulateFrameScan("MHACARD-2026-DEL-0491");
                                  _simulateFrameScan("MHACARD-2026-DEL-0491");
                                },
                                icon: const Icon(Icons.qr_code, size: 18, color: Colors.white),
                                label: const Text(
                                  "Scan Issued Card",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade800,
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: () {
                                _simulateFrameScan("INVALID-QR-CODE-1234");
                              },
                              child: const Text("Invalid", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
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
