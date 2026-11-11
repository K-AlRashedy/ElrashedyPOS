import 'dart:async';
import 'dart:io';

import 'api_client.dart';
import 'local_db.dart';
import 'ticket.dart';

class SyncReport {
  const SyncReport({
    required this.synced,
    required this.pending,
    this.blockedReason,
    this.authFailure = false,
  });

  final int synced;
  final int pending;
  final String? blockedReason;
  final bool authFailure;
}

/// Replays the local outbox against ``pos_sync``.
///
/// Mirrors the browser terminal: tickets are kept on any failure, auth failures
/// stop the run, and a price conflict (409) is left for a manager to reconcile.
class SyncEngine {
  SyncEngine(this._db, this._api, {required this.userId});

  final LocalDb _db;
  final ApiClient _api;
  final int userId;

  Timer? _timer;
  bool _running = false;
  bool online = true;
  String? lastError;

  void startPeriodic({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => syncNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SyncReport> syncNow() async {
    if (_running) return SyncReport(synced: 0, pending: await _db.pendingCount(userId));
    _running = true;
    var synced = 0;
    String? blocked;
    var authFailure = false;
    try {
      final pending = await _db.pendingTickets(userId);
      for (final ticket in pending) {
        try {
          final result = await _api.syncTicket(ticket);
          ticket
            ..synced = true
            ..serverId = result.saleId
            ..error = null
            ..attempts = ticket.attempts + 1;
          await _db.saveTicket(ticket);
          synced++;
          online = true;
        } on ApiException catch (error) {
          online = true;
          ticket
            ..error = error.message
            ..attempts = ticket.attempts + 1;
          await _db.saveTicket(ticket);
          if (error.isAuth) {
            blocked = error.message;
            authFailure = true;
            break;
          }
        } on TimeoutException {
          online = false;
          blocked = 'الخادم غير متاح. الطلبات محفوظة وستتم إعادة المزامنة.';
          break;
        } on SocketException {
          online = false;
          blocked = 'لا يوجد اتصال بالخادم. الطلبات محفوظة على الجهاز.';
          break;
        } on HttpException {
          online = false;
          blocked = 'تعذر الاتصال بالخادم. الطلبات محفوظة على الجهاز.';
          break;
        }
      }
      lastError = blocked;
      return SyncReport(
        synced: synced,
        pending: await _db.pendingCount(userId),
        blockedReason: blocked,
        authFailure: authFailure,
      );
    } finally {
      _running = false;
    }
  }

  Future<List<Ticket>> history() => _db.tickets(userId);

  Future<int> pendingCount() => _db.pendingCount(userId);
}