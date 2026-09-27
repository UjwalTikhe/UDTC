import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/record_model.dart';
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
    _database = await _initDB('ncb_field_ledger.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
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
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN confidence REAL DEFAULT 94.0');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN accused_present INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN reagent_window_ok INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN reaction_time_seconds INTEGER DEFAULT 30');
      await db.execute('ALTER TABLE chain_ledger ADD COLUMN is_sms_witnessed INTEGER DEFAULT 0');
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
      deviceId: "NCB-DEV-S24-IND01",
      kitType: "MARQUIS_OPIATE",
      classification: "PRESUMPTIVE_POSITIVE",
      deltaE2000: 2.64,
      confidence: 96.8,
      imageSha256: "b4a8e32c84279b9a19d854cf6097d8eefc8c7d3d5267b12260ff0d4810819777",
      cardSerial: "NCB-CARD-2026-0081",
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
      deviceId: "NCB-DEV-S24-IND01",
      kitType: "SCOTT_COCAINE",
      classification: "PRESUMPTIVE_NEGATIVE",
      deltaE2000: 38.45,
      confidence: 94.2,
      imageSha256: "c188f8d2e8e97a3297f6e3c153b89088b901fc82d5e5421f2bb8cb617cf12e98",
      cardSerial: "NCB-CARD-2026-0081",
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
}
