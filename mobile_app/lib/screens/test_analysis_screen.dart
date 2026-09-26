import 'package:flutter/material.dart';
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
    final resultColor = isPos ? Colors.redAccent : (isInc ? Colors.amberAccent : Colors.greenAccent);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Deterministic Colorimetry Analysis"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Presumptive Decision Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: resultColor, width: 2),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isPos ? Icons.warning_rounded : (isInc ? Icons.help_outline : Icons.check_circle),
                        color: resultColor,
                        size: 32,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        analysisResult.classification.replaceAll('_', ' '),
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Target Substance: ${reagentKit.targetDrug}",
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Courtroom Confidence: ${analysisResult.confidenceScore}% | ΔE₀₀ = ${analysisResult.deltaE2000.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reagent Reaction Window Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isReactionWindowValid ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFF7F1D1D).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isReactionWindowValid ? Colors.greenAccent : Colors.redAccent),
              ),
              child: Row(
                children: [
                  Icon(
                    isReactionWindowValid ? Icons.timer : Icons.timer_off,
                    color: isReactionWindowValid ? Colors.greenAccent : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isReactionWindowValid
                          ? "Reaction Window Valid: Read at ${elapsedReactionSeconds}s (Window: ${reagentKit.minReactionTimeSeconds}s–${reagentKit.maxReactionTimeSeconds}s)"
                          : "REACTION WINDOW EXCEEDED: Read at ${elapsedReactionSeconds}s. Potential over-oxidation flag added.",
                      style: TextStyle(
                        color: isReactionWindowValid ? Colors.greenAccent : Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Color Swatch Comparison & CIEDE2000 Explanation
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CIE L*a*b* Colorimetric Evaluation",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Measured Well Color
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: analysisResult.measuredRgbColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text("Reaction Spot", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                "L*=${analysisResult.measuredLab[0].toStringAsFixed(1)} a*=${analysisResult.measuredLab[1].toStringAsFixed(1)} b*=${analysisResult.measuredLab[2].toStringAsFixed(1)}",
                                style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: Icon(Icons.compare_arrows, color: Colors.white38),
                        ),
                        // Expected Reagent Standard Color
                        Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: analysisResult.expectedRgbColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text("Reagent Standard", style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                "L*=${analysisResult.expectedLab[0].toStringAsFixed(1)} a*=${analysisResult.expectedLab[1].toStringAsFixed(1)} b*=${analysisResult.expectedLab[2].toStringAsFixed(1)}",
                                style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      analysisResult.legalExplanation,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata & Geotag Verification Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Chain of Custody & Geotag",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Divider(color: Color(0xFF334155), height: 18),
                    _buildMetaRow("Reference Card Serial", cardSerial),
                    _buildMetaRow(
                      "GPS Coordinates",
                      "${locationResult.latitude?.toStringAsFixed(4)}, ${locationResult.longitude?.toStringAsFixed(4)}",
                    ),
                    _buildMetaRow(
                      "Location Integrity",
                      locationResult.status,
                      valueColor: locationResult.isConfirmed ? Colors.greenAccent : Colors.amberAccent,
                    ),
                    _buildMetaRow(
                      "Accused Present (NDPS §52A)",
                      accusedPresent ? "CONFIRMED (Panchas Signed)" : "ABSENT / SEIZED UNATTENDED",
                      valueColor: accusedPresent ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Statutory Courtroom Disclaimer (NDPS §52A)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF334155).withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "MANDATORY LEGAL NOTICE: Under Section 52A of the NDPS Act, 1985, this digital screening test establishes presumptive evidentiary basis for seizure. Final judicial conviction requires quantitative analysis report by a Central/State Forensic Science Laboratory (FSL).",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Next Action: Proceed to Dual Signing
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.fingerprint, color: Colors.white),
              label: const Text(
                "PROCEED TO DUAL CRYPTOGRAPHIC SIGNING",
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                      imageAssetPath: imageAssetPath,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
