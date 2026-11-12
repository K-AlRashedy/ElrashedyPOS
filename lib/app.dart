import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/login_screen.dart';
import 'ui/terminal_screen.dart';
import 'ui/theme.dart';

class PosApp extends StatefulWidget {
  const PosApp({super.key});

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  final Future<AppState> _boot = AppState.create();
  AppState? _app;

  @override
  void dispose() {
    _app?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: posTheme(),
            locale: const Locale('ar'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: _StartupFailure(error: snapshot.error.toString()),
          );
        }
        final app = snapshot.data;
        if (app == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: posTheme(),
            home: const Scaffold(
              backgroundColor: PosColors.brandDark,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale, color: Colors.white, size: 44),
                    SizedBox(height: 16),
                    Text(
                      'الرشيدي',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18),
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        _app = app;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: app),
            ChangeNotifierProvider.value(value: app.cart),
            ChangeNotifierProvider.value(value: app.shift),
            ChangeNotifierProvider.value(value: app.printer),
          ],
          child: _Shell(app: app),
        );
      },
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell({required this.app});

  final AppState app;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _lastToastId = 0;
  final List<Toast> _visibleToasts = [];
  final Map<int, Timer> _toastTimers = {};

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    for (final timer in _toastTimers.values) {
      timer.cancel();
    }
    widget.app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    final toast = widget.app.toast;
    if (toast == null || toast.id == _lastToastId) return;
    _lastToastId = toast.id;
    if (mounted) {
      setState(() => _visibleToasts.insert(0, toast));
    }
    _toastTimers[toast.id] = Timer(
      Duration(seconds: toast.isError ? 5 : 3),
      () {
        _toastTimers.remove(toast.id);
        if (mounted) {
          setState(
            () => _visibleToasts.removeWhere((item) => item.id == toast.id),
          );
        }
      },
    );
  }

  void _dismissToast(int id) {
    _toastTimers.remove(id)?.cancel();
    setState(() {
      _visibleToasts.removeWhere((toast) => toast.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'الرشيدي — كاشير سطح المكتب',
      debugShowCheckedModeBanner: false,
      theme: posTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          Positioned(
            top: 10,
            left: 24,
            right: 24,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final toast in _visibleToasts) ...[
                        TweenAnimationBuilder<double>(
                          key: ValueKey(toast.id),
                          duration: const Duration(milliseconds: 220),
                          tween: Tween(begin: 0, end: 1),
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, -12 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: _ModernAlert(
                            toast: toast,
                            onClose: () => _dismissToast(toast.id),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      home: app.signedIn ? const TerminalScreen() : const LoginScreen(),
    );
  }
}

class _ModernAlert extends StatelessWidget {
  const _ModernAlert({required this.toast, required this.onClose});

  final Toast toast;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = toast.isError ? PosColors.danger : PosColors.success;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: PosColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F172A),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                toast.isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toast.isError ? 'تنبيه' : 'تم',
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    toast.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PosColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 18, color: PosColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartupFailure extends StatelessWidget {
  const _StartupFailure({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error_outline, color: PosColors.danger),
                    SizedBox(width: 10),
                    Text(
                      'تعذر بدء الكاشير',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'لم يتم فتح قاعدة البيانات المحلية. أغلق أي نسخة أخرى من الكاشير ثم شغّل التطبيق مرة أخرى.',
                  style: TextStyle(height: 1.7),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  error,
                  style: const TextStyle(fontSize: 11, color: PosColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
