import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import 'record_detail_screen.dart';

/// Screen 11: Seizure Test History & Hash-Chain Verification
/// GIGW 3.0 searchable evidence log with real-time SHA-256 chain verification.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  List<LocalRecordModel> _records = [];
  bool _isLoading = true;
  String _filter = "ALL"; // 'ALL', 'POSITIVE', 'NEGATIVE', 'PENDING_SYNC'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await _db.getAllRecords(latestFirst: true);
    setState(() {
      _records = list;
      _isLoading = false;
    });
  }

  void _verifyLedgerIntegrity() async {
    final report = await _db.verifyChainIntegrity();

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
              report.isValid ? "SHA-256 Chain Intact" : "Tamper Alert!",
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
            Text(
              report.message,
              style: const TextStyle(fontSize: 13, color: GovTheme.textPrimary, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GovTheme.bgBase,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "Total Verified Blocks: ${report.verifiedBlocks}\nAlgorithm: Recursive SHA-256 Digest\nAdmissibility: BSA 2023 Section 63",
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GovTheme.primary),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<LocalRecordModel> get _filteredRecords {
    var list = _records;

    if (_filter == "POSITIVE") {
      list = list.where((r) => r.classification.toUpperCase().contains("POS")).toList();
    } else if (_filter == "NEGATIVE") {
      list = list.where((r) => r.classification.toUpperCase().contains("NEG")).toList();
    } else if (_filter == "PENDING_SYNC") {
      list = list.where((r) => r.isStage1Synced == 0).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((r) {
        return r.testId.toLowerCase().contains(query) ||
            r.officerId.toLowerCase().contains(query) ||
            r.cardSerial.toLowerCase().contains(query);
      }).toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Seizure Test History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.security, color: Colors.amberAccent),
            tooltip: "Audit Chain Integrity",
            onPressed: _verifyLedgerIntegrity,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
              subtitleText: "STATUTORY RECORD REPOSITORY • NDPS §52A LEDGER",
            ),
            // Search Bar & Filter Chips
            Container(
              padding: const EdgeInsets.all(GovTheme.space16),
              color: GovTheme.bgSurface,
              child: Column(
                children: [
                  TextFormField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Search by Test ID, Officer, Card...",
                      hintStyle: GovTheme.caption,
                      prefixIcon: const Icon(Icons.search, color: GovTheme.primary),
                      filled: true,
                      fillColor: GovTheme.bgBase,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: GovTheme.borderDefault),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip("ALL", "All (${_records.length})"),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          "POSITIVE",
                          "Positive (${_records.where((r) => r.classification.contains('POS')).length})",
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          "NEGATIVE",
                          "Negative (${_records.where((r) => r.classification.contains('NEG')).length})",
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          "PENDING_SYNC",
                          "Pending Sync (${_records.where((r) => r.isStage1Synced == 0).length})",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: GovTheme.borderDefault),

            // History Records List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GovTheme.primary))
                  : _filteredRecords.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: GovTheme.textSecondary),
                              const SizedBox(height: 12),
                              Text("No evidentiary records matching criteria.", style: GovTheme.caption),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(GovTheme.space16),
                          itemCount: _filteredRecords.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final r = _filteredRecords[index];
                            final bool isPos = r.classification.contains("POS");
                            final bool isNeg = r.classification.contains("NEG");

                            final Color badgeBg = isPos
                                ? GovTheme.alertPositiveBg
                                : (isNeg ? GovTheme.alertNegativeBg : GovTheme.alertInconclusiveBg);
                            final Color badgeFg = isPos
                                ? GovTheme.alertPositiveText
                                : (isNeg ? GovTheme.alertNegativeText : GovTheme.alertInconclusiveText);

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecordDetailScreen(record: r),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(GovTheme.space16),
                                decoration: BoxDecoration(
                                  color: GovTheme.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: GovTheme.borderDefault),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 4,
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: GovTheme.ashokaNavy,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeBg,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: badgeFg),
                                          ),
                                          child: Text(
                                            isPos ? "POSITIVE" : (isNeg ? "NEGATIVE" : "INCONCLUSIVE"),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: badgeFg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      r.classification,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          "Kit: ${r.kitType} • ΔE: ${r.deltaE2000.toStringAsFixed(2)} • Card: ${r.cardSerial}",
                                          style: GovTheme.caption,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "SHA: ${r.recordHash.substring(0, 16)}...",
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: GovTheme.textSecondary,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Icon(
                                              r.isStage1Synced == 1 ? Icons.cloud_done : Icons.cloud_off,
                                              size: 14,
                                              color: r.isStage1Synced == 1
                                                  ? GovTheme.alertNegativeText
                                                  : GovTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              r.isStage1Synced == 1 ? "Synced" : "Local Only",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: r.isStage1Synced == 1
                                                    ? GovTheme.alertNegativeText
                                                    : GovTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final bool isSelected = _filter == key;
    return InkWell(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? GovTheme.primary : GovTheme.bgBase,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? GovTheme.primary : GovTheme.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : GovTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
