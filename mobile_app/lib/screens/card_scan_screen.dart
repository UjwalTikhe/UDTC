import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'reaction_timer_screen.dart';

/// Screen 5: Reference Card QR Scan Screen (Step 2)
/// Validates genuine MHA Reference Card issuance via 3-frame debounced QR reading,
/// and enforces cross-checking against the selected KitType to block kit mismatches.
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
  String? _mismatchError;
  int _consecutiveReads = 0;
  String _lastPayload = "";
  bool _showTorchHint = false;
  Timer? _torchHintTimer;
  String _scanStatus = "Align Reference Card QR code within reticle frame...";

  @override
  void initState() {
    super.initState();
    // 3-second torch reminder if not detected
    _torchHintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _detectedSerial == null && _mismatchError == null) {
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
      _validateAndProceed(payload);
    }
  }

  void _validateAndProceed(String payload) {
    final cleanPayload = payload.trim().toUpperCase();

    // 1. Validate Prefix Format
    if (!cleanPayload.startsWith("MHACARD-")) {
      setState(() {
        _isScanning = true;
        _consecutiveReads = 0;
        _mismatchError = "INVALID CARD FORMAT: Payload must carry official 'MHACARD-' prefix.";
        _scanStatus = "SCAN REJECTED: Invalid reference card format.";
      });
      return;
    }

    // 2. Cross-check against Selected KitType
    KitType? encodedKit;
    if (cleanPayload.contains("-NDDK-") || cleanPayload.contains(":NDDK")) {
      encodedKit = KitType.nddk;
    } else if (cleanPayload.contains("-PCDK-") || cleanPayload.contains(":PCDK")) {
      encodedKit = KitType.pcdk;
    } else if (cleanPayload.contains("-KDK-") || cleanPayload.contains(":KDK")) {
      encodedKit = KitType.kdk;
    }

    if (encodedKit != null && encodedKit != widget.selectedKit) {
      final mismatchedName = encodedKit.name.toUpperCase();
      setState(() {
        _isScanning = true;
        _consecutiveReads = 0;
        _detectedSerial = null;
        _mismatchError = "KIT MISMATCH DETECTED!\n"
            "This reference card is provisioned for $mismatchedName, but you selected ${widget.selectedKit.name.toUpperCase()}.\n"
            "Action blocked to prevent running an invalid reagent sequence against the wrong card.";
        _scanStatus = "BLOCKED: Kit mismatch ($mismatchedName ≠ ${widget.selectedKit.name.toUpperCase()})";
      });
      return;
    }

    // 3. Card Validated Successfully
    setState(() {
      _isScanning = false;
      _mismatchError = null;
      _detectedSerial = cleanPayload;
      _scanStatus = "CARD VALIDATED: $cleanPayload\nKit Cross-Check: PASS (${widget.selectedKit.name.toUpperCase()})";
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReactionTimerScreen(
            currentUser: widget.currentUser,
            selectedKit: widget.selectedKit,
            reagentBatch: widget.reagentBatch,
            cardSerial: cleanPayload,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeKitName = widget.selectedKit.name.toUpperCase();
    final mismatchedKit = widget.selectedKit == KitType.nddk
        ? KitType.kdk
        : (widget.selectedKit == KitType.pcdk ? KitType.nddk : KitType.pcdk);

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
              subtitleText: "STEP 2 OF 6: REFERENCE CARD AUTHENTICATION & KIT CHECK",
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Camera / Viewfinder Simulation Area
                  Container(
                    color: const Color(0xFF1E293B),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 150,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Scanning Reference Card for Kit: $activeKitName",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Hold card flat under illumination • 3-frame debounce active",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
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
                            : (_mismatchError != null
                                ? GovTheme.alertPositiveText
                                : GovTheme.tricolorSaffron),
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
                              "MHACARD QR ZONE [$activeKitName]",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
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
                        if (_mismatchError != null)
                          const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: GovTheme.alertPositiveText,
                              size: 64,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Torch Hint Banner (if 3s elapsed)
                  if (_showTorchHint && _detectedSerial == null && _mismatchError == null)
                    Positioned(
                      top: 16,
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
                              "Low light? Try toggling flashlight above",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Kit Mismatch Warning Callout (Step 2 requirement)
                  if (_mismatchError != null)
                    Positioned(
                      top: 20,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GovTheme.alertPositiveText, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.block, color: GovTheme.alertPositiveText, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "VALIDATION FAILED",
                                    style: TextStyle(
                                      color: GovTheme.alertPositiveText,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _mismatchError!,
                                    style: const TextStyle(
                                      color: Color(0xFF8C1D18),
                                      fontSize: 11,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Scan Status & Simulator Triggers
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Button 1: Valid Matching Card
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: GovTheme.primary,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                onPressed: () {
                                  final validSerial = "MHACARD-$activeKitName-2026-DEL-0491";
                                  _simulateFrameScan(validSerial);
                                  _simulateFrameScan(validSerial);
                                  _simulateFrameScan(validSerial);
                                },
                                icon: const Icon(Icons.qr_code, size: 18, color: Colors.white),
                                label: Text(
                                  "Scan Issued $activeKitName Card",
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Button 2: Mismatched Card Trigger (Verifies Step 2 blocking)
                            Expanded(
                              flex: 2,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.amberAccent),
                                  foregroundColor: Colors.amberAccent,
                                  minimumSize: const Size.fromHeight(46),
                                ),
                                onPressed: () {
                                  final wrongSerial = "MHACARD-${mismatchedKit.name.toUpperCase()}-2026-DEL-0988";
                                  _simulateFrameScan(wrongSerial);
                                  _simulateFrameScan(wrongSerial);
                                  _simulateFrameScan(wrongSerial);
                                },
                                child: Text(
                                  "Test ${mismatchedKit.name.toUpperCase()} Card",
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
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
