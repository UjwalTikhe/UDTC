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
        title: const Text("Assay Classification Result"),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: badgeFg, width: 2.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(badgeIcon, color: badgeFg, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                badgeLabel,
                                style: TextStyle(
                                  color: badgeFg,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 1, color: Colors.black12),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Forensic Match Confidence:",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: badgeFg.withOpacity(0.9),
                              ),
                            ),
                            Text(
                              "${classification.confidence.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 20,
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
                              Icon(Icons.shield_outlined, color: Color(0xFFB78103), size: 20),
                              SizedBox(width: 8),
                              Text(
                                "CROSS-REACTIVE INTERFERENT ADVISORY",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFB78103),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...classification.interferentWarnings.map(
                            (warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: const TextStyle(
                                        fontSize: 12.5,
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

                  // 3. Optical & Forensic Colorimeter Metrics Card
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
                        const Text(
                          "OPTICAL CALIBRATION EVIDENCE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: GovTheme.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildMetricRow("Assay Kit", selectedKit.displayName),
                        _buildMetricRow("Reagent Lot", reagentBatch),
                        _buildMetricRow("Reference Card Serial", cardSerial),
                        _buildMetricRow("CIEDE2000 ΔE Distance", "${deltaE.toStringAsFixed(2)} (Threshold: 8.5)"),
                        _buildMetricRow(
                          "Measured CIE L*a*b*",
                          "[L:${labValues[0].toStringAsFixed(1)}, a:${labValues[1].toStringAsFixed(1)}, b:${labValues[2].toStringAsFixed(1)}]",
                        ),
                        _buildMetricRow("Laplacian Blur Variance", "${laplacianVariance.toStringAsFixed(1)} (>=100)"),
                        _buildMetricRow(
                          "GPS Spatial Anchor",
                          location != null ? location.toString() : "LOCATION UNCONFIRMED",
                          isAlert: !locationConfirmed,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Actions: Retake vs Confirm & Record
            Container(
              padding: const EdgeInsets.all(GovTheme.space16),
              decoration: const BoxDecoration(
                color: GovTheme.bgSurface,
                border: Border(top: BorderSide(color: GovTheme.borderDefault)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                        foregroundColor: GovTheme.textSecondary,
                        side: const BorderSide(color: GovTheme.borderDefault, width: 1.5),
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
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text("RETAKE CAPTURE", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GovTheme.primary,
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
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
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.verified, color: Colors.white, size: 20),
                      label: const Text(
                        "CONFIRM & DUAL-SIGN",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
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

  Widget _buildMetricRow(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GovTheme.caption),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFamily: value.startsWith("[") || value.startsWith("NCB") ? 'monospace' : 'Roboto',
              color: isAlert ? GovTheme.alertPositiveText : GovTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
