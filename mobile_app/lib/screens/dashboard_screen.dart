import 'package:flutter/material.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import '../services/staged_sync_service.dart';
import '../services/crypto_signer_service.dart';
import 'camera_capture_screen.dart';
import 'ledger_screen.dart';
import 'sms_outbox_screen.dart';
import 'provisioning_screen.dart';
import 'record_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  final StagedSyncService _syncService = StagedSyncService.instance;
  final CryptoSignerService _signer = CryptoSignerService.instance;

  List<LocalRecordModel> _recentRecords = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  LedgerIntegrityReport? _integrityReport;
  String _topHash = "...";

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    _signer.initializeHardwareKeystore();
    await _db.seedInitialDemoDataIfEmpty();
    await _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    final records = await _db.getAllRecords(latestFirst: true);
    final topHash = await _db.getLastRecordHash();
    final integrity = await _db.verifyChainIntegrity();

    setState(() {
      _recentRecords = records;
      _topHash = topHash;
      _integrityReport = integrity;
      _isLoading = false;
    });
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final res = await _syncService.syncAllPendingRecords();
    await _refreshDashboard();
    setState(() => _isSyncing = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Sync complete: ${res['synced']}/${res['attempted']} records anchored to NCB backend."),
        backgroundColor: const Color(0xFF1E3A8A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _recentRecords.length;
    int posCount = _recentRecords.where((r) => r.classification.contains("POS")).length;
    int pendingSync = _recentRecords.where((r) => r.isStage1Synced == 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.shield, color: Colors.amberAccent, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "NCB Field Companion",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "SIH26231 — Forensic Field Testing",
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_sync),
            tooltip: "Trigger Staged Sync",
            onPressed: _isSyncing ? null : _triggerManualSync,
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: "Device Provisioning",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProvisioningScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : RefreshIndicator(
              onRefresh: _refreshDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Officer Identity Card
                    _buildOfficerCard(),
                    const SizedBox(height: 16),

                    // Quick Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            "Total Sealed",
                            "$totalCount",
                            Icons.layers,
                            Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            "Positives",
                            "$posCount",
                            Icons.warning_amber_rounded,
                            Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            "Pending Sync",
                            "$pendingSync",
                            Icons.cloud_upload,
                            Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Primary Capture Call-to-Action
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                      label: const Text(
                        "START FIELD TEST CAPTURE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CameraCaptureScreen(),
                          ),
                        );
                        _refreshDashboard();
                      },
                    ),
                    const SizedBox(height: 12),

                    // Secondary Navigation Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF334155)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.view_timeline, color: Colors.cyanAccent),
                            label: const Text(
                              "Hash Ledger",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LedgerScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF334155)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.sms, color: Colors.greenAccent),
                            label: const Text(
                              "2G SMS Outbox",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SmsOutboxScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Cryptographic Integrity Verification Banner
                    _buildIntegrityCard(),
                    const SizedBox(height: 20),

                    // Recent Field Records Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Recent Field Seizure Tests",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LedgerScreen()),
                            );
                          },
                          child: const Text("View All", style: TextStyle(color: Color(0xFF38BDF8))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_recentRecords.isEmpty)
                      const Card(
                        color: Color(0xFF1E293B),
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(
                            child: Text(
                              "No field tests recorded yet.\nTap 'Start Field Test Capture' above to begin.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._recentRecords.take(4).map((r) => _buildRecordItem(r)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOfficerCard() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFF2563EB),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "INSP. RAJESH KUMAR",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          "ID: NCB-DEL-042 | Delhi Zonal Unit",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        "HARDWARE SECURE",
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 24),
            Row(
              children: [
                const Icon(Icons.key, size: 14, color: Colors.amberAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Device Key: ${_signer.deviceKeyFingerprint}",
                    style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.gavel, size: 14, color: Colors.cyanAccent),
                SizedBox(width: 6),
                Text(
                  "Statutory Authority: NDPS Act §52A & BSA 2023 §63",
                  style: TextStyle(fontSize: 11, color: Colors.cyanAccent, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityCard() {
    final report = _integrityReport;
    final bool isValid = report?.isValid ?? true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFF7F1D1D).withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isValid ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.verified_user : Icons.gpp_bad,
                color: isValid ? Colors.greenAccent : Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isValid ? "Local Hash Chain: Mathematically Untampered" : "TAMPERING ALERT!",
                style: TextStyle(
                  color: isValid ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            report?.message ?? "All blocks cryptographically verified with SHA-256.",
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text("Top Hash: ", style: TextStyle(color: Colors.white54, fontSize: 11)),
              Expanded(
                child: Text(
                  _topHash,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(LocalRecordModel r) {
    final isPos = r.classification.contains("POS");
    final isInc = r.classification.contains("INC");
    final color = isPos ? Colors.redAccent : (isInc ? Colors.amberAccent : Colors.greenAccent);

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Text(
                      r.classification,
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text("Kit: ${r.kitType.replaceAll('_', ' ')}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const Spacer(),
                  Text("ΔE₀₀: ${r.deltaE2000.toStringAsFixed(2)}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
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
                    r.isStage1Synced == 1 ? Icons.cloud_done : Icons.cloud_queue,
                    size: 14,
                    color: r.isStage1Synced == 1 ? Colors.blueAccent : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    r.isStage1Synced == 1 ? "Stage 1 Synced" : "Offline Only",
                    style: TextStyle(color: r.isStage1Synced == 1 ? Colors.blueAccent : Colors.white54, fontSize: 11),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
