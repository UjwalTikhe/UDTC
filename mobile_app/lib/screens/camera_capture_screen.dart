import 'dart:async';
import 'package:flutter/material.dart';
import '../models/reagent_kit.dart';
import '../services/colorimeter_service.dart';
import '../services/location_service.dart';
import 'test_analysis_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  ReagentKit _selectedKit = ReagentKit.allKits[0]; // Marquis default
  Timer? _reactionTimer;
  int _elapsedReactionSeconds = 25;
  bool _isTimerRunning = true;
  bool _burstMode = true;
  bool _accusedPresent = true;
  String _cardSerial = "NCB-CARD-2026-0081";

  // Real-time quality meters
  double _simulatedBlurVariance = 114.2; // Threshold >= 75.0
  double _simulatedGlareRatio = 0.02; // Threshold <= 0.08
  bool _cardInFrame = true;

  // Selected test demo image asset
  String _selectedAssetSample = 'assets/field_sample_positive.png';

  @override
  void initState() {
    super.initState();
    _startReactionTimer();
  }

  @override
  void dispose() {
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _startReactionTimer() {
    _reactionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isTimerRunning) {
        setState(() {
          _elapsedReactionSeconds++;
        });
      }
    });
  }

  bool get _isReactionWindowValid =>
      _elapsedReactionSeconds >= _selectedKit.minReactionTimeSeconds &&
      _elapsedReactionSeconds <= _selectedKit.maxReactionTimeSeconds;

  bool get _isQualityPass =>
      _simulatedBlurVariance >= 75.0 && _simulatedGlareRatio <= 0.08 && _cardInFrame;

  void _processCapture() async {
    // 1. Check quality gating
    if (!_isQualityPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Capture Rejected: Card misaligned or image blurry. Please steady device."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 2. Fetch Geolocation
    final location = await LocationService.instance.getCurrentPosition();

    // 3. Determine sample color based on selected sample
    List<double> sampleLab;
    if (_selectedAssetSample.contains("positive")) {
      // Very close to Marquis expected Lab [26.0, 48.0, -32.0]
      sampleLab = [27.2, 46.5, -30.8];
    } else if (_selectedAssetSample.contains("blurry")) {
      sampleLab = [29.0, 35.0, -18.0];
    } else {
      // Negative / unreactive beige background
      sampleLab = [65.0, 4.0, 18.0];
    }

    final analysisResult = ColorimeterService.evaluateReagentSample(
      kit: _selectedKit,
      measuredLab: sampleLab,
      blurVariance: _simulatedBlurVariance,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TestAnalysisScreen(
          reagentKit: _selectedKit,
          analysisResult: analysisResult,
          cardSerial: _cardSerial,
          locationResult: location,
          accusedPresent: _accusedPresent,
          elapsedReactionSeconds: _elapsedReactionSeconds,
          isReactionWindowValid: _isReactionWindowValid,
          imageAssetPath: _selectedAssetSample,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Capture Reagent Field Test"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(
              _burstMode ? Icons.burst_mode : Icons.camera,
              color: _burstMode ? Colors.cyanAccent : Colors.white70,
            ),
            tooltip: _burstMode ? "Burst Mode ON (3 frames anti-spoof)" : "Single Shot",
            onPressed: () {
              setState(() => _burstMode = !_burstMode);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Reagent Kit Selector Bar
          Container(
            color: const Color(0xFF1E293B),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text("Reagent: ", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ReagentKit>(
                      value: _selectedKit,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      items: ReagentKit.allKits.map((k) {
                        return DropdownMenuItem(
                          value: k,
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: k.representativeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${k.name} (${k.targetDrug})",
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (k) {
                        if (k != null) {
                          setState(() {
                            _selectedKit = k;
                            _elapsedReactionSeconds = k.minReactionTimeSeconds + 10;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Viewfinder with ArUco Reference Card Overlay
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Viewfinder / Target Card Image Display
                Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Image.asset(
                      _selectedAssetSample,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, st) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          color: const Color(0xFF1E293B),
                          child: const Center(
                            child: Text(
                              "Camera Viewfinder Active\nReference Card Detected: NCB-CARD-2026-0081",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Card Alignment Rectangular Guide
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _cardInFrame ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent,
                        width: 2.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // 4 ArUco Corner Markers visual anchors
                        _buildArUcoCorner(Alignment.topLeft, "ID:0"),
                        _buildArUcoCorner(Alignment.topRight, "ID:1"),
                        _buildArUcoCorner(Alignment.bottomRight, "ID:2"),
                        _buildArUcoCorner(Alignment.bottomLeft, "ID:3"),

                        // Reaction Well Crosshairs
                        Center(
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.cyanAccent.withOpacity(0.7), width: 1.5),
                            ),
                            child: const Center(
                              child: Text(
                                "WELL",
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Live Reaction Timer Countdown Gauge
                Positioned(
                  top: 16,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isReactionWindowValid ? Colors.greenAccent : Colors.amberAccent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 16,
                              color: _isReactionWindowValid ? Colors.greenAccent : Colors.amberAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Reaction Timer: ${_elapsedReactionSeconds}s",
                              style: TextStyle(
                                color: _isReactionWindowValid ? Colors.greenAccent : Colors.amberAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "Legal Window: ${_selectedKit.minReactionTimeSeconds}s–${_selectedKit.maxReactionTimeSeconds}s",
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Overlay: Live Quality Checks & Statutory Gating
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQualityIndicator(
                              "Laplacian Sharpness",
                              "${_simulatedBlurVariance.toStringAsFixed(1)} (Min 75)",
                              _simulatedBlurVariance >= 75.0,
                            ),
                            _buildQualityIndicator(
                              "Exposure / Glare",
                              "${(_simulatedGlareRatio * 100).toStringAsFixed(0)}% (Max 8%)",
                              _simulatedGlareRatio <= 0.08,
                            ),
                            _buildQualityIndicator(
                              "ArUco 4-Corners",
                              _cardInFrame ? "LOCKED" : "LOST",
                              _cardInFrame,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _accusedPresent,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() => _accusedPresent = val ?? true);
                              },
                            ),
                            const Expanded(
                              child: Text(
                                "Presence of Accused / Independent Panchas (NDPS §52A)",
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Control Panel: Sample Switcher & Shutter Trigger
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Demo Sample Card Selector
                PopupMenuButton<String>(
                  icon: const Icon(Icons.collections, color: Colors.white70),
                  tooltip: "Test Sample Field Cards",
                  color: const Color(0xFF1E293B),
                  onSelected: (val) {
                    setState(() {
                      _selectedAssetSample = val;
                      if (val.contains("blurry")) {
                        _simulatedBlurVariance = 42.0; // Fails blur check!
                      } else {
                        _simulatedBlurVariance = 114.2; // Passes blur check
                      }
                    });
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'assets/field_sample_positive.png',
                      child: Text("Sample: Positive Heroin Reaction", style: TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'assets/field_sample_negative.png',
                      child: Text("Sample: Negative Reaction (Inert)", style: TextStyle(color: Colors.white)),
                    ),
                    const PopupMenuItem(
                      value: 'assets/field_sample_blurry.png',
                      child: Text("Sample: Blurry Field Image (Rejection Test)", style: TextStyle(color: Colors.amberAccent)),
                    ),
                  ],
                ),

                // Primary Shutter Button
                GestureDetector(
                  onTap: _processCapture,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isQualityPass ? const Color(0xFF2563EB) : Colors.grey.shade700,
                    ),
                    child: Center(
                      child: Icon(
                        _burstMode ? Icons.burst_mode : Icons.camera_alt,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),

                // Reset Reaction Timer Button
                IconButton(
                  icon: const Icon(Icons.restart_alt, color: Colors.white70),
                  tooltip: "Reset Reaction Timer",
                  onPressed: () {
                    setState(() {
                      _elapsedReactionSeconds = 0;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArUcoCorner(Alignment alignment, String label) {
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          border: Border.all(color: Colors.greenAccent, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildQualityIndicator(String label, String value, bool isOk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isOk ? Icons.check_circle : Icons.cancel, size: 12, color: isOk ? Colors.greenAccent : Colors.redAccent),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isOk ? Colors.white : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
