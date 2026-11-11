import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _server;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _device;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _server = TextEditingController(text: settings.serverUrl);
    _username = TextEditingController();
    _password = TextEditingController();
    _device = TextEditingController(text: settings.deviceName);
  }

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _device.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState app) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    app.settings.deviceName = _device.text.trim().isEmpty ? app.settings.deviceName : _device.text.trim();
    await app.saveSettings();
    await app.login(
      serverUrl: _server.text,
      username: _username.text.trim(),
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: PosColors.brandDark,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PosColors.brand,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.point_of_sale, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('الرشيدي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                Text('كاشير سطح المكتب', style: TextStyle(color: PosColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FieldLabel('عنوان النظام'),
                      TextFormField(
                        controller: _server,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'https://your-app.herokuapp.com',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty ? 'أدخل عنوان النظام كما تفتحه في المتصفح.' : null,
                      ),
                      const SizedBox(height: 14),
                      FieldLabel('اسم المستخدم'),
                      TextFormField(
                        controller: _username,
                        autofocus: true,
                        decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline)),
                        validator: (value) => (value ?? '').trim().isEmpty ? 'أدخل اسم المستخدم.' : null,
                      ),
                      const SizedBox(height: 14),
                      FieldLabel('كلمة المرور'),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        onFieldSubmitted: (_) => _submit(app),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (value) => (value ?? '').isEmpty ? 'أدخل كلمة المرور.' : null,
                      ),
                      const SizedBox(height: 14),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        title: const Text('اسم هذا الجهاز', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        children: [
                          TextField(
                            controller: _device,
                            decoration: const InputDecoration(hintText: 'كاشير الفرع الرئيسي'),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يظهر اسم الجهاز في سجل أجهزة الكاشير لدى مدير النظام ليسهل إلغاء جهاز مفقود.',
                            style: TextStyle(color: PosColors.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: app.busy ? null : () => _submit(app),
                        icon: app.busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login),
                        label: Text(app.busy ? 'جارٍ تسجيل الدخول...' : 'دخول الكاشير'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'يحتاج الحساب إلى صلاحية تأكيد أوامر البيع. يعمل الكاشير بدون إنترنت ويحفظ الطلبات على الجهاز حتى عودة الاتصال.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: PosColors.muted, fontSize: 11.5, height: 1.6),
                      ),
                      if (app.appVersion.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('الإصدار ${app.appVersion}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: PosColors.muted, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}