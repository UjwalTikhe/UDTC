import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'camera_capture_screen.dart';

/// Screen 6: Reaction Timer Screen
/// Enforces statutory chemical reaction stabilization window before optical capture.
class ReactionTimerScreen extends StatefulWidget {
  final User currentUser;
  final KitType selectedKit;
  final String reagentBatch;
  final String cardSerial;

  const ReactionTimerScreen({
    super.key,
    required this.currentUser,
    required this.selectedKit,
    required this.reagentBatch,
    required this.cardSerial,
  });

  @override
  State<ReactionTimerScreen> createState() => _ReactionTimerScreenState();
}

class _ReactionTimerScreenState extends State<ReactionTimerScreen> {
  late int _totalDuration;
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isWindowActive = false;

  @override
  void initState() {
    super.initState();
    _totalDuration = widget.selectedKit.reactionWindowSeconds;
    // For fast field demo convenience, start at 10 seconds or full duration
    _remainingSeconds = _totalDuration > 15 ? 15 : _totalDuration;
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 3) {
            _isWindowActive = true;
          }
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _isWindowActive = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _proceedToCapture() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(
          currentUser: widget.currentUser,
          selectedKit: widget.selectedKit,
          reagentBatch: widget.reagentBatch,
          cardSerial: widget.cardSerial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_totalDuration - _remainingSeconds) / _totalDuration;

    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Reaction Stabilization"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
              subtitleText: "STEP 3 OF 6: CHEMICAL CHROMOPHORE STABILIZATION",
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(GovTheme.space24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Assay Indicator Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: GovTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GovTheme.primary),
                      ),
                      child: Text(
                        widget.selectedKit.displayName,
                        style: const TextStyle(
                          color: GovTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: GovTheme.space24),

                    // Countdown Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CircularProgressIndicator(
                            value: _remainingSeconds == 0 ? 1.0 : progress.clamp(0.0, 1.0),
                            strokeWidth: 14,
                            backgroundColor: GovTheme.borderDefault,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isWindowActive ? GovTheme.alertNegativeText : GovTheme.primary,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$_remainingSeconds",
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: _isWindowActive ? GovTheme.alertNegativeText : GovTheme.ashokaNavy,
                              ),
                            ),
                            Text(
                              _remainingSeconds == 0 ? "OPTIMAL WINDOW" : "SECONDS REMAINING",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _isWindowActive ? GovTheme.alertNegativeText : GovTheme.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: GovTheme.space32),

                    // Chemical Status Guide
                    Container(
                      padding: const EdgeInsets.all(GovTheme.space16),
                      decoration: BoxDecoration(
                        color: GovTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GovTheme.borderDefault),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isWindowActive ? Icons.verified : Icons.hourglass_top,
                                color: _isWindowActive ? GovTheme.alertNegativeText : GovTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isWindowActive
                                    ? "STABILIZED: Valid Chromophore Measurement Window"
                                    : "Stabilizing Reagent Chromophore...",
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: _isWindowActive ? GovTheme.alertNegativeText : GovTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Do not disturb reagent pouch. Optical calibration requires full chemical kinetic plateau to prevent false positives.",
                            style: GovTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Shutter Progression Button
            Padding(
              padding: const EdgeInsets.all(GovTheme.space16),
              child: ElevatedButton.icon(
                onPressed: _isWindowActive ? _proceedToCapture : null,
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                label: Text(
                  _isWindowActive
                      ? "PROCEED TO OPTICAL CAPTURE"
                      : "WAITING FOR STABILIZATION ($_remainingSeconds s)",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWindowActive ? GovTheme.primary : Colors.grey.shade400,
                  minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                ),
              ),
            ),
            const StatutoryWarningBanner(
              text: "Forensic Rule: Tests imaged before the kinetic window are legally inadmissible under NDPS §52A.",
            ),
          ],
        ),
      ),
    );
  }
}
