import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import 'card_scan_screen.dart';

/// Screen 4: Kit Selection Screen (Step 1)
/// Three selectable cards, equal width, stacked vertically:
/// Card 1 — "NDDK" — Narcotic Drugs Detection Kit — subtitle: "Opiates, cannabis, cocaine, amphetamines"
/// Card 2 — "PCDK" — Precursor Chemicals Detection Kit — subtitle: "Precursor chemicals used in synthesis"
/// Card 3 — "KDK" — Ketamine Detection Kit — subtitle: "Ketamine"
/// Each card: white surface (#FFFFFF), 16dp padding, 16dp corner radius, icon + title + subtitle, full tap target.
class KitSelectionScreen extends StatefulWidget {
  final User currentUser;
  const KitSelectionScreen({super.key, required this.currentUser});

  @override
  State<KitSelectionScreen> createState() => _KitSelectionScreenState();
}

class _KitSelectionScreenState extends State<KitSelectionScreen> {
  final TextEditingController _batchController = TextEditingController(text: "MHA-BATCH-2026-09B");

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  void _onKitSelected(KitType kit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardScanScreen(
          currentUser: widget.currentUser,
          selectedKit: kit,
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
              subtitleText: "STEP 1 OF 6: SELECT REAGENT ASSAY KIT",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  const Text(
                    "Kit Selection",
                    style: GovTheme.title,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Select authorized reagent kit to initiate reference card validation and test sequence.",
                    style: GovTheme.caption,
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Card 1: NDDK
                  _buildStackedKitCard(
                    kit: KitType.nddk,
                    title: "NDDK",
                    fullName: "Narcotic Drugs Detection Kit",
                    subtitle: "Opiates, cannabis, cocaine, amphetamines",
                    reagentDetail: "Marquis primary reagent • 45s kinetic timer",
                    icon: Icons.science,
                    iconBgColor: const Color(0xFF5B1647),
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Card 2: PCDK
                  _buildStackedKitCard(
                    kit: KitType.pcdk,
                    title: "PCDK",
                    fullName: "Precursor Chemicals Detection Kit",
                    subtitle: "Precursor chemicals used in synthesis",
                    reagentDetail: "Duquenois-Levine reagent • 60s kinetic timer",
                    icon: Icons.biotech,
                    iconBgColor: const Color(0xFF1E4B8F),
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Card 3: KDK
                  _buildStackedKitCard(
                    kit: KitType.kdk,
                    title: "KDK",
                    fullName: "Ketamine Detection Kit",
                    subtitle: "Ketamine",
                    reagentDetail: "Scott reagent (Cobalt thiocyanate) • 30s kinetic timer",
                    icon: Icons.grain,
                    iconBgColor: const Color(0xFF0F3BBF),
                  ),
                  const SizedBox(height: GovTheme.space24),

                  // Reagent Lot / Batch Number Container
                  Container(
                    padding: const EdgeInsets.all(GovTheme.space16),
                    decoration: BoxDecoration(
                      color: GovTheme.bgSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GovTheme.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "REAGENT LOT / BATCH NUMBER",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: GovTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _batchController,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: GovTheme.bgBase,
                            prefixIcon: const Icon(Icons.qr_code_2, color: GovTheme.primary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
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
                              "Quality Control Passed • Expiry 2027-12-31",
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
          ],
        ),
      ),
    );
  }

  Widget _buildStackedKitCard({
    required KitType kit,
    required String title,
    required String fullName,
    required String subtitle,
    required String reagentDetail,
    required IconData icon,
    required Color iconBgColor,
  }) {
    return Material(
      color: const Color(0xFFFFFFFF), // White surface
      borderRadius: BorderRadius.circular(16), // 16dp corner radius
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () => _onKitSelected(kit), // Full tap target on whole card
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(GovTheme.space16), // 16dp padding
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GovTheme.borderDefault, width: 1.2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Badge with 48dp touch target clearance
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBgColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconBgColor, size: 28),
              ),
              const SizedBox(width: 14),
              // Title + Full Name + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: GovTheme.ashokaNavy,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "($fullName)",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: GovTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GovTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reagentDetail,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: GovTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron indicator
              const Icon(Icons.arrow_forward_ios, size: 16, color: GovTheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
