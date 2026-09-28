import 'package:flutter/material.dart';
import '../theme/gov_theme.dart';
import '../models/domain_models.dart';
import '../models/record_model.dart';
import '../services/local_ledger_database.dart';
import '../services/staged_sync_service.dart';
import '../services/crypto_signer_service.dart';
import '../repositories/field_record_repository.dart';
import 'kit_selection_screen.dart';
import 'camera_capture_screen.dart';
import 'history_screen.dart';
import 'record_detail_screen.dart';
import 'sync_status_screen.dart';
import 'approval_queue_screen.dart';
import 'profile_settings_screen.dart';
import 'login_screen.dart';

/// Screen 3: Official Home / Dashboard Screen
/// GIGW 3.0 / WCAG 2.1 AA compliant operational portal for MHA field officers and supervisors.
class DashboardScreen extends StatefulWidget {
  final User? currentUser;
  const DashboardScreen({super.key, this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocalLedgerDatabase _db = LocalLedgerDatabase.instance;
  final IFieldRecordRepository _recordRepo = FieldRecordRepository.instance;
  final StagedSyncService _syncService = StagedSyncService.instance;
  final CryptoSignerService _signer = CryptoSignerService.instance;

  late User _user;
  List<LocalRecordModel> _recentRecords = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  LedgerIntegrityReport? _integrityReport;
  String _topHash = "...";

  @override
  void initState() {
    super.initState();
    _user = widget.currentUser ??
        User(
          userId: "OFFICER-7841",
          badgeNumber: "MHA-NZ-7841",
          department: "Ministry of Home Affairs (Operations)",
          role: Role.officer,
          deviceId: "MHA-SECURE-DEV-001",
          provisionedAt: DateTime.now().subtract(const Duration(days: 30)),
        );
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    _signer.initializeHardwareKeystore();
    await _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    final records = await _recordRepo.getAllRecords();
    final topHash = await _db.getLastRecordHash();
    final integrity = await _recordRepo.verifyChainIntegrity();

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
        content: Text("Sync complete: ${res['synced']}/${res['attempted']} anchored to MHA server."),
        backgroundColor: GovTheme.primary,
      ),
    );
  }

  void _startNewTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen(currentUser: _user),
      ),
    ).then((_) => _refreshDashboard());
  }

  void _startLabProtocol() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KitSelectionScreen(currentUser: _user),
      ),
    ).then((_) => _refreshDashboard());
  }

  @override
  Widget build(BuildContext context) {
    int totalCount = _recentRecords.length;
    int posCount = _recentRecords.where((r) => r.classification.contains("POS")).length;
    int pendingSync = _recentRecords.where((r) => r.isStage1Synced == 0).length;

    return Scaffold(
      backgroundColor: GovTheme.bgBase,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/mha_emblem.png',
                height: 32,
                width: 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.amberAccent, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "MHA FIELD PORTAL",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.6),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "Narcotics Enforcement • NDPS §52A",
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 24),
            tooltip: "Sync Pending Records",
            onPressed: _isSyncing ? null : _triggerManualSync,
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 22),
            tooltip: "Switch Officer / Log Out",
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const GovHeaderBanner(
              titleText: "MINISTRY OF HOME AFFAIRS",
              subtitleText: "OPERATIONAL FIELD HEADQUARTERS • NDPS §52A APPARATUS",
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: GovTheme.primary))
                  : RefreshIndicator(
                      onRefresh: _refreshDashboard,
                      child: ListView(
                        padding: const EdgeInsets.all(GovTheme.space16),
                        children: [
                          // 1. Officer Credentials & Device Binding Strip (Tappable to manage profile)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final updatedUser = await Navigator.push<User>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileSettingsScreen(currentUser: _user),
                                ),
                              );
                              if (updatedUser != null && mounted) {
                                setState(() => _user = updatedUser);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: GovTheme.bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _user.isVerified ? const Color(0xFF81C784) : Colors.amber.shade400,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: (_user.isVerified ? Colors.green : Colors.amber.shade700).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _user.isVerified ? Icons.badge : Icons.pending_actions,
                                      color: _user.isVerified ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _user.name.isNotEmpty ? _user.name : _user.badgeNumber,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: GovTheme.ashokaNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "${_user.rank} • Badge: ${_user.badgeNumber}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: GovTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${_user.unit} • ${_user.city}",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: GovTheme.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _user.isVerified ? const Color(0xFFE8F5E9) : Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _user.isVerified ? const Color(0xFF4CAF50) : Colors.amber.shade700,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _user.isVerified ? Icons.verified : Icons.warning_amber_rounded,
                                          size: 14,
                                          color: _user.isVerified ? const Color(0xFF2E7D32) : Colors.amber.shade900,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _user.isVerified ? "VERIFIED" : "VERIFY NOW",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                            color: _user.isVerified ? const Color(0xFF1B5E20) : Colors.amber.shade900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: GovTheme.space16),

                          // 2. Primary CTA: START FIELD TEST (CAMERA & GPS)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GovTheme.primary,
                              minimumSize: const Size.fromHeight(62),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: _startNewTest,
                            icon: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "START FIELD TEST (CAMERA & GPS)",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  "Instant Camera Shutter • Live GPS Geolocation",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Secondary: Multi-step Lab Protocol
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              side: const BorderSide(color: GovTheme.borderDefault, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: _startLabProtocol,
                            icon: const Icon(Icons.science_outlined, size: 18, color: GovTheme.ashokaNavy),
                            label: const Text(
                              "Standard 6-Step Lab Protocol (Kit Selection)",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: GovTheme.ashokaNavy,
                              ),
                            ),
                          ),
                          const SizedBox(height: GovTheme.space16),

                          // 3. Operational Overview Stats Row
                          Row(
                            children: [
                              _buildStatCard("Total Tests", "$totalCount", Icons.analytics_outlined),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                "Contraband Pos.",
                                "$posCount",
                                Icons.warning_amber_rounded,
                                isAlert: posCount > 0,
                              ),
                              const SizedBox(width: 8),
                              _buildStatCard(
                                "Pending Sync",
                                "$pendingSync",
                                Icons.cloud_queue,
                                isWarning: pendingSync > 0,
                              ),
                            ],
                          ),
                          const SizedBox(height: GovTheme.space20),

                          // 5. Functional Navigation Grid
                          Row(
                            children: [
                              Expanded(
                                child: _buildNavCard(
                                  title: "Seizure History",
                                  subtitle: "Search & Chain Audit",
                                  icon: Icons.history,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildNavCard(
                                  title: "Sync Mesh",
                                  subtitle: "2G SMS & Cloud",
                                  icon: Icons.sync,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (_user.role == Role.supervisor) ...[
                            _buildNavCard(
                              title: "Supervisor Approvals",
                              subtitle: "Co-sign High Stakes & Commercial Seizures",
                              icon: Icons.admin_panel_settings,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ApprovalQueueScreen(currentUser: _user),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          const SizedBox(height: GovTheme.space16),

                          // 6. Recent Seizure Evidence Records
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Recent Field Records", style: GovTheme.subtitle),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                ),
                                child: const Text("VIEW ALL", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_recentRecords.isEmpty)
                            const Center(child: Text("No records yet.", style: GovTheme.caption))
                          else
                            ..._recentRecords.take(4).map((r) {
                              return InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecordDetailScreen(record: r),
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: GovTheme.ashokaNavy,
                                            ),
                                          ),
                                          GovResultBadge(
                                            classification: r.classification,
                                            confidence: r.confidence,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        r.simpleDrugName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: GovTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 13, color: GovTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(r.formattedDate, style: GovTheme.caption),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.place, size: 13, color: GovTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              r.simpleLocation,
                                              style: GovTheme.caption,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.verified_user, size: 13, color: GovTheme.alertNegativeText),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.simpleIntegrityStatus,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: GovTheme.alertNegativeText,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(
                                                r.isStage1Synced == 1 ? Icons.cloud_done : Icons.cloud_queue,
                                                size: 14,
                                                color: r.isStage1Synced == 1
                                                    ? GovTheme.alertNegativeText
                                                    : GovTheme.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                r.simpleSyncStatus,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
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
                            }),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool isAlert = false, bool isWarning = false}) {
    final Color textColor = isAlert
        ? GovTheme.alertPositiveText
        : (isWarning ? GovTheme.alertInconclusiveText : GovTheme.textPrimary);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: GovTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GovTheme.borderDefault),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GovTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(GovTheme.space16),
        decoration: BoxDecoration(
          color: GovTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GovTheme.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GovTheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: GovTheme.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: GovTheme.ashokaNavy)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: GovTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
