import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'camera_capture_screen.dart';
import 'record_confirm_screen.dart';

/// Screen 9: Forensic Result Screen
/// Authoritative statutory result presentation with high-contrast color badges,
/// confidence score, interferent warnings, and non-dismissible NDPS §52A notice.
class ResultScreen extends StatelessWidget {
  final User currentUser;
  final KitType selectedKit;
  final String reagentBatch;
  final String cardSerial;
  final TestSession session;
  final ClassificationResult classification;
  final double deltaE;
  final List<double> labValues;
  final GeoPoint? location;
  final bool locationConfirmed;
  final double laplacianVariance;
  final File? capturedImageFile;

  const ResultScreen({
    super.key,
    required this.currentUser,
    required this.selectedKit,
    required this.reagentBatch,
    required this.cardSerial,
    required this.session,
    required this.classification,
    required this.deltaE,
    required this.labValues,
    this.location,
    required this.locationConfirmed,
    required this.laplacianVariance,
    this.capturedImageFile,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPos = classification.category == ResultCategory.positive;
    final bool isNeg = classification.category == ResultCategory.negative;

    final Color badgeBg = isPos
        ? GovTheme.alertPositiveBg
        : (isNeg ? GovTheme.alertNegativeBg : GovTheme.alertInconclusiveBg);

    final Color badgeFg = isPos
        ? GovTheme.alertPositiveText
        : (isNeg ? GovTheme.alertNegativeText : GovTheme.alertInconclusiveText);

    final IconData badgeIcon = isPos
        ? Icons.warning_amber_rounded
        : (isNeg ? Icons.check_circle_outline_rounded : Icons.help_outline_rounded);

    final String badgeLabel = isPos
        ? "PRESUMPTIVE POSITIVE: CONTRABAND DETECTED"
        : (isNeg
            ? "PRESUMPTIVE NEGATIVE: NO TARGET DRUG DETECTED"
            : "INCONCLUSIVE: RETEST OR LAB CHROMATOGRAPHY REQUIRED");

    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Assay Classification Result", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "STEP 5 OF 6: STATUTORY CLASSIFICATION OUTCOME",
            ),
            // Persistent Non-Dismissible Warning Banner
            const StatutoryWarningBanner(
              text: "PRESUMPTIVE RESULT ONLY: Mandatory confirmatory laboratory testing required under NDPS Act §52A and BSA 2023 §63 before submission to trial court.",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  // 1. Prominent High-Contrast Result Badge (Icon + Text + Tint)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(GovTheme.space20),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeFg, width: 2.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(badgeIcon, color: badgeFg, size: 40),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeFg,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, thickness: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Forensic Match Confidence:",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: badgeFg.withOpacity(0.9),
                              ),
                            ),
                            Text(
                              "${classification.confidence.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: badgeFg,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // 2. Interferent Warnings Callout Box (if applicable)
                  if (classification.interferentWarnings.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(GovTheme.space16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFFB78103), size: 22),
                              SizedBox(width: 8),
                              Text(
                                "CROSS-REACTIVE INTERFERENT ADVISORY",
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFB78103),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...classification.interferentWarnings.map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF5D4037),
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GovTheme.space16),
                  ],

                  // 2. Captured Watermarked Evidence Photo Preview
                  if (capturedImageFile != null && capturedImageFile!.existsSync()) ...[
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GovTheme.ashokaNavy, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.file(
                              capturedImageFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            color: GovTheme.ashokaNavy,
                            child: Row(
                              children: const [
                                Icon(Icons.verified, color: Colors.amberAccent, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "EVIDENCE PHOTO: Live GPS Coordinates & Officer Badge Stamped",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GovTheme.space16),
                  ],

                  // 3. Optical & Forensic Colorimeter Metrics Card (Clean 2-Column Forensic Report Layout)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: GovTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: GovTheme.borderDefault),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.analytics_outlined, color: GovTheme.ashokaNavy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "FIELD TEST EVIDENCE & ACCURACY",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: GovTheme.ashokaNavy,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildMetricRow("Substance Tested", selectedKit.targetSubstance),
                        _buildMetricRow("Field Test Kit", selectedKit.displayName),
                        _buildMetricRow("Reagent Lot No.", reagentBatch),
                        _buildMetricRow("Reference Card Serial", cardSerial),
                        _buildMetricRow(
                          "Color Match Accuracy",
                          "${classification.confidence.toStringAsFixed(1)}% (ΔE: ${deltaE.toStringAsFixed(2)})",
                          isHighlighted: true,
                        ),
                        _buildMetricRow(
                          "Photo Clarity / Focus",
                          "${laplacianVariance.toStringAsFixed(1)} (In Focus)",
                        ),
                        _buildMetricRow(
                          "Live GPS Crime Scene",
                          location != null
                              ? "${location!.latitude.toStringAsFixed(5)}° N, ${location!.longitude.toStringAsFixed(5)}° E"
                              : "LOCATION UNCONFIRMED",
                          isAlert: !locationConfirmed,
                        ),
                        _buildMetricRow("Evidence Status", "Digitally Sealed under NDPS §52A", isLast: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions: Large Touch Target Stacked Buttons (Zero Overlap & Zero Text Wrapping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: GovTheme.bgSurface,
                border: Border(top: BorderSide(color: GovTheme.borderDefault, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GovTheme.primary,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecordConfirmScreen(
                            currentUser: currentUser,
                            selectedKit: selectedKit,
                            reagentBatch: reagentBatch,
                            cardSerial: cardSerial,
                            session: session,
                            classification: classification,
                            deltaE: deltaE,
                            labValues: labValues,
                            location: location,
                            locationConfirmed: locationConfirmed,
                            laplacianVariance: laplacianVariance,
                            capturedImageFile: capturedImageFile,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.verified, color: Colors.white, size: 22),
                    label: const Text(
                      "CONFIRM & DUAL-SIGN EVIDENCE",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: GovTheme.ashokaNavy,
                      side: const BorderSide(color: GovTheme.borderDefault, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraCaptureScreen(
                            currentUser: currentUser,
                            selectedKit: selectedKit,
                            reagentBatch: reagentBatch,
                            cardSerial: cardSerial,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay, size: 20),
                    label: const Text(
                      "RETAKE CAPTURE / RE-SCAN ASSAY",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildMetricRow(String label, String value, {bool isAlert = false, bool isHighlighted = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isHighlighted ? GovTheme.primary.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: GovTheme.borderDefault.withOpacity(0.6), width: 0.8),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: GovTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                fontFamily: value.startsWith("[") || value.startsWith("MHA") ? 'monospace' : 'Roboto',
                color: isAlert ? GovTheme.alertPositiveText : GovTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
