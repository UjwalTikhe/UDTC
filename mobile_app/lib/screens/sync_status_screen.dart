import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import '../services/staged_sync_service.dart';
import '../services/sms_anchor_service.dart';

/// Screen 13: Multi-Tier Sync Mesh & Out-of-Band Anchor Screen
/// Monitors 3-tier offline sync: Encrypted SQLite -> 2G GSM SMS -> Cloud/Mesh backend.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  final StagedSyncService _syncService = StagedSyncService.instance;
  final SmsAnchorService _smsService = SmsAnchorService.instance;

  List<LocalRecordModel> _pendingRecords = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _meshStatus = "Mesh Node Listening (BLE/Wi-Fi Direct Active)";

  @override
  void initState() {
    super.initState();
    _loadSyncQueue();
  }

  Future<void> _loadSyncQueue() async {
    setState(() => _isLoading = true);
    final records = await _db.getAllRecords(latestFirst: true);
    final pending = records.where((r) => r.isStage1Synced == 0).toList();

    setState(() {
      _pendingRecords = pending;
      _isLoading = false;
    });
  }

  Future<void> _triggerBatchSync() async {
    setState(() => _isSyncing = true);
    final res = await _syncService.syncAllPendingRecords();
    await _loadSyncQueue();
    setState(() => _isSyncing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sync Batch Finished: ${res['synced']}/${res['attempted']} anchored."),
        backgroundColor: GovTheme.primary,
      ),
    );
  }

  Future<void> _flushSmsOutbox() async {
    int sent = 0;
    for (final r in _pendingRecords.where((r) => r.isSmsWitnessed == 0)) {
      final ok = await _smsService.dispatchSmsAnchor(r);
      if (ok) sent++;
    }
    await _loadSyncQueue();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Dispatched $sent 2G SMS Witness anchors over cellular SIM."),
        backgroundColor: GovTheme.alertNegativeText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: const Text("Sync Mesh & Out-of-Band Queue"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "NARCOTICS CONTROL BUREAU",
              subtitleText: "DATA TRANSMISSION REPOSITORY • 3-TIER RESILIENCE",
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GovTheme.space16),
                children: [
                  // Sync Mesh Status Card
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
                            const Icon(Icons.hub_outlined, color: GovTheme.primary, size: 24),
                            const SizedBox(width: 8),
                            const Text(
                              "TACTICAL MESH STATUS",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: GovTheme.ashokaNavy,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: GovTheme.alertNegativeBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "READY",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: GovTheme.alertNegativeText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_meshStatus, style: GovTheme.caption),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Pending Cloud Sync", style: GovTheme.caption),
                                  Text(
                                    "${_pendingRecords.length} records",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Pending 2G SMS", style: GovTheme.caption),
                                  Text(
                                    "${_pendingRecords.where((r) => r.isSmsWitnessed == 0).length} records",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: GovTheme.space16),

                  // Actions Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GovTheme.primary,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: _isSyncing ? null : _triggerBatchSync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload, color: Colors.white, size: 18),
                          label: const Text(
                            "Sync Cloud",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: GovTheme.primary, width: 1.5),
                          ),
                          onPressed: _flushSmsOutbox,
                          icon: const Icon(Icons.sms, color: GovTheme.primary, size: 18),
                          label: const Text(
                            "Flush 2G SMS",
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GovTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GovTheme.space24),

                  const Text("Pending Transmission Queue", style: GovTheme.title),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: GovTheme.primary))
                  else if (_pendingRecords.isEmpty)
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
                            "All Field Evidence Records Fully Synchronized",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Both Cloud Merkle trees and 2G SMS witness hashes confirmed.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: GovTheme.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._pendingRecords.map((r) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: GovTheme.bgSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: GovTheme.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.testId,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: GovTheme.alertInconclusiveBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    "QUEUED",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: GovTheme.alertInconclusiveText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Hash: ${r.recordHash.substring(0, 24)}...",
                              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "2G Payload: ${r.toGsmSmsPayload()}",
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: GovTheme.textSecondary,
                              ),
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
