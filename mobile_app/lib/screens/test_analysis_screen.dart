import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/reagent_kit.dart';
import '../services/colorimeter_service.dart';
import '../services/location_service.dart';
import 'dual_signing_screen.dart';

class TestAnalysisScreen extends StatelessWidget {
  final ReagentKit reagentKit;
  final ColorimetryResult analysisResult;
  final String cardSerial;
  final LocationResult locationResult;
  final bool accusedPresent;
  final int elapsedReactionSeconds;
  final bool isReactionWindowValid;
  final String imageAssetPath;

  const TestAnalysisScreen({
    super.key,
    required this.reagentKit,
    required this.analysisResult,
    required this.cardSerial,
    required this.locationResult,
    required this.accusedPresent,
    required this.elapsedReactionSeconds,
    required this.isReactionWindowValid,
    required this.imageAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPos = analysisResult.classification.contains("POS");
    final bool isInc = analysisResult.classification.contains("INC");

    final Color badgeBg = isPos
        ? GovTheme.alertPositiveBg
        : (isInc ? GovTheme.alertInconclusiveBg : GovTheme.alertNegativeBg);
    final Color badgeFg = isPos
        ? GovTheme.alertPositiveText
        : (isInc ? GovTheme.alertInconclusiveText : GovTheme.alertNegativeText);

    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Colorimetry Analysis"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "COLORIMETRY ANALYSIS • NDPS ACT §52A",
            ),
            const StatutoryWarningBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(GovTheme.space16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Result Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeFg, width: 2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                isPos ? Icons.warning_amber_rounded : (isInc ? Icons.help_outline : Icons.check_circle),
                                color: badgeFg,
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  analysisResult.classification,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: badgeFg,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Confidence Score:", style: GovTheme.caption),
                              Text(
                                "${analysisResult.confidence.toStringAsFixed(1)}%",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: badgeFg),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: GovTheme.space16),

                    // Metrics Breakdown Card
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
                            "OPTICAL CALIBRATION DETAILS",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GovTheme.primary),
                          ),
                          const SizedBox(height: 10),
                          _buildRow("Target Substance", reagentKit.substanceTarget),
                          _buildRow("CIEDE2000 ΔE Distance", "${analysisResult.deltaE2000.toStringAsFixed(2)} (Standard < 8.5)"),
                          _buildRow("Reference Card Serial", cardSerial),
                          _buildRow("Reaction Duration", "${elapsedReactionSeconds}s (Valid Window: $isReactionWindowValid)"),
                          _buildRow("Accused Present", accusedPresent ? "YES (Mandatory NDPS §52A)" : "NO"),
                        ],
                      ),
                    ),
                    const SizedBox(height: GovTheme.space24),

                    // Navigation to Dual Signing
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GovTheme.primary,
                        minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DualSigningScreen(
                              reagentKit: reagentKit,
                              analysisResult: analysisResult,
                              cardSerial: cardSerial,
                              locationResult: locationResult,
                              accusedPresent: accusedPresent,
                              elapsedReactionSeconds: elapsedReactionSeconds,
                              isReactionWindowValid: isReactionWindowValid,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.lock_person, color: Colors.white),
                      label: const Text(
                        "PROCEED TO DUAL SIGNING",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GovTheme.caption),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
