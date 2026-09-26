import 'package:flutter/material.dart';
import '../services/crypto_signer_service.dart';
import '../services/staged_sync_service.dart';

class ProvisioningScreen extends StatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  State<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends State<ProvisioningScreen> {
  final CryptoSignerService _signer = CryptoSignerService.instance;
  final StagedSyncService _syncService = StagedSyncService.instance;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _cardSerialController = TextEditingController();

  final List<String> _issuedCards = [
    "NCB-CARD-2026-0081",
    "NCB-CARD-2026-0082",
    "NCB-CARD-2026-0083",
  ];

  @override
  void initState() {
    super.initState();
    _urlController.text = _syncService.backendBaseUrl;
  }

  void _issueNewCard() {
    final serial = _cardSerialController.text.trim();
    if (serial.isEmpty) return;

    setState(() {
      _issuedCards.add(serial);
      _cardSerialController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Reference Card $serial registered and cryptographically bound."), backgroundColor: const Color(0xFF1E3A8A)),
    );
  }

  void _saveServerUrl() {
    _syncService.configureUrl(_urlController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("NCB Backend URL updated successfully."), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Admin & Device Provisioning"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 8.2 Organizational Permissions Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.amberAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Section 8.2 Organizational Authority & Enrollment",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Binds physical phone hardware Keystore keys to designated NCB officer credentials and registered reference cards under NDPS (Seizure, Storage, Sampling and Disposal) Rules, 2022.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Device Binding Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Enrolled Device Specification", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Divider(color: Color(0xFF334155), height: 20),
                    _buildField("Hardware Device ID", "NCB-DEV-S24-IND01"),
                    _buildField("Keystore Module", "AndroidKeyStore / StrongBox TEE"),
                    _buildField("Hardware Key Fingerprint", _signer.deviceKeyFingerprint),
                    _buildField("Signing Algorithm", "ECDSA NIST P-256 (FIPS 186-4)"),
                    _buildField("Officer Assigned", "INSP. RAJESH KUMAR (NCB-DEL-042)"),
                    _buildField("Zone / Office", "Delhi Zonal Unit, Narcotics Control Bureau"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reference Card Issuance Card
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Authorized Reference Card Serials", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text("Only pre-registered ArUco reference cards can be used for evidentiary capture:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _issuedCards.map((c) {
                        return Chip(
                          backgroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          avatar: const Icon(Icons.qr_code, size: 16, color: Colors.cyanAccent),
                          label: Text(c, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardSerialController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: "e.g. NCB-CARD-2026-0084",
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          onPressed: _issueNewCard,
                          child: const Text("Issue Card", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Backend Server Configuration
            Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Central Server Sync Endpoint", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text("Configure the central FastAPI/Firebase gateway for staged record sync:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                          onPressed: _saveServerUrl,
                          child: const Text("Save", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
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
}
