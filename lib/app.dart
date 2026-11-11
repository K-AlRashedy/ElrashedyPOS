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
                    Text('الرشيدي', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    SizedBox(height: 18),
                    SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
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
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  int _lastToastId = 0;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    super.dispose();
  }

  void _onAppChanged() {
    final toast = widget.app.toast;
    if (toast == null || toast.id == _lastToastId) return;
    _lastToastId = toast.id;
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(toast.text),
        backgroundColor: toast.isError ? PosColors.danger : PosColors.brandDark,
        duration: Duration(seconds: toast.isError ? 6 : 3),
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      title: 'الرشيدي — كاشير سطح المكتب',
      debugShowCheckedModeBanner: false,
      theme: posTheme(),
      scaffoldMessengerKey: _messengerKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: app.signedIn ? const TerminalScreen() : const LoginScreen(),
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
                        Text('تعذر بدء الكاشير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'لم يتم فتح قاعدة البيانات المحلية. أغلق أي نسخة أخرى من الكاشير ثم شغّل التطبيق مرة أخرى.',
                      style: TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(error, style: const TextStyle(fontSize: 11, color: PosColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}