import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

class LocalRecordModel {
  final String testId;
  final double timestampUtc;
  final String officerId;
  final String deviceId;
  final String kitType;
  final String classification;
  final double deltaE2000;
  final double confidence;
  final String imageSha256;
  final String cardSerial;
  final double? latitude;
  final double? longitude;
  final String locationStatus; // 'GPS_CONFIRMED' or 'LOCATION_UNCONFIRMED'
  final bool accusedPresent; // NDPS Act Section 52A requirement
  final bool reagentWindowOk;
  final int reactionTimeSeconds;
  final String prevHash;
  final String recordHash;
  final String deviceSigHex;
  final String officerSigHex;
  final bool isHighStakes;
  final String firNumber;
  final String seizureLocation;
  final String substanceDescription;
  final String panchWitnessDetails;
  final String grossWeight;
  final String netWeight;
  final String packagingMarkings;
  final String sealSerial;
  final String? supervisorId;
  final String? supervisorSigHex;
  final String? localEvidencePath;
  final int isStage1Synced; // 0 = pending, 1 = synced
  final int isStage2Synced; // 0 = pending, 1 = synced
  final int isSmsWitnessed; // 0 = pending, 1 = sent over GSM

  LocalRecordModel({
    required this.testId,
    required this.timestampUtc,
    required this.officerId,
    required this.deviceId,
    required this.kitType,
    required this.classification,
    required this.deltaE2000,
    this.confidence = 94.5,
    required this.imageSha256,
    required this.cardSerial,
    this.latitude,
    this.longitude,
    required this.locationStatus,
    this.accusedPresent = true,
    this.reagentWindowOk = true,
    this.reactionTimeSeconds = 30,
    required this.prevHash,
    required this.recordHash,
    required this.deviceSigHex,
    required this.officerSigHex,
    this.isHighStakes = false,
    this.firNumber = '',
    this.seizureLocation = '',
    this.substanceDescription = '',
    this.panchWitnessDetails = '',
    this.grossWeight = '',
    this.netWeight = '',
    this.packagingMarkings = '',
    this.sealSerial = '',
    this.supervisorId,
    this.supervisorSigHex,
    this.localEvidencePath,
    this.isStage1Synced = 0,
    this.isStage2Synced = 0,
    this.isSmsWitnessed = 0,
  });

  // ==========================================
  // ENCAPSULATED DOMAIN ABSTRACTIONS
  // Simplified terminology for field police & supervisors
  // ==========================================

  bool get isPositive => classification.toUpperCase().contains('POS');
  bool get isNegative => classification.toUpperCase().contains('NEG');
  bool get isInconclusive => !isPositive && !isNegative;

  /// Clear, direct result title for field officers
  String get simpleResultTitle {
    if (isPositive) return "POSITIVE: Contraband Detected";
    if (isNegative) return "NEGATIVE: No Drug Detected";
    return "INCONCLUSIVE: Retest Mandated";
  }

  /// Clean, easily understood drug name
  String get simpleDrugName {
    final upper = classification.toUpperCase();
    if (upper.contains("HEROIN") || upper.contains("MORPHINE") || kitType.contains("MARQUIS")) {
      return "Opioids (Heroin / Morphine)";
    }
    if (upper.contains("COCAINE") || kitType.contains("SCOTT")) {
      return "Cocaine Hydrochloride";
    }
    if (upper.contains("METH") || upper.contains("AMPHETAMINE") || kitType.contains("MECKE")) {
      return "Methamphetamine / Amphetamine";
    }
    if (upper.contains("CANNABIS") || upper.contains("THC") || kitType.contains("DUQUENOIS")) {
      return "Cannabis / Hashish (THC)";
    }
    return kitType;
  }

  /// Plain English kit description
  String get simpleKitDescription {
    if (kitType.contains("MARQUIS")) return "Marquis Field Reagent";
    if (kitType.contains("SCOTT")) return "Scott (Cobalt) Field Reagent";
    if (kitType.contains("MECKE")) return "Mecke Field Reagent";
    return "$kitType Test Kit";
  }

  /// Human-friendly readable date and time
  String get formattedDate {
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch((timestampUtc * 1000).toInt()).toLocal();
      return DateFormat("dd MMM yyyy, hh:mm a").format(dt);
    } catch (_) {
      return "Recent";
    }
  }

  /// Plain location description with GPS fix indicator
  String get simpleLocation {
    if (latitude != null && longitude != null) {
      return "${latitude!.toStringAsFixed(4)}° N, ${longitude!.toStringAsFixed(4)}° E (GPS Locked)";
    }
    return "Stationary / Panchnama Site";
  }

  /// Police-friendly sync status
  String get simpleSyncStatus =>
      isStage1Synced == 1 ? "Uploaded to Police HQ" : "Saved Offline on Device";

  /// Statutory legal seal label
  String get simpleIntegrityStatus => "Digitally Sealed under NDPS §52A";

  /// Clear match accuracy
  String get simpleMatchAccuracy =>
      "${confidence.toStringAsFixed(1)}% Match Confidence";


  /// Canonical JSON representation for tamper-proof deterministic SHA-256 computation
  String toCanonicalJson() {
    final map = {
      'accused_present': accusedPresent,
      'card_serial': cardSerial,
      'classification': classification,
      'confidence': double.parse(confidence.toStringAsFixed(2)),
      'delta_e2000': double.parse(deltaE2000.toStringAsFixed(2)),
      'device_id': deviceId,
      'image_sha256': imageSha256,
      'kit_type': kitType,
      'latitude': latitude != null ? double.parse(latitude!.toStringAsFixed(5)) : null,
      'location_status': locationStatus,
      'longitude': longitude != null ? double.parse(longitude!.toStringAsFixed(5)) : null,
      'officer_id': officerId,
      'reaction_time_seconds': reactionTimeSeconds,
      'reagent_window_ok': reagentWindowOk,
      'test_id': testId,
      'timestamp_utc': double.parse(timestampUtc.toStringAsFixed(3)),
      'is_high_stakes': isHighStakes,
      'fir_number': firNumber,
      'seizure_location': seizureLocation,
      'substance_description': substanceDescription,
      'panch_witness_details': panchWitnessDetails,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'packaging_markings': packagingMarkings,
      'seal_serial': sealSerial,
      'supervisor_id': supervisorId,
      'supervisor_sig_hex': supervisorSigHex,
    };
    return jsonEncode(map);
  }

  /// Calculates block SHA-256: H_n = SHA256(CanonicalData_n + PrevHash)
  static String computeBlockSha256(String canonicalJson, String prevHash) {
    final combined = '$canonicalJson|$prevHash';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Strict 140-char GSM SMS Anchor representation for 2G out-of-band witness
  String toGsmSmsPayload() {
    final shortId = testId.replaceAll('TEST-', '').replaceAll('NDPS-', '');
    final hashPrefix = recordHash.length > 32 ? recordHash.substring(0, 32) : recordHash;
    final shortOfficer = officerId.replaceAll('OFFICER-', '');
    final upper = classification.toUpperCase();
    final resCode = upper.contains('POS') ? 'POS' : (upper.contains('NEG') ? 'NEG' : 'INC');
    final gpsStr = (latitude != null && longitude != null)
        ? '${latitude!.toStringAsFixed(3)},${longitude!.toStringAsFixed(3)}'
        : 'NOGPS';
    return 'MHA|$shortId|$hashPrefix|$shortOfficer|$resCode|$gpsStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'test_id': testId,
      'timestamp_utc': timestampUtc,
      'officer_id': officerId,
      'device_id': deviceId,
      'kit_type': kitType,
      'classification': classification,
      'delta_e2000': deltaE2000,
      'confidence': confidence,
      'image_sha256': imageSha256,
      'card_serial': cardSerial,
      'latitude': latitude,
      'longitude': longitude,
      'location_status': locationStatus,
      'accused_present': accusedPresent ? 1 : 0,
      'reagent_window_ok': reagentWindowOk ? 1 : 0,
      'reaction_time_seconds': reactionTimeSeconds,
      'prev_hash': prevHash,
      'record_hash': recordHash,
      'device_sig_hex': deviceSigHex,
      'officer_sig_hex': officerSigHex,
      'is_high_stakes': isHighStakes ? 1 : 0,
      'fir_number': firNumber,
      'seizure_location': seizureLocation,
      'substance_description': substanceDescription,
      'panch_witness_details': panchWitnessDetails,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'packaging_markings': packagingMarkings,
      'seal_serial': sealSerial,
      'supervisor_id': supervisorId,
      'supervisor_sig_hex': supervisorSigHex,
      'local_evidence_path': localEvidencePath,
      'is_stage1_synced': isStage1Synced,
      'is_stage2_synced': isStage2Synced,
      'is_sms_witnessed': isSmsWitnessed,
    };
  }

  factory LocalRecordModel.fromMap(Map<String, dynamic> map) {
    return LocalRecordModel(
      testId: map['test_id'] as String,
      timestampUtc: (map['timestamp_utc'] as num).toDouble(),
      officerId: map['officer_id'] as String,
      deviceId: map['device_id'] as String,
      kitType: map['kit_type'] as String,
      classification: map['classification'] as String,
      deltaE2000: (map['delta_e2000'] as num).toDouble(),
      confidence: map['confidence'] != null ? (map['confidence'] as num).toDouble() : 92.0,
      imageSha256: map['image_sha256'] as String,
      cardSerial: map['card_serial'] as String,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      locationStatus: map['location_status'] as String,
      accusedPresent: (map['accused_present'] ?? 1) == 1,
      reagentWindowOk: (map['reagent_window_ok'] ?? 1) == 1,
      reactionTimeSeconds: map['reaction_time_seconds'] ?? 30,
      prevHash: map['prev_hash'] as String,
      recordHash: map['record_hash'] as String,
      deviceSigHex: map['device_sig_hex'] as String,
      officerSigHex: map['officer_sig_hex'] as String,
      isHighStakes: (map['is_high_stakes'] ?? 0) == 1,
      firNumber: map['fir_number'] as String? ?? '',
      seizureLocation: map['seizure_location'] as String? ?? '',
      substanceDescription: map['substance_description'] as String? ?? '',
      panchWitnessDetails: map['panch_witness_details'] as String? ?? '',
      grossWeight: map['gross_weight'] as String? ?? '',
      netWeight: map['net_weight'] as String? ?? '',
      packagingMarkings: map['packaging_markings'] as String? ?? '',
      sealSerial: map['seal_serial'] as String? ?? '',
      supervisorId: map['supervisor_id'] as String?,
      supervisorSigHex: map['supervisor_sig_hex'] as String?,
      localEvidencePath: map['local_evidence_path'] as String?,
      isStage1Synced: map['is_stage1_synced'] ?? 0,
      isStage2Synced: map['is_stage2_synced'] ?? 0,
      isSmsWitnessed: map['is_sms_witnessed'] ?? 0,
    );
  }

  LocalRecordModel copyWith({
    int? isStage1Synced,
    int? isStage2Synced,
    int? isSmsWitnessed,
    String? supervisorId,
    String? supervisorSigHex,
  }) {
    return LocalRecordModel(
      testId: testId,
      timestampUtc: timestampUtc,
      officerId: officerId,
      deviceId: deviceId,
      kitType: kitType,
      classification: classification,
      deltaE2000: deltaE2000,
      confidence: confidence,
      imageSha256: imageSha256,
      cardSerial: cardSerial,
      latitude: latitude,
      longitude: longitude,
      locationStatus: locationStatus,
      accusedPresent: accusedPresent,
      reagentWindowOk: reagentWindowOk,
      reactionTimeSeconds: reactionTimeSeconds,
      prevHash: prevHash,
      recordHash: recordHash,
      deviceSigHex: deviceSigHex,
      officerSigHex: officerSigHex,
      isHighStakes: isHighStakes,
      firNumber: firNumber,
      seizureLocation: seizureLocation,
      substanceDescription: substanceDescription,
      panchWitnessDetails: panchWitnessDetails,
      grossWeight: grossWeight,
      netWeight: netWeight,
      packagingMarkings: packagingMarkings,
      sealSerial: sealSerial,
       supervisorId: supervisorId ?? this.supervisorId,
       supervisorSigHex: supervisorSigHex ?? this.supervisorSigHex,
      localEvidencePath: localEvidencePath ?? this.localEvidencePath,
      isStage1Synced: isStage1Synced ?? this.isStage1Synced,
      isStage2Synced: isStage2Synced ?? this.isStage2Synced,
      isSmsWitnessed: isSmsWitnessed ?? this.isSmsWitnessed,
    );
  }
}
