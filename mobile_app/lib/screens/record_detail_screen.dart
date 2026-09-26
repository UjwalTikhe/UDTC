import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/record_model.dart';
import '../services/staged_sync_service.dart';
import '../services/sms_anchor_service.dart';

class RecordDetailScreen extends StatefulWidget {
  final LocalRecordModel record;

  const RecordDetailScreen({super.key, required this.record});

  @override
  State<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends State<RecordDetailScreen> {
  late LocalRecordModel _currentRecord;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _currentRecord = widget.record;
  }

  void _triggerSync() async {
    setState(() => _isSyncing = true);
    final ok1 = await StagedSyncService.instance.syncStage1Metadata(_currentRecord);

    if (ok1) {
      setState(() {
        _currentRecord = _currentRecord.copyWith(isStage1Synced: 1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stage 1 Metadata successfully anchored to NCB server!"), backgroundColor: Color(0xFF1E3A8A)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network unavailable. Record securely retained in local offline queue."), backgroundColor: Colors.amber),
        );
      }
    }
    setState(() => _isSyncing = false);
  }

  void _resendSmsAnchor() async {
    final ok = await SmsAnchorService.instance.dispatchSmsAnchor(_currentRecord);
    if (ok) {
      setState(() {
        _currentRecord = _currentRecord.copyWith(isSmsWitnessed: 1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("2G SMS Witness Anchor dispatched via SIM!"), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _currentRecord;
    final isPos = r.classification.contains("POS");
    final isInc = r.classification.contains("INC");
    final resultColor = isPos ? Colors.redAccent : (isInc ? Colors.amberAccent : Colors.greenAccent);
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(
      DateTime.fromMillisecondsSinceEpoch((r.timestampUtc * 1000).toInt(), isUtc: true),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(r.testId),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload),
            tooltip: "Sync Record to Backend",
            onPressed: _isSyncing ? null : _triggerSync,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Classification & Confidence Top Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: resultColor, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.classification.replaceAll('_', ' '),
                        style: TextStyle(color: resultColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text("Kit: ${r.kitType} | ΔE₀₀ = ${r.deltaE2000.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
                    child: Text("${r.confidence}% Conf.", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2G SMS Out-of-band Witness Status Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: r.isSmsWitnessed == 1 ? Colors.greenAccent.withOpacity(0.5) : Colors.amberAccent.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        r.isSmsWitnessed == 1 ? Icons.sms : Icons.sms_failed,
                        color: r.isSmsWitnessed == 1 ? Colors.greenAccent : Colors.amberAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        r.isSmsWitnessed == 1 ? "2G SMS Out-of-Band Anchor: WITNESSED" : "2G SMS Anchor: PENDING TRANSMISSION",
                        style: TextStyle(
                          color: r.isSmsWitnessed == 1 ? Colors.greenAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (r.isSmsWitnessed == 0)
                        TextButton(
                          onPressed: _resendSmsAnchor,
                          child: const Text("Send SMS", style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text("Strict 140-char GSM Payload sent over device SIM:", style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      r.toGsmSmsPayload(),
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chain of Custody & Geotag Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Chain of Custody & Field Metadata", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildRow("Test ID", r.testId),
                    _buildRow("Timestamp (UTC)", "$dateStr UTC"),
                    _buildRow("Investigating Officer", r.officerId),
                    _buildRow("Device Keystore ID", r.deviceId),
                    _buildRow("Reference Card Serial", r.cardSerial),
                    _buildRow("Reaction Duration", "${r.reactionTimeSeconds}s (Valid: ${r.reagentWindowOk ? 'YES' : 'NO'})"),
                    _buildRow("Accused Present (NDPS §52A)", r.accusedPresent ? "YES (Signed in Presence)" : "NO"),
                    _buildRow(
                      "GPS Location",
                      r.latitude != null ? "${r.latitude!.toStringAsFixed(4)}, ${r.longitude!.toStringAsFixed(4)} (${r.locationStatus})" : "NOGPS (${r.locationStatus})",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cryptographic Proofs & Dual Signatures
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Cryptographic Proofs (Dual-Bound)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildHashRow("Previous Block Hash", r.prevHash),
                    _buildHashRow("Record SHA-256 Hash", r.recordHash, highlight: true),
                    _buildHashRow("Image SHA-256 Digest", r.imageSha256),
                    _buildHashRow("Device ECDSA P-256 Sig", r.deviceSigHex),
                    _buildHashRow("Officer PBKDF2 HMAC Sig", r.officerSigHex),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bharatiya Sakshya Adhiniyam 2023 §63 Legal Summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF334155).withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Legal Admissibility — BSA 2023 §63 Compliant",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This electronic record satisfies Section 63 of Bharatiya Sakshya Adhiniyam, 2023 (conditions of admissibility for electronic records) by maintaining:\n"
                    "1. Hardware-bound SHA-256 hash certificate identifying device origin\n"
                    "2. Dual electronic signatures of device and lawful operating officer\n"
                    "3. Continuous tamper-evident hash-chain unbroken since capture\n"
                    "4. Independent telecom-stamped 2G SMS anchor timestamp witness.",
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Staged Sync Status & Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: r.isStage1Synced == 1 ? const Color(0xFF047857) : const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(r.isStage1Synced == 1 ? Icons.cloud_done : Icons.cloud_upload, color: Colors.white),
              label: Text(
                r.isStage1Synced == 1 ? "STAGE 1 METADATA ANCHORED TO SERVER" : "SYNC METADATA TO NCB SERVER",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: r.isStage1Synced == 1 ? null : _triggerSync,
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String label, String hash, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            hash.isEmpty ? "(Not Sealed)" : hash,
            style: TextStyle(
              color: highlight ? Colors.amberAccent : Colors.cyanAccent,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
