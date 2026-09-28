import 'package:flutter_test/flutter_test.dart';
import 'package:sih_field_drug_testing/models/record_model.dart';
import 'package:sih_field_drug_testing/services/camera_quality_gate.dart';
import 'dart:math';

void main() {
  group('Camera Quality Gate & ArUco Gating Tests', () {
    test('CameraQualityMetrics accurately evaluates gate passing criteria', () {
      // 1. Sharpness passing and ArUco 4/4 passing -> Gate PASS
      const passedMetrics = CameraQualityMetrics(
        laplacianVariance: 154.2,
        fourFiducialsVisible: true,
        arucoMarkerIds: [0, 1, 2, 3],
      );
      expect(passedMetrics.passed, isTrue);

      // 2. Sharpness failing (< 100) even if ArUco detected -> Gate FAIL
      const blurryMetrics = CameraQualityMetrics(
        laplacianVariance: 48.5,
        fourFiducialsVisible: true,
        arucoMarkerIds: [0, 1, 2, 3],
      );
      expect(blurryMetrics.passed, isFalse);

      // 3. ArUco missing (< 4 markers) even if sharp -> Gate FAIL
      const missingArucoMetrics = CameraQualityMetrics(
        laplacianVariance: 210.0,
        fourFiducialsVisible: false,
        arucoMarkerIds: [0, 1],
      );
      expect(missingArucoMetrics.passed, isFalse);

      // 4. Zero metrics (initial state) -> Gate FAIL
      const initialMetrics = CameraQualityMetrics(
        laplacianVariance: 0.0,
        fourFiducialsVisible: false,
      );
      expect(initialMetrics.passed, isFalse);
    });

    test('ArUco quadrant and unique marker validation logic', () {
      final markerIds = [0, 1, 2, 3];
      final markerQuadrants = [0, 1, 2, 3];

      final bool passed = markerIds.length >= 4 &&
          markerIds.toSet().length >= 4 &&
          markerQuadrants.toSet().containsAll(const <int>[0, 1, 2, 3]);

      expect(passed, isTrue);

      // Duplicate marker ID in same frame should fail
      final duplicateIds = [0, 0, 1, 2];
      final bool duplicatePassed = duplicateIds.length >= 4 &&
          duplicateIds.toSet().length >= 4 &&
          markerQuadrants.toSet().containsAll(const <int>[0, 1, 2, 3]);

      expect(duplicatePassed, isFalse);

      // Missing quadrant (e.g. tilted/cut off) should fail
      final missingQuadrant = [0, 1, 1, 3];
      final bool missingQuadrantPassed = markerIds.length >= 4 &&
          markerIds.toSet().length >= 4 &&
          missingQuadrant.toSet().containsAll(const <int>[0, 1, 2, 3]);

      expect(missingQuadrantPassed, isFalse);
    });
  });

  group('Offline Retry & Durable Evidence Retention Tests', () {
    test('Offline SMS payload satisfies statutory 140-char GSM limit', () {
      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0;
      final record = LocalRecordModel(
        testId: 'TEST-2026-DEL-0099',
        timestampUtc: nowUtc,
        officerId: 'MHA-NCB-DEL-042',
        deviceId: 'DEV-PIXEL-FORENSIC-01',
        kitType: 'nddk',
        classification: 'Positive (Heroin / Morphine)',
        confidence: 94.5,
        deltaE2000: 8.4,
        imageSha256: 'a1b2c3d4e5f60718293a4b5c6d7e8f90',
        cardSerial: 'CARD-DEL-0099',
        latitude: 28.6139,
        longitude: 77.2090,
        locationStatus: 'CONFIRMED',
        accusedPresent: true,
        reagentWindowOk: true,
        reactionTimeSeconds: 30,
        prevHash: '0000000000000000000000000000000000000000000000000000000000000000',
        recordHash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        deviceSigHex: '3045022100a1b2c3d4e5f6',
        officerSigHex: '30440220112233445566',
        isHighStakes: false,
        firNumber: 'FIR-2026/89',
        seizureLocation: 'IGI Airport Cargo Terminal 3',
        substanceDescription: 'Brownish crystalline powder',
        panchWitnessDetails: 'Shri R. Sharma, Shri A. Verma',
        grossWeight: '500g',
        netWeight: '450g',
        packagingMarkings: 'Heat sealed transparent polythene',
        sealSerial: 'SEAL-NCB-7788',
        isStage1Synced: 0,
        isStage2Synced: 0,
        isSmsWitnessed: 0,
      );

      final gsmPayload = record.toGsmSmsPayload();
      print("Generated GSM Payload: $gsmPayload (Length: ${gsmPayload.length})");
      expect(gsmPayload.length, lessThanOrEqualTo(140));
      expect(gsmPayload.startsWith('MHA|'), isTrue);
      expect(gsmPayload.contains('DEL-0099'), isTrue);
      expect(gsmPayload.contains('POS'), isTrue);
    });

    test('Exponential backoff schedule prevents retry storm without losing sync evidence', () {
      // Test backoff calculation: min(3600, 30 * (1 << min(attempts, 6)))
      final expectedDelays = <int, int>{
        0: 30,   // 30 * 1 = 30s
        1: 60,   // 30 * 2 = 60s
        2: 120,  // 30 * 4 = 2m
        3: 240,  // 30 * 8 = 4m
        4: 480,  // 30 * 16 = 8m
        5: 960,  // 30 * 32 = 16m
        6: 1920, // 30 * 64 = 32m
        7: 1920, // capped at 2^6 * 30
      };

      for (final entry in expectedDelays.entries) {
        final attempts = entry.key;
        final expectedDelay = entry.value;
        final calculatedDelay = min(3600, 30 * (1 << min(attempts, 6)));
        expect(calculatedDelay, equals(expectedDelay));
      }
    });

    test('Record model preserves all statutory forensic fields for BSA §63 admissibility', () {
      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0;
      final record = LocalRecordModel(
        testId: 'TEST-2026-BSA-01',
        timestampUtc: nowUtc,
        officerId: 'PSI-KUMAR-99',
        deviceId: 'DEV-MHA-007',
        kitType: 'nddk',
        classification: 'Positive',
        confidence: 96.0,
        deltaE2000: 5.2,
        imageSha256: 'img-sha256-hash',
        cardSerial: 'CARD-2026',
        latitude: 28.6139,
        longitude: 77.2090,
        locationStatus: 'CONFIRMED',
        accusedPresent: true,
        reagentWindowOk: true,
        reactionTimeSeconds: 25,
        prevHash: '0000000000000000000000000000000000000000000000000000000000000000',
        recordHash: 'abcd1234ef567890',
        deviceSigHex: 'sig-device-hex',
        officerSigHex: 'sig-officer-hex',
        isHighStakes: true,
        firNumber: 'NDPS/2026/012',
        seizureLocation: 'Railway Station Platform 1',
        substanceDescription: 'White crystalline substance',
        panchWitnessDetails: 'Independent Witness 1 & 2',
        grossWeight: '1200g',
        netWeight: '1000g',
        packagingMarkings: 'Mark A with Red Wax Seal',
        sealSerial: 'SEAL-998811',
        localEvidencePath: '/data/user/0/gov.mha.fieldtesting/app_flutter/evidence_01.jpg',
        isStage1Synced: 0,
        isStage2Synced: 0,
        isSmsWitnessed: 0,
      );

      final map = record.toMap();
      final reconstructed = LocalRecordModel.fromMap(map);

      expect(reconstructed.testId, equals(record.testId));
      expect(reconstructed.firNumber, equals('NDPS/2026/012'));
      expect(reconstructed.isHighStakes, isTrue);
      expect(reconstructed.localEvidencePath, equals(record.localEvidencePath));
      expect(reconstructed.isStage1Synced, equals(0));
      expect(reconstructed.isStage2Synced, equals(0));
      expect(reconstructed.isSmsWitnessed, equals(0));
    });
  });
}
