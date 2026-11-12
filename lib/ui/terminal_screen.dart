import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/cart_state.dart';
import 'dialogs/expense_dialog.dart';
import 'dialogs/history_dialog.dart';
import 'dialogs/order_dialog.dart';
import 'dialogs/shift_dialog.dart';
import 'dialogs/shift_entry_dialogs.dart';
import 'printer_settings_screen.dart';
import 'theme.dart';
import 'widgets/cart_panel.dart';
import 'widgets/common.dart';
import 'widgets/menu_panel.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _printKitchen() {
    final app = context.read<AppState>();
    final cart = context.read<CartState>();
    if (cart.isEmpty || app.user == null || app.branch == null) return;
    app.printer.printTicket(cart.buildTicket(), kitchen: true, force: true);
  }

  void _openPrinters() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrinterSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyF,
        ): () =>
            _searchFocus.requestFocus(),
        LogicalKeySet(LogicalKeyboardKey.f2): () => showOrderDialog(context),
        LogicalKeySet(LogicalKeyboardKey.f3): _printKitchen,
        LogicalKeySet(LogicalKeyboardKey.f4): () => showExpenseDialog(context),
        LogicalKeySet(LogicalKeyboardKey.f6): () => showAdvanceDialog(context),
        LogicalKeySet(LogicalKeyboardKey.f7): () => showSupplierDialog(context),
        LogicalKeySet(LogicalKeyboardKey.f8): app.refreshAll,
        LogicalKeySet(LogicalKeyboardKey.f9): () => showHistoryDialog(context),
        LogicalKeySet(LogicalKeyboardKey.f10): _openPrinters,
        LogicalKeySet(LogicalKeyboardKey.f12): app.printer.openDrawer,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              const _TopBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: MenuPanel(searchFocus: _searchFocus)),
                    const SizedBox(width: 400, child: CartPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final shift = app.shift;
    return Container(
      color: PosColors.brandDark,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              const Text(
                'الرشيدي',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 16),
              _BranchControl(app: app),
              const SizedBox(width: 12),
              Text(
                'اليوم التشغيلي ${shift.operationalDate}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              if (app.updateVersion != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    avatar: const Icon(
                      Icons.system_update_alt,
                      size: 15,
                      color: PosColors.warning,
                    ),
                    label: Text(
                      'تحديث ${app.updateVersion}',
                      style: const TextStyle(
                        color: PosColors.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () => _showUpdate(context, app),
                  ),
                ),
              StatusPill(
                label: app.online ? 'متصل' : 'غير متصل',
                color: app.online ? PosColors.success : PosColors.warning,
                icon: app.online ? Icons.wifi : Icons.wifi_off,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: '${app.pendingCount} معلق',
                color: app.pendingCount == 0
                    ? PosColors.success
                    : PosColors.warning,
                icon: Icons.cloud_upload_outlined,
              ),
              const SizedBox(width: 12),
              Text(
                app.user?.displayName ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _confirmLogout(context, app),
                icon: const Icon(Icons.logout, color: Colors.white70, size: 19),
                tooltip: 'تسجيل الخروج',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BarButton(
                label: 'مصروف',
                icon: Icons.money_off_csred_outlined,
                shortcut: 'F4',
                enabled: !shift.closed,
                onTap: () => showExpenseDialog(context),
              ),
              _BarButton(
                label: 'سلفة موظف',
                icon: Icons.people_outline,
                shortcut: 'F6',
                enabled: !shift.closed,
                onTap: () => showAdvanceDialog(context),
              ),
              _BarButton(
                label: 'سداد مورد',
                icon: Icons.local_shipping_outlined,
                shortcut: 'F7',
                enabled: !shift.closed,
                onTap: () => showSupplierDialog(context),
              ),
              _BarButton(
                label: shift.closed ? 'الوردية مقفلة' : 'تقفيل الوردية',
                icon: shift.closed
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                onTap: () => showShiftDialog(context),
              ),
              _BarButton(
                label: 'الطلبات السابقة',
                icon: Icons.receipt_long_outlined,
                shortcut: 'F9',
                onTap: () => showHistoryDialog(context),
              ),
              _BarButton(
                label: 'الطابعات',
                icon: Icons.print_outlined,
                shortcut: 'F10',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                ),
              ),
              _BarButton(
                label: 'فتح الدرج',
                icon: Icons.point_of_sale,
                shortcut: 'F12',
                onTap: app.printer.openDrawer,
              ),
              const Spacer(),
              _BarButton(
                label: 'مزامنة',
                icon: Icons.sync,
                shortcut: 'F8',
                highlight: true,
                onTap: app.refreshAll,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppState app) async {
    final confirmed = await showPosDialog<bool>(
      context,
      title: 'تسجيل الخروج',
      width: 440,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: PosColors.danger),
          child: const Text('خروج'),
        ),
      ],
      child: Text(
        app.pendingCount > 0
            ? 'يوجد ${app.pendingCount} طلب لم تتم مزامنته. سيبقى محفوظاً على هذا الجهاز ويمكن مزامنته بعد تسجيل الدخول مرة أخرى.'
            : 'سيتم إلغاء رمز هذا الجهاز من النظام. الطلبات المحفوظة تبقى على الجهاز.',
        style: const TextStyle(height: 1.7),
      ),
    );
    if (confirmed == true) await app.logout();
  }

  Future<void> _showUpdate(BuildContext context, AppState app) async {
    await showPosDialog<void>(
      context,
      title: 'تحديث متاح ${app.updateVersion}',
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'نسخة أحدث من كاشير سطح المكتب متاحة على موقع النظام.',
            style: TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          SelectableText(
            app.updateUrl ?? '',
            style: const TextStyle(fontSize: 12, color: PosColors.brand),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: app.updateUrl ?? ''));
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.copy, size: 17),
            label: const Text('نسخ رابط التحميل'),
          ),
        ],
      ),
    );
  }
}

class _BranchControl extends StatelessWidget {
  const _BranchControl({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 230),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: app.canChangeBranch
        ? DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: app.branchId,
              isDense: true,
              dropdownColor: PosColors.brandDark,
              iconEnabledColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
              hint: const Text(
                'اختر فرع الجهاز',
                style: TextStyle(color: Colors.white70),
              ),
              items: [
                for (final branch in app.branches)
                  DropdownMenuItem(
                    value: branch.id,
                    child: Text(branch.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) app.selectBranch(value);
              },
            ),
          )
        : Tooltip(
            message:
                'الفرع محفوظ على هذا الجهاز ولا يغيّره إلا المستخدم الرئيسي',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, color: Colors.white70, size: 15),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    app.branch?.name ?? 'الفرع غير مضبوط',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: app.branch == null
                          ? PosColors.warning
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
  );
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.shortcut,
    this.enabled = true,
    this.highlight = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? shortcut;
  final bool enabled;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Tooltip(
      message: shortcut == null ? label : '$label ($shortcut)',
      child: TextButton.icon(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          backgroundColor: highlight
              ? PosColors.brand
              : Colors.white.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}
