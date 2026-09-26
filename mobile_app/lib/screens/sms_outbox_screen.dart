import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sms_anchor_service.dart';

class SmsOutboxScreen extends StatefulWidget {
  const SmsOutboxScreen({super.key});

  @override
  State<SmsOutboxScreen> createState() => _SmsOutboxScreenState();
}

class _SmsOutboxScreenState extends State<SmsOutboxScreen> {
  final SmsAnchorService _smsService = SmsAnchorService.instance;

  @override
  Widget build(BuildContext context) {
    final list = _smsService.outboxHistory;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("2G SMS Witness Outbox"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Outbox Info Banner
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
                      Icon(Icons.network_cell, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Section 4.4 Out-of-Band 2G SMS Anchor",
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Operates 100% offline on pure 2G networks without internet. Sends a cryptographic hash fingerprint (~40 chars) over the officer's SIM directly to central NCB gateway, providing an independent timestamp witness outside the device.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Transmission History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text("Gateway: ${_smsService.ncbGatewayNumber}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),

            if (list.isEmpty)
              const Card(
                color: Color(0xFF1E293B),
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      "No SMS anchors dispatched yet in this session.\nAny newly sealed test will automatically appear here.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              )
            else
              ...list.map((entry) {
                final dateStr = DateFormat('HH:mm:ss dd-MMM').format(entry.timestamp);
                return Card(
                  color: const Color(0xFF1E293B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.testId, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.status,
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Destination: ${entry.destinationNumber} | Sent: $dateStr",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Text(
                            entry.gsmPayload,
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Payload Length: ${entry.gsmPayload.length}/140 chars (GSM 03.38)",
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                            if (entry.transmissionRef != null)
                              Text(
                                "Ref: ${entry.transmissionRef}",
                                style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
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
    );
  }
}
