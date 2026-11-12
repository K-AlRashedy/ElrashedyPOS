import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/api_client.dart';
import '../core/local_db.dart';
import '../core/models.dart';
import '../core/secure_store.dart';
import '../core/settings.dart';
import '../core/sync_engine.dart';
import 'cart_state.dart';
import 'printer_state.dart';
import 'shift_state.dart';

class Toast {
  const Toast(this.id, this.text, this.isError);
  final int id;
  final String text;
  final bool isError;
}

/// Session, settings, menu and outbox owner for the whole terminal.
class AppState extends ChangeNotifier {
  AppState._({required this.db, required this.secure, required this.settings}) {
    cart = CartState(this);
    shift = ShiftState(this);
    printer = PrinterState(settings.printers, (next) async {
      settings.printers = next;
      await saveSettings();
    }, (message, isError) => tell(message, isError: isError));
  }

  static Future<AppState> create() async {
    final db = await LocalDb.open();
    final stored = await db.getSetting('app');
    final settings = stored == null
        ? AppSettings()
        : AppSettings.fromJson(jsonDecode(stored) as Map<String, dynamic>);
    final app = AppState._(db: db, secure: SecureStore(), settings: settings);
    await app._restore();
    return app;
  }

  final LocalDb db;
  final SecureStore secure;
  final AppSettings settings;

  late final CartState cart;
  late final ShiftState shift;
  late final PrinterState printer;

  ApiClient? _api;
  SyncEngine? _sync;
  Timer? _clock;

  PosUser? user;
  Bootstrap? bootstrap;
  int? branchId;
  List<PosProduct> products = [];
  String? menuCachedAt;
  bool busy = false;
  bool online = true;
  int pendingCount = 0;
  DateTime? lastSyncAt;
  String? syncError;
  String? updateVersion;
  String? updateUrl;
  String appVersion = '';
  Toast? toast;
  int _toastSeq = 0;

  bool get signedIn => user != null;
  bool get canChangeBranch => user?.isSuperuser == true;
  ApiClient? get api => _api;
  List<PosBranch> get branches => bootstrap?.branches ?? const [];
  PosBranch? get branch {
    for (final item in branches) {
      if (item.id == branchId) return item;
    }
    return null;
  }

  bool get shiftClosed => shift.closed;

  void tell(String text, {bool isError = false}) {
    toast = Toast(++_toastSeq, text, isError);
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await db.setSetting('app', jsonEncode(settings.toJson()));
    notifyListeners();
  }

  Future<void> _restore() async {
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      appVersion = '';
    }
    final token = await secure.readToken();
    if (token == null || settings.serverUrl.isEmpty) return;
    _api = ApiClient(baseUrl: settings.serverUrl, token: token);
    try {
      await _applyBootstrap(await _api!.bootstrapRaw());
      await loadMenu();
      await syncNow();
      unawaited(checkForUpdate());
    } on ApiException catch (error) {
      if (error.isAuth) {
        await _forgetSession();
        tell(error.message, isError: true);
      } else {
        await _useCachedSession();
        tell(error.message, isError: true);
      }
    } on TimeoutException {
      await _useCachedSession();
    } on SocketException {
      await _useCachedSession();
    } on HttpException {
      await _useCachedSession();
    }
  }

  Future<void> _useCachedSession() async {
    final cached = await db.getSetting('bootstrap');
    if (cached == null) {
      await _forgetSession();
      tell(
        'لا يوجد اتصال بالخادم ولا نسخة محفوظة. اتصل بالإنترنت وسجّل الدخول مرة أخرى.',
        isError: true,
      );
      return;
    }
    await _applyBootstrap(
      jsonDecode(cached) as Map<String, dynamic>,
      persist: false,
    );
    await loadMenu();
    online = false;
    tell(
      'وضع عدم الاتصال: يتم عرض آخر بيانات محفوظة. الطلبات ستنتظر المزامنة.',
    );
  }

  Future<void> _forgetSession() async {
    _sync?.stop();
    _sync = null;
    await secure.clearToken();
    _api = null;
    user = null;
    bootstrap = null;
    branchId = null;
    products = [];
    pendingCount = 0;
    cart.reset();
    shift.reset();
  }

  Future<void> _applyBootstrap(
    Map<String, dynamic> raw, {
    bool persist = true,
  }) async {
    final data = Bootstrap.fromJson(raw);
    bootstrap = data;
    user = data.user;
    if (persist) await db.setSetting('bootstrap', jsonEncode(raw));
    final savedRaw = await db.getSetting('branch');
    final saved = int.tryParse(savedRaw ?? '');
    final allowed = data.branches.map((item) => item.id).toSet();
    if (savedRaw != null) {
      branchId = saved != null && allowed.contains(saved) ? saved : null;
    } else {
      PosBranch? initialBranch;
      for (final branch in data.branches) {
        if (branch.name == data.user.branchName) {
          initialBranch = branch;
          break;
        }
      }
      initialBranch ??= data.branches.isEmpty ? null : data.branches.first;
      branchId = initialBranch?.id;
      if (branchId != null) await db.setSetting('branch', '$branchId');
    }
    products = data.products.where((product) => product.isMenuSection).toList();
    _startSync();
    await cart.loadDraft();
    await refreshPending();
    if (branchId != null) await shift.refresh(silent: true);
    notifyListeners();
  }

  void _startSync() {
    _sync?.stop();
    final api = _api;
    final currentUser = user;
    if (api == null || currentUser == null) return;
    _sync = SyncEngine(db, api, userId: currentUser.id);
    _sync!.startPeriodic();
    _clock?.cancel();
    _clock = Timer.periodic(
      const Duration(minutes: 1),
      (_) => notifyListeners(),
    );
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    busy = true;
    notifyListeners();
    try {
      settings.serverUrl = ApiClient.normalizeBaseUrl(serverUrl);
      await saveSettings();
      final api = ApiClient(baseUrl: settings.serverUrl);
      final result = await api.login(
        username: username,
        password: password,
        deviceName: settings.deviceName,
      );
      api.token = result.token;
      await secure.writeToken(result.token);
      _api = api;
      await _applyBootstrap(await api.bootstrapRaw());
      await loadMenu();
      await syncNow();
      unawaited(checkForUpdate());
      tell('مرحباً ${result.user.displayName}. الكاشير جاهز.');
      return true;
    } on ApiException catch (error) {
      tell(error.message, isError: true);
      return false;
    } on TimeoutException {
      tell('انتهت مهلة الاتصال بالخادم. راجع العنوان والشبكة.', isError: true);
      return false;
    } on SocketException catch (error) {
      tell(
        'تعذر الوصول إلى الخادم. ${error.osError?.message ?? ''}',
        isError: true,
      );
      return false;
    } on FormatException {
      tell('عنوان الخادم غير صحيح.', isError: true);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final api = _api;
    if (api != null) await api.logout();
    await _forgetSession();
    notifyListeners();
  }

  Future<void> selectBranch(int id) async {
    if (!canChangeBranch) {
      tell('تغيير الفرع متاح للمستخدم الرئيسي فقط.', isError: true);
      return;
    }
    if (!branches.any((branch) => branch.id == id)) {
      tell('الفرع المحدد غير متاح لهذا المستخدم.', isError: true);
      return;
    }
    if (branchId == id) return;
    branchId = id;
    await db.setSetting('branch', '$id');
    await cart.loadDraft();
    notifyListeners();
    await loadMenu();
    await shift.refresh(silent: true);
  }

  Future<void> loadMenu() async {
    final id = branchId;
    final api = _api;
    if (id == null) return;
    final key = 'menu:$id';
    if (api != null) {
      try {
        final raw = await api.catalogRaw(id);
        if (branchId != id) return;
        products = ApiClient.parseCatalog(raw);
        menuCachedAt = null;
        online = true;
        await db.saveMenu(
          key,
          (raw['products'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>(),
        );
        notifyListeners();
        return;
      } on ApiException catch (error) {
        if (error.isAuth) {
          tell(error.message, isError: true);
          return;
        }
      } on TimeoutException {
        online = false;
      } on SocketException {
        online = false;
      } on HttpException {
        online = false;
      }
    }
    final cached = await db.readMenu(key);
    if (cached != null && branchId == id) {
      products = ApiClient.parseCatalog({'products': cached.products});
      menuCachedAt = cached.cachedAt;
      notifyListeners();
    }
  }

  Future<void> refreshPending() async {
    final currentUser = user;
    if (currentUser == null) return;
    pendingCount = await db.pendingCount(currentUser.id);
    notifyListeners();
  }

  Future<void> syncNow() async {
    final engine = _sync;
    if (engine == null) return;
    final report = await engine.syncNow();
    online = engine.online;
    syncError = report.blockedReason;
    pendingCount = report.pending;
    if (report.synced > 0) lastSyncAt = DateTime.now();
    notifyListeners();
    if (report.authFailure) {
      await _forgetSession();
      notifyListeners();
      tell(
        report.blockedReason ?? 'انتهت الجلسة. سجّل الدخول مرة أخرى.',
        isError: true,
      );
    } else if (report.blockedReason != null) {
      tell(report.blockedReason!, isError: true);
    }
  }

  Future<void> refreshAll() async {
    await loadMenu();
    await shift.refresh(silent: true);
    await syncNow();
  }

  Future<void> checkForUpdate() async {
    final api = _api;
    if (api == null) return;
    final release = await api.appLatest();
    if (release == null || release['available'] != true) return;
    final latest = (release['version'] ?? '').toString();
    if (latest.isEmpty || !_isNewer(latest, appVersion)) return;
    updateVersion = latest;
    updateUrl = release['url']?.toString();
    notifyListeners();
  }

  static bool _isNewer(String candidate, String current) {
    List<int> parts(String value) => value
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
    final left = parts(candidate);
    final right = parts(current);
    for (var index = 0; index < left.length || index < right.length; index++) {
      final a = index < left.length ? left[index] : 0;
      final b = index < right.length ? right[index] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _sync?.stop();
    _api?.close();
    cart.dispose();
    shift.dispose();
    printer.dispose();
    super.dispose();
  }
}
