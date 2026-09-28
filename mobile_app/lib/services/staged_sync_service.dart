import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/record_model.dart';
import 'local_ledger_database.dart';

class SyncStatusSummary {
  final int stage1SyncedCount;
  final int stage1PendingCount;
  final int stage2SyncedCount;
  final int stage2PendingCount;
  final bool isBackendOnline;

  SyncStatusSummary({
    required this.stage1SyncedCount,
    required this.stage1PendingCount,
    required this.stage2SyncedCount,
    required this.stage2PendingCount,
    required this.isBackendOnline,
  });
}

class StagedSyncService {
  static final StagedSyncService instance = StagedSyncService._internal();

  String backendBaseUrl = 'http://10.0.2.2:8000'; // Default Android emulator loopback

  StagedSyncService._internal();

  void configureUrl(String url) {
    backendBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
  }

  /// Step 1: Weak-Signal Metadata Sync (<1KB Payload)
  Future<bool> syncStage1Metadata(LocalRecordModel record) async {
    final url = Uri.parse('$backendBaseUrl/sync/stage1/metadata');
    final payload = {
      'test_id': record.testId,
      'timestamp_utc': record.timestampUtc,
      'officer_id': record.officerId,
      'device_id': record.deviceId,
      'kit_type': record.kitType,
      'classification': record.classification,
      'delta_e2000': record.deltaE2000,
      'image_sha256': record.imageSha256,
      'card_serial': record.cardSerial,
      'latitude': record.latitude,
      'longitude': record.longitude,
      'location_status': record.locationStatus,
      'prev_hash': record.prevHash,
      'record_hash': record.recordHash,
      'device_sig_hex': record.deviceSigHex,
      'officer_sig_hex': record.officerSigHex,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-officer-id': record.officerId,
          'x-role': 'officer',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        await LocalLedgerDatabase.instance.markStage1Synced(record.testId);
        return true;
      }
      await LocalLedgerDatabase.instance.markSyncFailure(
        testId: record.testId,
        stage: 1,
        error: 'Stage 1 HTTP ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint("Stage 1 Sync network error (offline queue retained): $e");
      await LocalLedgerDatabase.instance.markSyncFailure(
        testId: record.testId,
        stage: 1,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Step 2: High-Bandwidth Verified Image Upload (Post-Stage 1)
  Future<bool> syncStage2Image({
    required String testId,
    required List<int> imageBytes,
    required String filename,
    required String officerId,
  }) async {
    final url = Uri.parse('$backendBaseUrl/sync/stage2/image');
    try {
      var request = http.MultipartRequest('POST', url);
      request.headers['x-officer-id'] = officerId;
      request.headers['x-role'] = 'officer';
      request.fields['test_id'] = testId;
      request.files.add(http.MultipartFile.fromBytes('file', imageBytes, filename: filename));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await LocalLedgerDatabase.instance.markStage2Synced(testId);
        return true;
      }
      await LocalLedgerDatabase.instance.markSyncFailure(
        testId: testId,
        stage: 2,
        error: 'Stage 2 HTTP ${response.statusCode}',
      );
      return false;
    } catch (e) {
      debugPrint("Stage 2 Image Upload network error: $e");
      await LocalLedgerDatabase.instance.markSyncFailure(
        testId: testId,
        stage: 2,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Synchronizes all pending records currently waiting in the offline queue
  Future<Map<String, int>> syncAllPendingRecords() async {
    final db = LocalLedgerDatabase.instance;
    final pendingStage1 = await db.getDueUnsyncedStage1Records();

    int attempted = 0;
    int synced = 0;
    for (final rec in pendingStage1) {
      attempted++;
      final ok = await syncStage1Metadata(rec);
      if (ok) synced++;
    }

    final pendingStage2 = await db.getDueUnsyncedStage2Records();
    for (final rec in pendingStage2) {
      attempted++;
      final path = rec.localEvidencePath;
      if (path == null || path.isEmpty || !await File(path).exists()) {
        await db.markSyncFailure(
          testId: rec.testId,
          stage: 2,
          error: 'Local evidence file is unavailable for upload.',
        );
        continue;
      }
      final ok = await syncStage2Image(
        testId: rec.testId,
        imageBytes: await File(path).readAsBytes(),
        filename: path.split(Platform.pathSeparator).last,
        officerId: rec.officerId,
      );
      if (ok) synced++;
    }

    return {
      'attempted': attempted,
      'synced': synced,
    };
  }

  /// Checks if backend server is reachable
  Future<bool> testBackendHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$backendBaseUrl/audit'),
        headers: {'x-role': 'auditor'},
      ).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
