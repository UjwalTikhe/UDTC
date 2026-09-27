import '../models/record_model.dart';
import '../services/local_ledger_database.dart';

/// Abstract Data Contract for Field Record Repository
/// Enforces Data Abstraction: UI layers (Dashboard, History, Supervisor Queue)
/// depend exclusively on this abstract interface, remaining completely isolated from
/// raw SQL databases, table schemas, and cryptographic file storage.
abstract class IFieldRecordRepository {
  Future<List<LocalRecordModel>> getRecentRecords({int limit = 10});
  Future<List<LocalRecordModel>> getAllRecords();
  Future<LocalRecordModel?> getRecordById(String testId);
  Future<void> saveRecord(LocalRecordModel record);
  Future<LedgerIntegrityReport> verifyChainIntegrity();
  Future<int> getPendingSyncCount();
  Future<int> getTotalRecordCount();
}

/// Concrete Encapsulated Repository Implementation
/// Encapsulates all query executions, cryptographic hash checks,
/// and data-mapping mechanisms.
class FieldRecordRepository implements IFieldRecordRepository {
  static final FieldRecordRepository instance = FieldRecordRepository._internal();
  final LocalLedgerDatabase _db;

  FieldRecordRepository._internal({LocalLedgerDatabase? db})
      : _db = db ?? LocalLedgerDatabase.instance;

  @override
  Future<List<LocalRecordModel>> getRecentRecords({int limit = 10}) async {
    final records = await _db.getAllRecords();
    return records.take(limit).toList();
  }

  @override
  Future<List<LocalRecordModel>> getAllRecords() async {
    return await _db.getAllRecords();
  }

  @override
  Future<LocalRecordModel?> getRecordById(String testId) async {
    return await _db.getRecordById(testId);
  }

  @override
  Future<void> saveRecord(LocalRecordModel record) async {
    await _db.insertRecord(record);
  }

  @override
  Future<LedgerIntegrityReport> verifyChainIntegrity() async {
    return await _db.verifyChainIntegrity();
  }

  @override
  Future<int> getPendingSyncCount() async {
    final records = await _db.getAllRecords();
    return records.where((r) => r.isStage1Synced == 0).length;
  }

  @override
  Future<int> getTotalRecordCount() async {
    final records = await _db.getAllRecords();
    return records.length;
  }
}
