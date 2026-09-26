import 'package:flutter/material.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import 'record_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  List<LocalRecordModel> _records = [];
  bool _isLoading = true;
  String _filter = "ALL"; // 'ALL', 'POSITIVE', 'UNSYNCED'

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger() async {
    setState(() => _isLoading = true);
    final list = await _db.getAllRecords(latestFirst: true);
    setState(() {
      _records = list;
      _isLoading = false;
    });
  }

  void _runChainIntegrityCheck() async {
    final report = await _db.verifyChainIntegrity();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            Icon(
              report.isValid ? Icons.verified : Icons.gpp_bad,
              color: report.isValid ? Colors.greenAccent : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Text(
              report.isValid ? "Chain Integrity Verified" : "Tampering Detected!",
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(report.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 8),
            Text("Total Blocks Scanned: ${report.totalBlocks}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text("Algorithm: SHA-256 Recursive Chain H_n = H(Data_n || H_{n-1})", style: TextStyle(color: Colors.white54, fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<LocalRecordModel> filtered = _records;
    if (_filter == "POSITIVE") {
      filtered = _records.where((r) => r.classification.contains("POS")).toList();
    } else if (_filter == "UNSYNCED") {
      filtered = _records.where((r) => r.isStage1Synced == 0).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Local Append-Only Ledger"),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: const Icon(Icons.verified_user, color: Colors.greenAccent),
            tooltip: "Verify Cryptographic Chain",
            onPressed: _runChainIntegrityCheck,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : Column(
              children: [
                // Filter Chips
                Container(
                  color: const Color(0xFF1E293B),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip("ALL", "All (${_records.length})"),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "POSITIVE",
                        "Positives (${_records.where((r) => r.classification.contains('POS')).length})",
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "UNSYNCED",
                        "Pending (${_records.where((r) => r.isStage1Synced == 0).length})",
                      ),
                    ],
                  ),
                ),

                // Blockchain List View
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text("No records found for current filter.", style: TextStyle(color: Colors.white70)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final r = filtered[index];
                            final isPos = r.classification.contains("POS");
                            final isInc = r.classification.contains("INC");
                            final badgeColor = isPos ? Colors.redAccent : (isInc ? Colors.amberAccent : Colors.greenAccent);

                            return Column(
                              children: [
                                Card(
                                  color: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => RecordDetailScreen(record: r)),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                r.testId,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: badgeColor.withOpacity(0.5)),
                                                ),
                                                child: Text(
                                                  r.classification,
                                                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Kit: ${r.kitType} | ΔE₀₀: ${r.deltaE2000.toStringAsFixed(2)} | Confidence: ${r.confidence}%",
                                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.link, size: 14, color: Colors.amberAccent),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  "Hash: ${r.recordHash.substring(0, 24)}...",
                                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace'),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(color: Color(0xFF334155), height: 16),
                                          Row(
                                            children: [
                                              Icon(
                                                r.isSmsWitnessed == 1 ? Icons.sms : Icons.sms_failed,
                                                size: 14,
                                                color: r.isSmsWitnessed == 1 ? Colors.greenAccent : Colors.white38,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.isSmsWitnessed == 1 ? "2G SMS Anchored" : "SMS Pending",
                                                style: TextStyle(color: r.isSmsWitnessed == 1 ? Colors.greenAccent : Colors.white54, fontSize: 11),
                                              ),
                                              const Spacer(),
                                              Icon(
                                                r.isStage1Synced == 1 ? Icons.cloud_done : Icons.cloud_off,
                                                size: 14,
                                                color: r.isStage1Synced == 1 ? Colors.blueAccent : Colors.white38,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.isStage1Synced == 1 ? "Stage 1 Synced" : "Local Only",
                                                style: TextStyle(color: r.isStage1Synced == 1 ? Colors.blueAccent : Colors.white54, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (index < filtered.length - 1)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4.0),
                                    child: Icon(Icons.arrow_downward, size: 16, color: Colors.white30),
                                  ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
