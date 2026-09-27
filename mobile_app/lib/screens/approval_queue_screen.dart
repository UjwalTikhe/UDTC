import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import '../services/crypto_signer_service.dart';

/// Screen 14: Approval Queue Screen (Supervisor Role Only)
/// Thin-slice mobile capability for field supervisors: high-stakes commercial quantity
/// co-signing, legal evidence export authorization, and chain audits.
class ApprovalQueueScreen extends StatefulWidget {
  final User currentUser;
  const ApprovalQueueScreen({super.key, required this.currentUser});

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  List<LocalRecordModel> _highStakesRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final all = await _db.getAllRecords(latestFirst: true);
    // High-stakes filter: positive records requiring supervisory co-signing
    final positives = all.where((r) => r.classification.contains("POS")).toList();

    setState(() {
      _highStakesRecords = positives;
      _isLoading = false;
    });
  }

  Future<void> _coSignRecord(LocalRecordModel record) async {
    final signer = CryptoSignerService.instance;
    final supervisorSig = signer.signWithDeviceHardware("SUPERVISOR_COSIGN|${record.testId}");

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GovTheme.bgSurface,
        title: Row(
          children: const [
            Icon(Icons.verified, color: GovTheme.alertNegativeText),
            SizedBox(width: 8),
            Text("Supervisory Co-Sign Affixed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Supervisor ${widget.currentUser.badgeNumber} has cryptographically co-signed Test ID ${record.testId}.",
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              color: GovTheme.bgBase,
              child: Text(
                "Supervisor Sig:\n${supervisorSig.substring(0, 32)}...\nTimestamp: ${DateTime.now().toUtc()} UTC",
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Supervisory Approvals"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
              subtitleText: "SUPERVISORY AUDIT & DUAL-SIGN DISPATCH WING",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  // Role Clearance Card
                  Container(
                    padding: const EdgeInsets.all(GovTheme.space16),
                    decoration: BoxDecoration(
                      color: GovTheme.ashokaNavy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: Colors.amberAccent, size: 36),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "SUPERVISOR AUTHORIZATION ACTIVE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Supervisor: ${widget.currentUser.badgeNumber} • Section 52A NDPS Approval Authority",
                                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GovTheme.space24),

                  const Text("Commercial / High-Stakes Co-Sign Queue", style: GovTheme.title),
                  const SizedBox(height: 4),
                  Text(
                    "Positive field seizures requiring mandatory secondary supervisor cryptographic co-signature.",
                    style: GovTheme.caption,
                  ),
                  const SizedBox(height: GovTheme.space16),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: GovTheme.primary))
                  else if (_highStakesRecords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: GovTheme.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GovTheme.borderDefault),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.check_circle_outline, color: GovTheme.alertNegativeText, size: 40),
                          SizedBox(height: 8),
                          Text(
                            "Approval Queue Clear",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "No pending high-stakes seizures awaiting co-signature.",
                            style: TextStyle(fontSize: 12, color: GovTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._highStakesRecords.map((r) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(GovTheme.space16),
                        decoration: BoxDecoration(
                          color: GovTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GovTheme.borderDefault),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.testId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: GovTheme.ashokaNavy,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: GovTheme.alertPositiveBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: GovTheme.alertPositiveText),
                                  ),
                                  child: const Text(
                                    "AWAITING CO-SIGN",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: GovTheme.alertPositiveText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.classification,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Seizing Officer: ${r.officerId} • CIEDE2000 ΔE: ${r.deltaE2000.toStringAsFixed(2)}",
                              style: GovTheme.caption,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Block SHA: ${r.recordHash.substring(0, 24)}...",
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: GovTheme.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: GovTheme.primary,
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                    onPressed: () => _coSignRecord(r),
                                    icon: const Icon(Icons.verified, size: 16, color: Colors.white),
                                    label: const Text(
                                      "CO-SIGN SEIZURE",
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
