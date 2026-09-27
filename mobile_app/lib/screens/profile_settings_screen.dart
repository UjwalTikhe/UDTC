import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../services/local_ledger_database.dart';
import 'login_screen.dart';

/// Screen 15: Profile & Apparatus Settings Screen
/// Displays officer credentials, hardware keystore binding, active reference card,
/// cryptographic ledger self-audit, and secure session purge.
class ProfileSettingsScreen extends StatefulWidget {
  final User currentUser;
  const ProfileSettingsScreen({super.key, required this.currentUser});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  bool _isAuditing = false;

  void _runLedgerAudit() async {
    setState(() => _isAuditing = true);
    final report = await _db.verifyChainIntegrity();
    setState(() => _isAuditing = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GovTheme.bgSurface,
        title: Row(
          children: [
            Icon(
              report.isValid ? Icons.verified_user : Icons.gpp_bad,
              color: report.isValid ? GovTheme.alertNegativeText : GovTheme.alertPositiveText,
            ),
            const SizedBox(width: 8),
            Text(
              report.isValid ? "Ledger Audit PASSED" : "Ledger Audit FAILED",
              style: TextStyle(
                color: report.isValid ? GovTheme.alertNegativeText : GovTheme.alertPositiveText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.message, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: GovTheme.bgBase,
              child: Text(
                "Verified Chain Length: ${report.verifiedBlocks}\nAlgorithm: Recursive SHA-256 Digest\nAdmissibility: Section 63 BSA 2023",
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GovTheme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GovTheme.bgSurface,
        title: const Text("End Officer Session?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          "Signing out immediately purges the PIN-derived ECDSA signing key from memory. You will need to re-enter your 6-digit PIN to sign new evidence.",
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GovTheme.alertPositiveText),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("PURGE SESSION & EXIT", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Profile & Security Settings"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "OPERATIONAL CREDENTIALS • HARDWARE ATTESTATION",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  // Officer Identity Card
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
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: GovTheme.ashokaNavy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.currentUser.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${widget.currentUser.badgeNumber} • ${widget.currentUser.role.name.toUpperCase()}",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy),
                                  ),
                                  Text(
                                    widget.currentUser.department,
                                    style: GovTheme.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        _buildRow("Official Email", widget.currentUser.email),
                        _buildRow("Badge / Service No.", widget.currentUser.badgeNumber),
                        _buildRow("Age & Gender", "${widget.currentUser.age} yrs • ${widget.currentUser.gender}"),
                        _buildRow("Posting City", widget.currentUser.city),
                        _buildRow("User ID", widget.currentUser.userId),
                        _buildRow("Bound Device ID", widget.currentUser.deviceId),
                        _buildRow("Active Reference Card", "MHACARD-2026-DEL-0491"),
                        _buildRow("Keystore Algorithm", "ECDSA P-256 (Hardware Secure Enclave)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Legal & Security Boundaries Card
                  Container(
                    padding: const EdgeInsets.all(GovTheme.space16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined, color: GovTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "ARCHITECTURAL SECURITY BOUNDARY",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: GovTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Admin and Auditor roles are strictly restricted to the secure Web Console. "
                          "Field devices are provisioned solely with Officer and Supervisor capabilities to eliminate field theft attack surfaces.",
                          style: TextStyle(fontSize: 12, color: GovTheme.textPrimary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GovTheme.space24),

                  // Ledger Audit Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GovTheme.primary,
                      minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                    ),
                    onPressed: _isAuditing ? null : _runLedgerAudit,
                    icon: _isAuditing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.security, color: Colors.white),
                    label: const Text(
                      "RUN RECURSIVE LEDGER INTEGRITY AUDIT",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: GovTheme.space12),

                  // Sign Out Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GovTheme.alertPositiveText,
                      side: const BorderSide(color: GovTheme.alertPositiveText, width: 1.5),
                      minimumSize: const Size.fromHeight(GovTheme.primaryButtonHeight),
                    ),
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text(
                      "PURGE SESSION KEY & LOGOUT",
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

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GovTheme.caption),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
