import 'dart:convert';
import 'dart:io';

/// SIH26231 — Domain Model Specification (Section 2)
/// Flat composition models for field drug testing compliance

enum Role { officer, supervisor, auditor, admin }

class User {
  final String userId;
  final String name;
  final String email;
  final String badgeNumber;
  final int age;
  final String gender;
  final String city;
  final String department;
  final Role role;
  final String deviceId; // bound hardware device
  final DateTime provisionedAt;
  final String rank;
  final String unit;
  final bool isVerified;
  final String? serviceId;
  final String dob;
  final String phone;

  User({
    required this.userId,
    this.name = "Officer",
    this.email = "officer@mha.gov.in",
    required this.badgeNumber,
    this.age = 30,
    this.gender = "Male",
    this.city = "New Delhi",
    this.department = "Ministry of Home Affairs • Forensic Operations Division",
    required this.role,
    this.deviceId = "MHA-SECURE-DEV-001",
    required this.provisionedAt,
    this.rank = "Police Sub-Inspector (PSI)",
    this.unit = "Special Task Force (Anti-Narcotics Unit)",
    this.isVerified = true,
    this.serviceId,
    this.dob = "1996-05-15",
    this.phone = "+91 98765 43210",
  });

  User copyWith({
    String? userId,
    String? name,
    String? email,
    String? badgeNumber,
    int? age,
    String? gender,
    String? city,
    String? department,
    Role? role,
    String? deviceId,
    DateTime? provisionedAt,
    String? rank,
    String? unit,
    bool? isVerified,
    String? serviceId,
    String? dob,
    String? phone,
  }) => User(
    userId: userId ?? this.userId,
    name: name ?? this.name,
    email: email ?? this.email,
    badgeNumber: badgeNumber ?? this.badgeNumber,
    age: age ?? this.age,
    gender: gender ?? this.gender,
    city: city ?? this.city,
    department: department ?? this.department,
    role: role ?? this.role,
    deviceId: deviceId ?? this.deviceId,
    provisionedAt: provisionedAt ?? this.provisionedAt,
    rank: rank ?? this.rank,
    unit: unit ?? this.unit,
    isVerified: isVerified ?? this.isVerified,
    serviceId: serviceId ?? this.serviceId,
    dob: dob ?? this.dob,
    phone: phone ?? this.phone,
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'name': name,
    'email': email,
    'badgeNumber': badgeNumber,
    'age': age,
    'gender': gender,
    'city': city,
    'department': department,
    'role': role.name,
    'deviceId': deviceId,
    'provisionedAt': provisionedAt.toIso8601String(),
    'rank': rank,
    'unit': unit,
    'isVerified': isVerified,
    'serviceId': serviceId,
    'dob': dob,
    'phone': phone,
  };

  factory User.fromMap(Map<String, dynamic> map) => User(
    userId: map['userId'] as String? ?? (map['user_id'] as String?) ?? 'MHA-DEFAULT',
    name: map['name'] as String? ?? 'Officer',
    email: map['email'] as String? ?? 'officer@mha.gov.in',
    badgeNumber: map['badgeNumber'] as String? ?? (map['badge_number'] as String?) ?? 'MHA-NZ-7841',
    age: (map['age'] as num?)?.toInt() ?? 30,
    gender: map['gender'] as String? ?? 'Male',
    city: map['city'] as String? ?? 'New Delhi',
    department: map['department'] as String? ?? 'Ministry of Home Affairs • Forensic Operations Division',
    role: Role.values.firstWhere((e) => e.name == map['role'], orElse: () => Role.officer),
    deviceId: map['deviceId'] as String? ?? (map['device_id'] as String?) ?? 'MHA-SECURE-DEV-001',
    provisionedAt: map['provisionedAt'] != null 
        ? DateTime.parse(map['provisionedAt'] as String) 
        : (map['created_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(((map['created_at'] as num) * 1000).toInt()) 
            : DateTime.now()),
    rank: map['rank'] as String? ?? 'Police Sub-Inspector (PSI)',
    unit: map['unit'] as String? ?? 'Special Task Force (Anti-Narcotics Unit)',
    isVerified: (map['isVerified'] ?? map['is_verified']) == 1 || (map['isVerified'] ?? map['is_verified']) == true,
    serviceId: (map['serviceId'] ?? map['service_id']) as String?,
    dob: map['dob'] as String? ?? '1996-05-15',
    phone: map['phone'] as String? ?? '+91 98765 43210',
  );
}

/// Official Department Registry Entry for Law Enforcement Personnel
/// Pre-seeded or provisioned by Ministry of Home Affairs Admin
class DepartmentOfficer {
  final String serviceId;
  final String badgeNumber;
  final String name;
  final String rank;
  final String unit;
  final String city;
  final String registeredPhone;
  final String registeredEmail;
  final Role role;
  final String credentialSig;
  final bool isActivated;
  final String? deviceId;

  const DepartmentOfficer({
    required this.serviceId,
    required this.badgeNumber,
    required this.name,
    required this.rank,
    required this.unit,
    required this.city,
    required this.registeredPhone,
    required this.registeredEmail,
    required this.role,
    required this.credentialSig,
    this.isActivated = false,
    this.deviceId,
  });

  Map<String, dynamic> toMap() => {
    'service_id': serviceId,
    'badge_number': badgeNumber,
    'name': name,
    'rank': rank,
    'unit': unit,
    'city': city,
    'registered_phone': registeredPhone,
    'registered_email': registeredEmail,
    'role': role.name,
    'credential_sig': credentialSig,
    'is_activated': isActivated ? 1 : 0,
    'device_id': deviceId,
  };

  factory DepartmentOfficer.fromMap(Map<String, dynamic> map) => DepartmentOfficer(
    serviceId: map['service_id'] as String,
    badgeNumber: map['badge_number'] as String,
    name: map['name'] as String,
    rank: map['rank'] as String,
    unit: map['unit'] as String,
    city: map['city'] as String,
    registeredPhone: map['registered_phone'] as String,
    registeredEmail: map['registered_email'] as String,
    role: Role.values.firstWhere((e) => e.name == map['role'], orElse: () => Role.officer),
    credentialSig: map['credential_sig'] as String? ?? 'SIG-MHA-VALID',
    isActivated: (map['is_activated'] as num?)?.toInt() == 1,
    deviceId: map['device_id'] as String?,
  );
}

enum DeviceStatus { active, revoked, lost }

class Device {
  final String deviceId;
  final String hardwareKeyFingerprint; // from Android Keystore / Secure Enclave
  final String? assignedUserId;
  final DeviceStatus status;

  Device({
    required this.deviceId,
    required this.hardwareKeyFingerprint,
    this.assignedUserId,
    this.status = DeviceStatus.active,
  });
}

enum CardStatus { active, retired, reported_lost }

class ReferenceCard {
  final String serial;
  final String qrPayload;
  final String? issuedToOfficerId;
  final CardStatus status;

  ReferenceCard({
    required this.serial,
    required this.qrPayload,
    this.issuedToOfficerId,
    this.status = CardStatus.active,
  });
}

enum KitType { nddk, pcdk, kdk }

extension KitTypeDetails on KitType {
  String get displayName {
    switch (this) {
      case KitType.nddk:
        return "NDDK (General Narcotics / Marquis)";
      case KitType.pcdk:
        return "PCDK (Cannabis / Duquenois-Levine)";
      case KitType.kdk:
        return "KDK (Cocaine / Scott Reagent)";
    }
  }

  String get targetSubstance {
    switch (this) {
      case KitType.nddk:
        return "Opium / Heroin / Morphine";
      case KitType.pcdk:
        return "Cannabis / Hashish / Marijuana";
      case KitType.kdk:
        return "Cocaine HCl / Crack";
    }
  }

  int get reactionWindowSeconds {
    switch (this) {
      case KitType.nddk:
        return 45;
      case KitType.pcdk:
        return 60;
      case KitType.kdk:
        return 30;
    }
  }
}

class CapturedFrame {
  final String frameId;
  final List<int> imageBytes;
  final DateTime capturedAt;
  final double laplacianVariance;
  final double exposureScore;
  final bool arucoDetected;

  CapturedFrame({
    required this.frameId,
    required this.imageBytes,
    required this.capturedAt,
    required this.laplacianVariance,
    required this.exposureScore,
    required this.arucoDetected,
  });
}

class CaptureResult {
  final List<CapturedFrame> burstFrames;
  final File capturedImageFile;
  final GeoPoint? location;
  final bool locationConfirmed;
  final KitType kitType;
  final String cardSerial;
  final String reagentBatch;
  final DateTime reactionTimestamp;
  final bool accusedPresent;

  CaptureResult({
    this.burstFrames = const [],
    required this.capturedImageFile,
    this.location,
    required this.locationConfirmed,
    required this.kitType,
    required this.cardSerial,
    required this.reagentBatch,
    required this.reactionTimestamp,
    this.accusedPresent = true,
  });
}

class CalibrationResult {
  final double deltaE;
  final double confidence;
  final bool cardDetected;
  final bool withinReactionWindow;
  final bool qualityPassed;

  CalibrationResult({
    required this.deltaE,
    required this.confidence,
    required this.cardDetected,
    required this.withinReactionWindow,
    required this.qualityPassed,
  });
}

enum ResultCategory { positive, negative, inconclusive }

class ClassificationResult {
  final ResultCategory category;
  final double confidence;
  final List<String> interferentWarnings;

  ClassificationResult({
    required this.category,
    required this.confidence,
    required this.interferentWarnings,
  });
}

class GeoPoint {
  final double latitude;
  final double longitude;
  final double accuracy;

  GeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy = 5.0,
  });

  @override
  String toString() => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

class Signature {
  final String signerId;
  final String algorithm; // ECDSA-P256
  final String signatureBytes;
  final DateTime signedAt;

  Signature({
    required this.signerId,
    this.algorithm = 'ECDSA-P256',
    required this.signatureBytes,
    required this.signedAt,
  });
}

enum SyncStatus { pending, smsWitnessed, stagedSynced, fullyAnchored }

class TestSession {
  final String sessionId;
  final KitType kitType;
  final DateTime reactionStartedAt;
  final List<CapturedFrame> burstFrames;
  CalibrationResult? calibration;

  TestSession({
    required this.sessionId,
    required this.kitType,
    required this.reactionStartedAt,
    this.burstFrames = const [],
    this.calibration,
  });
}

class TestRecord {
  final String testId;
  final String prevHash;
  final String recordHash;
  final User officer;
  final Device device;
  final ReferenceCard card;
  final TestSession session;
  final ClassificationResult result;
  final GeoPoint? location;
  final bool locationConfirmed;
  final DateTime timestamp;
  final Signature deviceSignature;
  final Signature officerSignature;
  SyncStatus syncStatus;

  TestRecord({
    required this.testId,
    required this.prevHash,
    required this.recordHash,
    required this.officer,
    required this.device,
    required this.card,
    required this.session,
    required this.result,
    this.location,
    required this.locationConfirmed,
    required this.timestamp,
    required this.deviceSignature,
    required this.officerSignature,
    this.syncStatus = SyncStatus.pending,
  });

  /// Canonical JSON for Section 63 BSA compliance
  String toCanonicalJson() {
    final map = {
      'test_id': testId,
      'prev_hash': prevHash,
      'officer_id': officer.userId,
      'badge_number': officer.badgeNumber,
      'device_id': device.deviceId,
      'card_serial': card.serial,
      'kit_type': session.kitType.name.toUpperCase(),
      'category': result.category.name.toUpperCase(),
      'confidence': double.parse(result.confidence.toStringAsFixed(2)),
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'location_confirmed': locationConfirmed,
      'timestamp': timestamp.toUtc().toIso8601String(),
    };
    return jsonEncode(map);
  }

  /// Strict 140-char GSM SMS Anchor representation for 2G out-of-band witness
  String toGsmSmsPayload() {
    final shortId = testId.replaceAll('TEST-', '').replaceAll('NDPS-', '');
    final hashPrefix = recordHash.length > 32 ? recordHash.substring(0, 32) : recordHash;
    final resCode = result.category == ResultCategory.positive
        ? 'POS'
        : (result.category == ResultCategory.negative ? 'NEG' : 'INC');
    final gpsStr = (location != null && locationConfirmed)
        ? '${location!.latitude.toStringAsFixed(3)},${location!.longitude.toStringAsFixed(3)}'
        : 'NOGPS';
    return 'MHA|$shortId|$hashPrefix|${officer.badgeNumber}|$resCode|$gpsStr';
  }
}

enum AuditAction { view, export, search, sign }

class AuditLogEntry {
  final String logId;
  final String prevLogHash;
  final String actorId;
  final AuditAction action;
  final String? targetTestId;
  final DateTime timestamp;

  AuditLogEntry({
    required this.logId,
    required this.prevLogHash,
    required this.actorId,
    required this.action,
    this.targetTestId,
    required this.timestamp,
  });
}
