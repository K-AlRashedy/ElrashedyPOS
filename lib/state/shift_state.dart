import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/operational_date.dart';
import 'app_state.dart';

/// Shift totals and the staged cash movements that belong to the operational day.
class ShiftState extends ChangeNotifier {
  ShiftState(this._app);

  final AppState _app;
  int? _branchId;

  ShiftSummary? summary;
  List<ShiftExpense> expenses = [];
  String expensesTotal = '0';
  bool loading = false;
  bool busy = false;
  String? error;

  bool get closed => summary?.closed ?? false;
  String get operationalDate => summary?.operationalDate ?? operationalDateIso(DateTime.now());

  void reset() {
    summary = null;
    expenses = [];
    expensesTotal = '0';
    error = null;
    notifyListeners();
  }

  Future<void> refresh({bool silent = false}) async {
    final api = _app.api;
    final id = _app.branchId;
    if (api == null || id == null) return;
    if (_branchId != id) {
      _branchId = id;
      summary = null;
      expenses = [];
      expensesTotal = '0';
    }
    if (!silent) {
      loading = true;
      notifyListeners();
    }
    try {
      summary = await api.shiftSummary(id);
      error = null;
    } on ApiException catch (failure) {
      error = failure.message;
      if (!silent) _app.tell(failure.message, isError: true);
    } on TimeoutException {
      error = 'تعذر تحميل ملخص الوردية: انتهت المهلة.';
    } on SocketException {
      error = 'تعذر تحميل ملخص الوردية: لا يوجد اتصال.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadExpenses() async {
    final api = _app.api;
    final id = _app.branchId;
    if (api == null || id == null) return;
    try {
      final result = await api.shiftExpenses(id);
      expenses = result.expenses;
      expensesTotal = result.total;
      error = null;
    } on ApiException catch (failure) {
      error = failure.message;
    } on TimeoutException {
      error = 'تعذر تحميل المصروفات.';
    } on SocketException {
      error = 'تعذر تحميل المصروفات: لا يوجد اتصال.';
    }
    notifyListeners();
  }

  Future<String?> addExpense({required int accountId, required String amount, required String reason}) =>
      _submit(() => _app.api!.addExpense(
            branchId: _app.branchId!,
            accountId: accountId,
            amount: amount,
            reason: reason,
          ), 'تم حفظ المصروف مؤقتاً مع الوردية، بدون تغيير رصيد الخزينة.');

  Future<String?> addAdvance({required int employeeId, required String amount, required String notes}) =>
      _submit(() => _app.api!.addAdvance(
            branchId: _app.branchId!,
            employeeId: employeeId,
            amount: amount,
            notes: notes,
          ), 'تم حفظ السلفة مؤقتاً مع الوردية.');

  Future<String?> addSupplierPayment({required int supplierId, required String amount, required String notes}) =>
      _submit(() => _app.api!.addSupplierPayment(
            branchId: _app.branchId!,
            supplierId: supplierId,
            amount: amount,
            notes: notes,
          ), 'تم حفظ سداد المورد مؤقتاً مع الوردية.');

  Future<String?> _submit(Future<void> Function() job, String successMessage) async {
    if (_app.api == null || _app.branchId == null) return 'لا يوجد فرع محدد.';
    if (closed) return 'تم تقفيل الوردية. لا يمكن تسجيل حركات جديدة.';
    busy = true;
    notifyListeners();
    try {
      await job();
      await refresh(silent: true);
      await loadExpenses();
      _app.tell(successMessage);
      return null;
    } on ApiException catch (failure) {
      return failure.message;
    } on TimeoutException {
      return 'انتهت مهلة الاتصال بالخادم. لم يتم حفظ الحركة.';
    } on SocketException {
      return 'لا يوجد اتصال بالخادم. تسجيل الحركات يحتاج اتصالاً.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Mirrors the browser guard: sync, re-read, then refuse if anything is still local.
  Future<String?> closeShift(String shift) async {
    final api = _app.api;
    final id = _app.branchId;
    final user = _app.user;
    if (api == null || id == null || user == null) return 'لا يوجد فرع محدد.';
    busy = true;
    notifyListeners();
    try {
      await _app.syncNow();
      await refresh(silent: true);
      final latest = summary;
      if (latest == null) return 'تعذر التحقق من بيانات الوردية. اتصل بالخادم أولاً.';
      if (latest.closed) return 'تم إرسال الوردية للمراجعة بالفعل #${latest.cashInId}.';
      final pending = (await _app.db.pendingTickets(user.id))
          .where((ticket) =>
              ticket.branchId == id && operationalDateIso(ticket.placedAt) == latest.operationalDate)
          .length;
      if (pending > 0) return 'يوجد $pending طلب غير متزامن. اتصل بالإنترنت واضغط مزامنة قبل التقفيل.';
      final cashInId = await api.closeShift(branchId: id, shift: shift);
      await refresh(silent: true);
      _app.tell('تم إرسال تقفيل الوردية #$cashInId إلى محاسب الخزينة للمراجعة.');
      return null;
    } on ApiException catch (failure) {
      return failure.message;
    } on TimeoutException {
      return 'انتهت مهلة الاتصال بالخادم. لم يتم تقفيل الوردية.';
    } on SocketException {
      return 'لا يوجد اتصال بالخادم. تقفيل الوردية يحتاج اتصالاً.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}