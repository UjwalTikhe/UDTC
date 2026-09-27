import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:crypto/crypto.dart';
import '../models/record_model.dart';
import '../models/domain_models.dart';
import 'crypto_signer_service.dart';

class LedgerIntegrityReport {
  final bool isValid;
  final int totalBlocks;
  final int? brokenBlockIndex;
  final String? brokenTestId;
  final String message;

  LedgerIntegrityReport({
    required this.isValid,
    required this.totalBlocks,
    this.brokenBlockIndex,
    this.brokenTestId,
    required this.message,
  });

  int get verifiedBlocks => totalBlocks;
}

class LocalLedgerDatabase {
  static final LocalLedgerDatabase instance = LocalLedgerDatabase._init();
  static Database? _database;

  LocalLedgerDatabase._init();

  static const String genesisHash = '0000000000000000000000000000000000000000000000000000000000000000';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mha_field_ledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chain_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        test_id TEXT NOT NULL UNIQUE,
        timestamp_utc REAL NOT NULL,
        officer_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        kit_type TEXT NOT NULL,
        classification TEXT NOT NULL,
        delta_e2000 REAL NOT NULL,
        confidence REAL NOT NULL,
        image_sha256 TEXT NOT NULL,
        card_serial TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        location_status TEXT NOT NULL,
        accused_present INTEGER DEFAULT 1,
        reagent_window_ok INTEGER DEFAULT 1,
        reaction_time_seconds INTEGER DEFAULT 30,
        prev_hash TEXT NOT NULL,
        record_hash TEXT NOT NULL,
        device_sig_hex TEXT NOT NULL,
        officer_sig_hex TEXT NOT NULL,
        is_stage1_synced INTEGER DEFAULT 0,
        is_stage2_synced INTEGER DEFAULT 0,
        is_sms_witnessed INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        badge_number TEXT NOT NULL,
        age INTEGER NOT NULL DEFAULT 30,
        gender TEXT NOT NULL DEFAULT 'Male',
        city TEXT NOT NULL DEFAULT 'New Delhi',
        role TEXT NOT NULL DEFAULT 'officer',
        department TEXT NOT NULL DEFAULT 'Ministry of Home Affairs',
        password_hash TEXT NOT NULL,
        password_salt TEXT NOT NULL,
        device_id TEXT NOT NULL DEFAULT 'MHA-SECURE-DEV-001',
        dob TEXT DEFAULT '1996-05-15',
        phone TEXT DEFAULT '+91 98765 43210',
        rank TEXT DEFAULT 'Police Sub-Inspector (PSI)',
        unit TEXT DEFAULT 'Special Task Force (Anti-Narcotics Unit)',
        is_verified INTEGER DEFAULT 0,
        service_id TEXT,
        created_at REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS department_registry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id TEXT NOT NULL UNIQUE,
        badge_number TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        rank TEXT NOT NULL,
        unit TEXT NOT NULL,
        city TEXT NOT NULL,
        registered_phone TEXT NOT NULL,
        registered_email TEXT NOT NULL,
        role TEXT NOT NULL,
        credential_sig TEXT NOT NULL,
        is_activated INTEGER DEFAULT 0,
        device_id TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN confidence REAL DEFAULT 94.0');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN accused_present INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN reagent_window_ok INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN reaction_time_seconds INTEGER DEFAULT 30');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN is_sms_witnessed INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          email TEXT NOT NULL UNIQUE,
          badge_number TEXT NOT NULL UNIQUE,
          age INTEGER NOT NULL,
          gender TEXT NOT NULL,
          city TEXT NOT NULL,
          role TEXT NOT NULL,
          department TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          password_salt TEXT NOT NULL,
          device_id TEXT NOT NULL,
          created_at REAL NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS department_registry (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          service_id TEXT NOT NULL UNIQUE,
          badge_number TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          rank TEXT NOT NULL,
          unit TEXT NOT NULL,
          city TEXT NOT NULL,
          registered_phone TEXT NOT NULL,
          registered_email TEXT NOT NULL,
          role TEXT NOT NULL,
          credential_sig TEXT NOT NULL,
          is_activated INTEGER DEFAULT 0,
          device_id TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      try { await db.execute('ALTER TABLE users ADD COLUMN dob TEXT DEFAULT "1996-05-15"'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN phone TEXT DEFAULT "+91 98765 43210"'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN rank TEXT DEFAULT "Police Sub-Inspector (PSI)"'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN unit TEXT DEFAULT "Special Task Force (Anti-Narcotics Unit)"'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN is_verified INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE users ADD COLUMN service_id TEXT'); } catch (_) {}
    }
  }

  /// Retrieves the top-of-chain SHA-256 hash or Genesis hash if empty
  Future<String> getLastRecordHash() async {
    final db = await instance.database;
    final maps = await db.query(
      'chain_ledger',
      columns: ['record_hash'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['record_hash'] as String;
    }
    return genesisHash;
  }

  /// Appends a new immutable test record to the chain
  Future<LocalRecordModel> insertRecord(LocalRecordModel record) async {
    final db = await instance.database;
    await db.insert('chain_ledger', record.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
    return record;
  }

  /// Retrieves all records in descending order (latest first)
  Future<List<LocalRecordModel>> getAllRecords({bool latestFirst = true}) async {
    final db = await instance.database;
    final result = await db.query(
      'chain_ledger',
      orderBy: latestFirst ? 'id DESC' : 'id ASC',
    );
    return result.map((json) => LocalRecordModel.fromMap(json)).toList();
  }

  Future<LocalRecordModel?> getRecordById(String testId) async {
    final db = await instance.database;
    final maps = await db.query(
      'chain_ledger',
      where: 'test_id = ?',
      whereArgs: [testId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return LocalRecordModel.fromMap(maps.first);
    }
    return null;
  }

  /// Verifies the cryptographic integrity of the entire local append-only hash chain
  Future<LedgerIntegrityReport> verifyChainIntegrity() async {
    final records = await getAllRecords(latestFirst: false);
    if (records.isEmpty) {
      return LedgerIntegrityReport(
        isValid: true,
        totalBlocks: 0,
        message: "Ledger is empty (Genesis state). Chain is fully intact.",
      );
    }

    String expectedPrevHash = genesisHash;

    for (int i = 0; i < records.length; i++) {
      final r = records[i];

      // 1. Verify prev_hash linkage
      if (r.prevHash != expectedPrevHash) {
        return LedgerIntegrityReport(
          isValid: false,
          totalBlocks: records.length,
          brokenBlockIndex: i,
          brokenTestId: r.testId,
          message: "Chain Link Broken at Block #$i (${r.testId})! Expected prev_hash: $expectedPrevHash, but found: ${r.prevHash}",
        );
      }

      // 2. Recompute and verify record_hash
      final recomputed = LocalRecordModel.computeBlockSha256(r.toCanonicalJson(), r.prevHash);
      if (recomputed != r.recordHash) {
        return LedgerIntegrityReport(
          isValid: false,
          totalBlocks: records.length,
          brokenBlockIndex: i,
          brokenTestId: r.testId,
          message: "Data Tampering Detected at Block #$i (${r.testId})! Recomputed hash ($recomputed) does not match stored hash (${r.recordHash})",
        );
      }

      expectedPrevHash = r.recordHash;
    }

    return LedgerIntegrityReport(
      isValid: true,
      totalBlocks: records.length,
      message: "Chain Integrity Verified. All ${records.length} blocks mathematically linked and untampered.",
    );
  }

  Future<List<LocalRecordModel>> getUnsyncedStage1Records() async {
    final db = await instance.database;
    final result = await db.query(
      'chain_ledger',
      where: 'is_stage1_synced = ?',
      whereArgs: [0],
      orderBy: 'id ASC',
    );
    return result.map((json) => LocalRecordModel.fromMap(json)).toList();
  }

  Future<int> markStage1Synced(String testId) async {
    final db = await instance.database;
    return await db.update(
      'chain_ledger',
      {'is_stage1_synced': 1},
      where: 'test_id = ?',
      whereArgs: [testId],
    );
  }

  Future<int> markStage2Synced(String testId) async {
    final db = await instance.database;
    return await db.update(
      'chain_ledger',
      {'is_stage2_synced': 1},
      where: 'test_id = ?',
      whereArgs: [testId],
    );
  }

  Future<int> markSmsWitnessed(String testId) async {
    final db = await instance.database;
    return await db.update(
      'chain_ledger',
      {'is_sms_witnessed': 1},
      where: 'test_id = ?',
      whereArgs: [testId],
    );
  }

  /// Seeds default verified test records if database has no records
  Future<void> seedInitialDemoDataIfEmpty() async {
    final records = await getAllRecords();
    if (records.isNotEmpty) return;

    final signer = CryptoSignerService.instance;
    signer.initializeHardwareKeystore();

    // Sample 1: Marquis Opiate (Positive)
    final canonical1 = LocalRecordModel(
      testId: "NDPS-2026-TEST-0042",
      timestampUtc: DateTime.utc(2026, 9, 26, 14, 20).millisecondsSinceEpoch / 1000.0,
      officerId: "OFFICER-RAJESH-04",
      deviceId: "MHA-SECURE-DEV-001",
      kitType: "MARQUIS_OPIATE",
      classification: "PRESUMPTIVE_POSITIVE",
      deltaE2000: 2.64,
      confidence: 96.8,
      imageSha256: "b4a8e32c84279b9a19d854cf6097d8eefc8c7d3d5267b12260ff0d4810819777",
      cardSerial: "MHACARD-2026-DEL-0491",
      latitude: 28.5355,
      longitude: 77.2410,
      locationStatus: "GPS_CONFIRMED",
      accusedPresent: true,
      reagentWindowOk: true,
      reactionTimeSeconds: 32,
      prevHash: genesisHash,
      recordHash: "",
      deviceSigHex: "",
      officerSigHex: "",
      isStage1Synced: 1,
      isStage2Synced: 1,
      isSmsWitnessed: 1,
    );

    final hash1 = LocalRecordModel.computeBlockSha256(canonical1.toCanonicalJson(), genesisHash);
    final sigs1 = signer.signDualBound(
      canonicalRecordPayload: canonical1.toCanonicalJson(),
      officerPin: "749210",
      officerId: "OFFICER-RAJESH-04",
    );

    final record1 = LocalRecordModel(
      testId: canonical1.testId,
      timestampUtc: canonical1.timestampUtc,
      officerId: canonical1.officerId,
      deviceId: canonical1.deviceId,
      kitType: canonical1.kitType,
      classification: canonical1.classification,
      deltaE2000: canonical1.deltaE2000,
      confidence: canonical1.confidence,
      imageSha256: canonical1.imageSha256,
      cardSerial: canonical1.cardSerial,
      latitude: canonical1.latitude,
      longitude: canonical1.longitude,
      locationStatus: canonical1.locationStatus,
      accusedPresent: canonical1.accusedPresent,
      reagentWindowOk: canonical1.reagentWindowOk,
      reactionTimeSeconds: canonical1.reactionTimeSeconds,
      prevHash: genesisHash,
      recordHash: hash1,
      deviceSigHex: sigs1.deviceSigHex,
      officerSigHex: sigs1.officerSigHex,
      isStage1Synced: 1,
      isStage2Synced: 1,
      isSmsWitnessed: 1,
    );
    await insertRecord(record1);

    // Sample 2: Scott Cocaine (Negative)
    final canonical2 = LocalRecordModel(
      testId: "NDPS-2026-TEST-0043",
      timestampUtc: DateTime.utc(2026, 9, 26, 18, 45).millisecondsSinceEpoch / 1000.0,
      officerId: "OFFICER-RAJESH-04",
      deviceId: "MHA-SECURE-DEV-001",
      kitType: "SCOTT_COCAINE",
      classification: "PRESUMPTIVE_NEGATIVE",
      deltaE2000: 38.45,
      confidence: 94.2,
      imageSha256: "c188f8d2e8e97a3297f6e3c153b89088b901fc82d5e5421f2bb8cb617cf12e98",
      cardSerial: "MHACARD-2026-DEL-0491",
      latitude: 28.5361,
      longitude: 77.2418,
      locationStatus: "GPS_CONFIRMED",
      accusedPresent: true,
      reagentWindowOk: true,
      reactionTimeSeconds: 24,
      prevHash: hash1,
      recordHash: "",
      deviceSigHex: "",
      officerSigHex: "",
      isStage1Synced: 1,
      isStage2Synced: 0,
      isSmsWitnessed: 1,
    );

    final hash2 = LocalRecordModel.computeBlockSha256(canonical2.toCanonicalJson(), hash1);
    final sigs2 = signer.signDualBound(
      canonicalRecordPayload: canonical2.toCanonicalJson(),
      officerPin: "749210",
      officerId: "OFFICER-RAJESH-04",
    );

    final record2 = LocalRecordModel(
      testId: canonical2.testId,
      timestampUtc: canonical2.timestampUtc,
      officerId: canonical2.officerId,
      deviceId: canonical2.deviceId,
      kitType: canonical2.kitType,
      classification: canonical2.classification,
      deltaE2000: canonical2.deltaE2000,
      confidence: canonical2.confidence,
      imageSha256: canonical2.imageSha256,
      cardSerial: canonical2.cardSerial,
      latitude: canonical2.latitude,
      longitude: canonical2.longitude,
      locationStatus: canonical2.locationStatus,
      accusedPresent: canonical2.accusedPresent,
      reagentWindowOk: canonical2.reagentWindowOk,
      reactionTimeSeconds: canonical2.reactionTimeSeconds,
      prevHash: hash1,
      recordHash: hash2,
      deviceSigHex: sigs2.deviceSigHex,
      officerSigHex: sigs2.officerSigHex,
      isStage1Synced: 1,
      isStage2Synced: 0,
      isSmsWitnessed: 1,
    );
    await insertRecord(record2);
  }

  // ==========================================
  // USER AUTHENTICATION & CREDENTIAL DATABASE
  // Ministry of Home Affairs Secure Sign-Up / Sign-In
  // ==========================================

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password:MHA_GOV_SECURE_SALT_2026');
    return sha256.convert(bytes).toString();
  }

  Future<void> seedDefaultUsersIfEmpty() async {
    final db = await instance.database;
    final res = await db.query('users', limit: 1);
    if (res.isEmpty) {
      // Seed Ujwal Tikhe (PSI)
      await registerUser(
        name: "Ujwal Tikhe",
        email: "ujwal.tikhe@mha.gov.in",
        badgeNumber: "MH-8842",
        age: 28,
        gender: "Male",
        city: "Mumbai",
        role: Role.officer,
        password: "Officer@123",
        department: "Ministry of Home Affairs • Special Task Force",
        deviceId: "MHA-SECURE-DEV-001",
        rank: "Police Sub-Inspector (PSI)",
        unit: "Special Task Force (Anti-Narcotics Unit)",
        isVerified: true,
        serviceId: "MH-PSI-2026-081",
        phone: "+91 98765 43210",
        dob: "1998-08-14",
      );

      // Seed Rajesh Kumar (ASI)
      await registerUser(
        name: "Rajesh Kumar",
        email: "officer@mha.gov.in",
        badgeNumber: "MHA-NZ-7841",
        age: 34,
        gender: "Male",
        city: "New Delhi",
        role: Role.officer,
        password: "Officer@123",
        department: "Ministry of Home Affairs • Forensic Operations Division",
        deviceId: "MHA-SECURE-DEV-001",
        rank: "Assistant Sub-Inspector (ASI)",
        unit: "Northern Zone Field Unit",
        isVerified: true,
        serviceId: "MHA-SO-2026-7841",
        phone: "+91 98990 12345",
        dob: "1992-03-22",
      );

      // Seed Amitabh Sharma (SP)
      await registerUser(
        name: "Amitabh Sharma",
        email: "supervisor@mha.gov.in",
        badgeNumber: "MH-1002",
        age: 48,
        gender: "Male",
        city: "New Delhi",
        role: Role.supervisor,
        password: "Supervisor@123",
        department: "Ministry of Home Affairs • Forensic Directorate",
        deviceId: "MHA-SECURE-DEV-001",
        rank: "Superintendent of Police (SP)",
        unit: "Zonal Forensic Directorate",
        isVerified: true,
        serviceId: "MHA-SP-2026-004",
        phone: "+91 98110 98765",
        dob: "1978-11-05",
      );
    }

    // Always seed department registry as well
    await seedDepartmentRegistryIfEmpty();
  }

  Future<void> seedDepartmentRegistryIfEmpty() async {
    final db = await instance.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS department_registry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id TEXT NOT NULL UNIQUE,
        badge_number TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        rank TEXT NOT NULL,
        unit TEXT NOT NULL,
        city TEXT NOT NULL,
        registered_phone TEXT NOT NULL,
        registered_email TEXT NOT NULL,
        role TEXT NOT NULL,
        credential_sig TEXT NOT NULL,
        is_activated INTEGER DEFAULT 0,
        device_id TEXT
      )
    ''');

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM department_registry'),
    ) ?? 0;

    if (count > 0) return;

    final officers = [
      const DepartmentOfficer(
        serviceId: "MH-PSI-2026-081",
        badgeNumber: "MH-8842",
        name: "Ujwal Tikhe",
        rank: "Police Sub-Inspector (PSI)",
        unit: "Special Task Force (Anti-Narcotics Unit)",
        city: "Mumbai",
        registeredPhone: "+91 98765 43210",
        registeredEmail: "ujwal.tikhe@mha.gov.in",
        role: Role.officer,
        credentialSig: "MHA-PKI-ECDSA-P256:7D88B923A0F11C84",
        isActivated: true,
        deviceId: "MHA-SECURE-DEV-001",
      ),
      const DepartmentOfficer(
        serviceId: "MHA-SP-2026-004",
        badgeNumber: "MH-1002",
        name: "Amitabh Sharma",
        rank: "Superintendent of Police (SP)",
        unit: "Zonal Forensic Directorate",
        city: "New Delhi",
        registeredPhone: "+91 98110 98765",
        registeredEmail: "amitabh.sharma@mha.gov.in",
        role: Role.supervisor,
        credentialSig: "MHA-PKI-ECDSA-P256:4C29E711DF92003B",
        isActivated: true,
        deviceId: "MHA-SECURE-DEV-001",
      ),
      const DepartmentOfficer(
        serviceId: "MHA-SO-2026-7841",
        badgeNumber: "MHA-NZ-7841",
        name: "Rajesh Kumar",
        rank: "Assistant Sub-Inspector (ASI)",
        unit: "Northern Zone Field Unit",
        city: "New Delhi",
        registeredPhone: "+91 98990 12345",
        registeredEmail: "officer@mha.gov.in",
        role: Role.officer,
        credentialSig: "MHA-PKI-ECDSA-P256:91AE3F08B764512A",
        isActivated: true,
        deviceId: "MHA-SECURE-DEV-001",
      ),
    ];

    for (final off in officers) {
      await db.insert(
        'department_registry',
        off.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<DepartmentOfficer?> lookupDepartmentRegistry(String query) async {
    final db = await instance.database;
    final clean = query.trim().toUpperCase();
    if (clean.isEmpty) return null;

    await seedDepartmentRegistryIfEmpty();

    final results = await db.query(
      'department_registry',
      where: 'UPPER(badge_number) = ? OR UPPER(service_id) = ?',
      whereArgs: [clean, clean],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return DepartmentOfficer.fromMap(results.first);
  }

  Future<User> provisionOfficerFromRegistry(
    DepartmentOfficer officer, {
    String? password,
    String? deviceId,
  }) async {
    final db = await instance.database;
    final devId = deviceId ?? "MHA-SECURE-DEV-001";
    final effectivePass = password ?? "Officer@123";

    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ? OR UPPER(badge_number) = ?',
      whereArgs: [officer.registeredEmail.toLowerCase(), officer.badgeNumber.toUpperCase()],
      limit: 1,
    );

    if (existing.isEmpty) {
      final salt = "${DateTime.now().millisecondsSinceEpoch}_${officer.registeredEmail.hashCode}";
      final passHash = hashPassword(effectivePass, salt);
      final userId = "MHA-${officer.badgeNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}";
      final nowUtc = DateTime.now().millisecondsSinceEpoch / 1000.0;

      await db.insert(
        'users',
        {
          'user_id': userId,
          'name': officer.name,
          'email': officer.registeredEmail.toLowerCase(),
          'badge_number': officer.badgeNumber.toUpperCase(),
          'age': 32,
          'gender': 'Male',
          'city': officer.city,
          'role': officer.role.name,
          'department': "${officer.unit} • Ministry of Home Affairs",
          'password_hash': passHash,
          'password_salt': salt,
          'device_id': devId,
          'created_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return User(
      userId: "MHA-${officer.badgeNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}",
      name: officer.name,
      email: officer.registeredEmail,
      badgeNumber: officer.badgeNumber,
      age: 32,
      gender: "Male",
      city: officer.city,
      department: "${officer.unit} • Ministry of Home Affairs",
      role: officer.role,
      deviceId: devId,
      provisionedAt: DateTime.now(),
      rank: officer.rank,
      unit: officer.unit,
      isVerified: true,
      serviceId: officer.serviceId,
    );
  }

  Future<User> registerUser({
    required String name,
    required String email,
    required String badgeNumber,
    required int age,
    required String gender,
    required String city,
    required Role role,
    required String password,
    String? department,
    String? deviceId,
    String? rank,
    String? unit,
    bool isVerified = true,
    String? serviceId,
    String dob = "1996-05-15",
    String phone = "+91 98765 43210",
  }) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();
    final cleanBadge = badgeNumber.trim().toUpperCase();

    // Check if already registered
    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ? OR UPPER(badge_number) = ?',
      whereArgs: [cleanEmail, cleanBadge],
    );
    if (existing.isNotEmpty) {
      if (existing.first['email'] == cleanEmail) {
        throw Exception("An officer account with email '$cleanEmail' already exists.");
      } else {
        throw Exception("Badge number '$cleanBadge' is already registered.");
      }
    }

    final salt = "${DateTime.now().millisecondsSinceEpoch}_${cleanEmail.hashCode}";
    final passHash = hashPassword(password, salt);
    final userId = "MHA-${cleanBadge.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}";
    final dept = department ?? "Ministry of Home Affairs • Forensic Operations Division";
    final devId = deviceId ?? "MHA-SECURE-DEV-001";
    final effRank = rank ?? (role == Role.supervisor ? "Superintendent of Police (SP)" : "Police Sub-Inspector (PSI)");
    final effUnit = unit ?? "Special Task Force (Anti-Narcotics Unit)";
    final nowUtc = DateTime.now().millisecondsSinceEpoch / 1000.0;

    await db.insert(
      'users',
      {
        'user_id': userId,
        'name': name.trim(),
        'email': cleanEmail,
        'badge_number': cleanBadge,
        'age': age,
        'gender': gender,
        'city': city.trim(),
        'role': role.name,
        'department': dept,
        'password_hash': passHash,
        'password_salt': salt,
        'device_id': devId,
        'dob': dob,
        'phone': phone,
        'rank': effRank,
        'unit': effUnit,
        'is_verified': isVerified ? 1 : 0,
        'service_id': serviceId,
        'created_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return User(
      userId: userId,
      name: name.trim(),
      email: cleanEmail,
      badgeNumber: cleanBadge,
      age: age,
      gender: gender,
      city: city.trim(),
      department: dept,
      role: role,
      deviceId: devId,
      provisionedAt: DateTime.now(),
      rank: effRank,
      unit: effUnit,
      isVerified: isVerified,
      serviceId: serviceId,
      dob: dob,
      phone: phone,
    );
  }

  /// Simplified registration: Sign up with Email and Password only (+ optional Name)
  Future<User> registerUserWithEmail({
    required String email,
    required String password,
    String? name,
  }) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();

    final existing = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );
    if (existing.isNotEmpty) {
      throw Exception("An officer account with email '$cleanEmail' already exists. Please Sign In.");
    }

    final salt = "${DateTime.now().millisecondsSinceEpoch}_${cleanEmail.hashCode}";
    final passHash = hashPassword(password, salt);
    final randomDigits = (DateTime.now().millisecondsSinceEpoch % 9000 + 1000).toString();
    final placeholderBadge = "MHA-PENDING-$randomDigits";
    final userId = "MHA-$randomDigits";
    final effectiveName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : "Officer ${cleanEmail.split('@').first}";
    final nowUtc = DateTime.now().millisecondsSinceEpoch / 1000.0;

    await db.insert(
      'users',
      {
        'user_id': userId,
        'name': effectiveName,
        'email': cleanEmail,
        'badge_number': placeholderBadge,
        'age': 28,
        'gender': 'Male',
        'city': 'New Delhi',
        'role': Role.officer.name,
        'department': 'Ministry of Home Affairs • Field Operations',
        'password_hash': passHash,
        'password_salt': salt,
        'device_id': 'MHA-SECURE-DEV-001',
        'dob': '1998-05-15',
        'phone': '+91 98765 00000',
        'rank': 'Field Officer (Unverified)',
        'unit': 'Anti-Narcotics Field Operations',
        'is_verified': 0,
        'service_id': null,
        'created_at': nowUtc,
      },
    );

    return User(
      userId: userId,
      name: effectiveName,
      email: cleanEmail,
      badgeNumber: placeholderBadge,
      age: 28,
      gender: 'Male',
      city: 'New Delhi',
      department: 'Ministry of Home Affairs • Field Operations',
      role: Role.officer,
      deviceId: 'MHA-SECURE-DEV-001',
      provisionedAt: DateTime.now(),
      rank: 'Field Officer (Unverified)',
      unit: 'Anti-Narcotics Field Operations',
      isVerified: false,
      dob: '1998-05-15',
      phone: '+91 98765 00000',
    );
  }

  /// Update personal details in local SQLite database
  Future<User> updateUserProfile({
    required String email,
    String? name,
    String? gender,
    String? dob,
    String? city,
    String? phone,
    int? age,
  }) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();

    final updateData = <String, dynamic>{};
    if (name != null && name.trim().isNotEmpty) updateData['name'] = name.trim();
    if (gender != null && gender.trim().isNotEmpty) updateData['gender'] = gender.trim();
    if (dob != null && dob.trim().isNotEmpty) updateData['dob'] = dob.trim();
    if (city != null && city.trim().isNotEmpty) updateData['city'] = city.trim();
    if (phone != null && phone.trim().isNotEmpty) updateData['phone'] = phone.trim();
    if (age != null && age > 0) updateData['age'] = age;

    if (updateData.isNotEmpty) {
      await db.update(
        'users',
        updateData,
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
      );
    }

    final updated = await getUserByEmail(cleanEmail);
    return updated!;
  }

  /// Update officer password with salted SHA-256 validation
  Future<void> changePassword({
    required String email,
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (results.isEmpty) {
      throw Exception("Officer account not found.");
    }

    final row = results.first;
    final storedHash = row['password_hash'] as String;
    final salt = row['password_salt'] as String;

    final computedHash = hashPassword(oldPassword, salt);
    if (computedHash != storedHash) {
      throw Exception("Current password verification failed. Please try again.");
    }

    if (newPassword.trim().length < 6) {
      throw Exception("New password must be at least 6 characters.");
    }

    final newSalt = "${DateTime.now().millisecondsSinceEpoch}_${cleanEmail.hashCode}";
    final newPassHash = hashPassword(newPassword.trim(), newSalt);

    await db.update(
      'users',
      {
        'password_hash': newPassHash,
        'password_salt': newSalt,
      },
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );
  }

  /// Bind logged-in account to verified Department Registry record
  Future<User> bindUserToDepartmentOfficer({
    required String userEmail,
    required DepartmentOfficer officer,
  }) async {
    final db = await instance.database;
    final cleanEmail = userEmail.trim().toLowerCase();

    await db.update(
      'users',
      {
        'name': officer.name,
        'badge_number': officer.badgeNumber,
        'rank': officer.rank,
        'unit': officer.unit,
        'city': officer.city,
        'role': officer.role.name,
        'department': "${officer.unit} • Ministry of Home Affairs",
        'is_verified': 1,
        'service_id': officer.serviceId,
        'phone': officer.registeredPhone,
      },
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
    );

    await db.update(
      'department_registry',
      {
        'is_activated': 1,
        'device_id': 'MHA-SECURE-DEV-001',
      },
      where: 'service_id = ?',
      whereArgs: [officer.serviceId],
    );

    final updated = await getUserByEmail(cleanEmail);
    return updated!;
  }

  Future<User?> authenticateUser({
    required String email,
    required String password,
  }) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;
    final storedHash = row['password_hash'] as String;
    final salt = row['password_salt'] as String;

    final computedHash = hashPassword(password, salt);
    if (computedHash != storedHash) {
      return null;
    }

    return User(
      userId: row['user_id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      badgeNumber: row['badge_number'] as String,
      age: (row['age'] as num).toInt(),
      gender: row['gender'] as String,
      city: row['city'] as String,
      department: row['department'] as String,
      role: Role.values.firstWhere((e) => e.name == row['role'], orElse: () => Role.officer),
      deviceId: row['device_id'] as String,
      provisionedAt: DateTime.fromMillisecondsSinceEpoch(((row['created_at'] as num) * 1000).toInt()),
      rank: row['rank'] as String? ?? 'Police Sub-Inspector (PSI)',
      unit: row['unit'] as String? ?? 'Special Task Force (Anti-Narcotics Unit)',
      isVerified: (row['is_verified'] as num?)?.toInt() == 1,
      serviceId: row['service_id'] as String?,
      dob: row['dob'] as String? ?? '1996-05-15',
      phone: row['phone'] as String? ?? '+91 98765 43210',
    );
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await instance.database;
    final cleanEmail = email.trim().toLowerCase();

    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return User(
      userId: row['user_id'] as String,
      name: row['name'] as String,
      email: row['email'] as String,
      badgeNumber: row['badge_number'] as String,
      age: (row['age'] as num).toInt(),
      gender: row['gender'] as String,
      city: row['city'] as String,
      department: row['department'] as String,
      role: Role.values.firstWhere((e) => e.name == row['role'], orElse: () => Role.officer),
      deviceId: row['device_id'] as String,
      provisionedAt: DateTime.fromMillisecondsSinceEpoch(((row['created_at'] as num) * 1000).toInt()),
      rank: row['rank'] as String? ?? 'Police Sub-Inspector (PSI)',
      unit: row['unit'] as String? ?? 'Special Task Force (Anti-Narcotics Unit)',
      isVerified: (row['is_verified'] as num?)?.toInt() == 1,
      serviceId: row['service_id'] as String?,
      dob: row['dob'] as String? ?? '1996-05-15',
      phone: row['phone'] as String? ?? '+91 98765 43210',
    );
  }
}
