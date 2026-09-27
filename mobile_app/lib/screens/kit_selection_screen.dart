import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'card_scan_screen.dart';
import 'camera_capture_screen.dart';

/// Screen 4: Kit Selection Screen
/// Forensic selection of certified government drug testing kit (NDDK, PCDK, KDK)
/// according to NDPS field manual testing standards.
class KitSelectionScreen extends StatefulWidget {
  final User currentUser;
  const KitSelectionScreen({super.key, required this.currentUser});

  @override
  State<KitSelectionScreen> createState() => _KitSelectionScreenState();
}

class _KitSelectionScreenState extends State<KitSelectionScreen> {
  KitType _selectedKit = KitType.nddk;
  final TextEditingController _batchController = TextEditingController(text: "MHA-BATCH-2026-09B");

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  void _proceedToCardScan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardScanScreen(
          currentUser: widget.currentUser,
          selectedKit: _selectedKit,
          reagentBatch: _batchController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Select Test Kit"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "STEP 1 OF 6: REAGENT ASSAY SPECIFICATION",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  const Text(
                    "Reagent Kit Selection",
                    style: GovTheme.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Select the authorized reagent assay matching the suspected substance.",
                    style: GovTheme.caption,
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Option 1: NDDK
                  _buildKitCard(
                    type: KitType.nddk,
                    title: "NDDK — General Narcotics Assay",
                    reagents: "Marquis Reagent (Formaldehyde + Sulfuric Acid)",
                    target: "Opium, Morphine, Heroin, Codeine",
                    reactionTime: "45 Seconds",
                    colorShift: "Expected Positive: Deep Purple / Violet",
                    icon: Icons.science,
                  ),
                  const SizedBox(height: GovTheme.space12),

                  // Option 2: PCDK
                  _buildKitCard(
                    type: KitType.pcdk,
                    title: "PCDK — Plant Cannabinoid Assay",
                    reagents: "Duquenois-Levine Reagent (Vanillin + Acetaldehyde)",
                    target: "Cannabis, Hashish, Charas, Ganja",
                    reactionTime: "60 Seconds",
                    colorShift: "Expected Positive: Indigo-Blue / Violet in Chloroform",
                    icon: Icons.grass,
                  ),
                  const SizedBox(height: GovTheme.space12),

                  // Option 3: KDK
                  _buildKitCard(
                    type: KitType.kdk,
                    title: "KDK — Cocaine & Stimulants Assay",
                    reagents: "Scott Reagent (Cobalt Thiocyanate + Glycerin)",
                    target: "Cocaine HCl, Crack, Methamphetamine",
                    reactionTime: "30 Seconds",
                    colorShift: "Expected Positive: Cobalt Blue Precipitate",
                    icon: Icons.biotech,
                  ),
                  const SizedBox(height: GovTheme.space24),

                  // Reagent Batch Verification Card
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
                          "REAGENT LOT / BATCH NUMBER",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: GovTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _batchController,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: GovTheme.bgBase,
                            prefixIcon: const Icon(Icons.qr_code_2, color: GovTheme.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: GovTheme.borderDefault),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.verified, size: 14, color: GovTheme.alertNegativeText),
                            const SizedBox(width: 4),
                            Text(
                              "Expiry: 2027-12-31 • Quality Control Passed",
                              style: GovTheme.caption.copyWith(color: GovTheme.alertNegativeText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GovTheme.space16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GovTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraCaptureScreen(
                            currentUser: widget.currentUser,
                            selectedKit: _selectedKit,
                            reagentBatch: _batchController.text.trim(),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    label: const Text(
                      "LAUNCH FIELD CAMERA & GPS",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _proceedToCardScan,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text(
                      "Manual Card Scan Protocol (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

  Widget _buildKitCard({
    required KitType type,
    required String title,
    required String reagents,
    required String target,
    required String reactionTime,
    required String colorShift,
    required IconData icon,
  }) {
    final bool isSelected = _selectedKit == type;

    return InkWell(
      onTap: () => setState(() => _selectedKit = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(GovTheme.space16),
        decoration: BoxDecoration(
          color: isSelected ? GovTheme.bgSurface : GovTheme.bgBase,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? GovTheme.primary : GovTheme.borderDefault,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: GovTheme.primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? GovTheme.primary : GovTheme.borderDefault.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : GovTheme.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? GovTheme.primary : GovTheme.textPrimary,
                          ),
                        ),
                      ),
                      Radio<KitType>(
                        value: type,
                        groupValue: _selectedKit,
                        activeColor: GovTheme.primary,
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedKit = val);
                        },
                      ),
                    ],
                  ),
                  Text("Reagent: $reagents", style: GovTheme.caption),
                  const SizedBox(height: 4),
                  Text("Target: $target", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GovTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Timer: $reactionTime",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GovTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          colorShift,
                          style: const TextStyle(fontSize: 11, color: GovTheme.textSecondary, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
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
    );
  }
}
