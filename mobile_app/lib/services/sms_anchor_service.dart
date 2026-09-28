import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/record_model.dart';
import 'local_ledger_database.dart';

class SmsDispatchEntry {
  final String testId;
  final String destinationNumber;
  final String gsmPayload;
  final DateTime timestamp;
  final String status; // 'DISPATCHED_SIM', 'QUEUED_OFFLINE', 'DELIVERED_WITNESS'
  final String? transmissionRef;

  SmsDispatchEntry({
    required this.testId,
    required this.destinationNumber,
    required this.gsmPayload,
    required this.timestamp,
    required this.status,
    this.transmissionRef,
  });
}

class SmsAnchorService {
  static final SmsAnchorService instance = SmsAnchorService._internal();
  SmsAnchorService._internal();

  static const MethodChannel _smsChannel = MethodChannel('in.gov.mha/sms');

  final String mhaGatewayNumber = "+91-11-2309-MHA1";
  final List<SmsDispatchEntry> _outbox = [];

  List<SmsDispatchEntry> get outboxHistory => List.unmodifiable(_outbox);

  /// Dispatches 140-char out-of-band witness anchor over the officer's device SIM
  Future<bool> dispatchSmsAnchor(LocalRecordModel record) async {
    final payload = record.toGsmSmsPayload();
    if (payload.length > 140) {
      throw StateError('SMS witness anchor exceeds the 140-character GSM limit.');
    }
    final now = DateTime.now();

    bool success = false;
    String status = "QUEUED_OFFLINE";
    String? error;
    String? ref;

    try {
      final res = await _smsChannel.invokeMethod<bool>('sendSms', {
        'to': mhaGatewayNumber,
        'message': payload,
      });
      if (res == true) {
        status = "DISPATCHED_SIM";
        success = true;
        ref = "GSM-${now.millisecondsSinceEpoch}";
      } else {
        error = "Native SMS channel did not confirm dispatch.";
      }
    } catch (e) {
      debugPrint("Native telephony dispatch queued for retry: $e");
      error = e.toString();
    }

    final entry = SmsDispatchEntry(
      testId: record.testId,
      destinationNumber: mhaGatewayNumber,
      gsmPayload: payload,
      timestamp: now,
      status: status,
      transmissionRef: ref,
    );
    _outbox.insert(0, entry);

    if (success) {
      await LocalLedgerDatabase.instance.markSmsWitnessed(record.testId);
      await LocalLedgerDatabase.instance.removeSmsOutbox(record.testId);
    } else {
      await LocalLedgerDatabase.instance.enqueueSmsAnchor(
        testId: record.testId,
        destination: mhaGatewayNumber,
        payload: payload,
        error: error,
      );
    }

    return success;
  }

  /// Direct SMS dispatch method
  Future<bool> sendSmsAnchor({
    required String destinationPhone,
    required String smsMessage,
  }) async {
    try {
      final res = await _smsChannel.invokeMethod<bool>('sendSms', {
        'to': destinationPhone,
        'message': smsMessage,
      });
      return res == true;
    } catch (e) {
      debugPrint("Native telephony direct send exception: $e");
      return false;
    }
  }
}
