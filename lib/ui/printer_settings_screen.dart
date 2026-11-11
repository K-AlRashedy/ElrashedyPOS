import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/settings.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets/common.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late final PrinterSettings _draft;
  late final TextEditingController _header;
  late final TextEditingController _footer;
  List<String> _printers = [];
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().printer.settings;
    _draft = PrinterSettings.fromJson(settings.toJson());
    _header = TextEditingController(text: _draft.receiptHeader);
    _footer = TextEditingController(text: _draft.receiptFooter);
    _loadPrinters();
  }

  @override
  void dispose() {
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    final printers = await context.read<AppState>().printer.listPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _loadingPrinters = false;
    });
  }

  Future<void> _save() async {
    _draft.receiptHeader = _header.text.trim();
    _draft.receiptFooter = _footer.text.trim();
    await context.read<AppState>().printer.save(_draft);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final printer = context.watch<AppState>().printer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الطابعات'),
        actions: [
          TextButton.icon(
            onPressed: printer.busy ? null : () => printer.openDrawer(),
            icon: const Icon(Icons.point_of_sale, color: Colors.white, size: 18),
            label: const Text('فتح الدرج', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PosColors.brand.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosColors.brand.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.translate, color: PosColors.brand, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تُرسم الإيصالات بمحرك نصوص Flutter ثم تُرسل كصورة نقطية، لذا تظهر العربية بشكل صحيح على أي طابعة حرارية حتى لو لم تدعم كود الصفحة العربية. الوضع الشبكي يرسل ESC/POS مباشرة إلى منفذ 9100، ووضع USB يرسل البيانات الخام إلى طابعة ويندوز بدون نافذة طباعة.',
                    style: TextStyle(fontSize: 12, height: 1.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrinterCard(
            title: 'طابعة إيصالات العملاء',
            icon: Icons.receipt_long_outlined,
            config: _draft.customer,
            printers: _printers,
            loadingPrinters: _loadingPrinters,
            onRefreshPrinters: _loadPrinters,
            onChanged: () => setState(() {}),
            onTest: () => printer.testPrint(_draft.customer),
            busy: printer.busy,
          ),
          const SizedBox(height: 14),
          _PrinterCard(
            title: 'طابعة المطبخ',
            icon: Icons.soup_kitchen_outlined,
            config: _draft.kitchen,
            printers: _printers,
            loadingPrinters: _loadingPrinters,
            onRefreshPrinters: _loadPrinters,
            onChanged: () => setState(() {}),
            onTest: () => printer.testPrint(_draft.kitchen),
            busy: printer.busy,
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('الطباعة التلقائية ونص الإيصال',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _draft.autoPrintCustomer,
                    onChanged: (value) => setState(() => _draft.autoPrintCustomer = value),
                    title: const Text('طباعة إيصال العميل تلقائياً بعد كل بيع', style: TextStyle(fontSize: 13)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _draft.autoPrintKitchen,
                    onChanged: (value) => setState(() => _draft.autoPrintKitchen = value),
                    title: const Text('طباعة شيك المطبخ تلقائياً بعد كل بيع', style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  const FieldLabel('ترويسة الإيصال'),
                  TextField(controller: _header, decoration: const InputDecoration(hintText: 'الرشيدي')),
                  const SizedBox(height: 12),
                  const FieldLabel('تذييل الإيصال'),
                  TextField(controller: _footer, decoration: const InputDecoration(hintText: 'شكراً لزيارتكم')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: PosColors.card,
          border: Border(top: BorderSide(color: PosColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: printer.busy ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الإعدادات'),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ],
        ),
      ),
    );
  }
}

class _PrinterCard extends StatefulWidget {
  const _PrinterCard({
    required this.title,
    required this.icon,
    required this.config,
    required this.printers,
    required this.loadingPrinters,
    required this.onRefreshPrinters,
    required this.onChanged,
    required this.onTest,
    required this.busy,
  });

  final String title;
  final IconData icon;
  final PrinterConfig config;
  final List<String> printers;
  final bool loadingPrinters;
  final VoidCallback onRefreshPrinters;
  final VoidCallback onChanged;
  final VoidCallback onTest;
  final bool busy;

  @override
  State<_PrinterCard> createState() => _PrinterCardState();
}

class _PrinterCardState extends State<_PrinterCard> {
  late final TextEditingController _host = TextEditingController(text: widget.config.host);
  late final TextEditingController _port = TextEditingController(text: '${widget.config.port}');

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final printers = widget.printers;
    final loadingPrinters = widget.loadingPrinters;
    final busy = widget.busy;
    final onChanged = widget.onChanged;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: PosColors.brand, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                Switch(value: config.enabled, onChanged: (value) {
                  config.enabled = value;
                  onChanged();
                }),
              ],
            ),
            const SizedBox(height: 8),
            const FieldLabel('طريقة التوصيل'),
            SegmentedButton<PrinterTransport>(
              segments: const [
                ButtonSegment(value: PrinterTransport.network, label: Text('شبكة TCP'), icon: Icon(Icons.lan_outlined)),
                ButtonSegment(value: PrinterTransport.usb, label: Text('USB ويندوز'), icon: Icon(Icons.usb)),
                ButtonSegment(value: PrinterTransport.pdf, label: Text('PDF / A4'), icon: Icon(Icons.picture_as_pdf_outlined)),
              ],
              selected: {config.transport},
              onSelectionChanged: (selection) {
                config.transport = selection.first;
                onChanged();
              },
            ),
            const SizedBox(height: 14),
            if (config.transport == PrinterTransport.network) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('عنوان الطابعة (IP)'),
                        TextField(
                          controller: _host,
                          decoration: const InputDecoration(hintText: '192.168.1.50'),
                          onChanged: (value) {
                            config.host = value.trim();
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FieldLabel('المنفذ'),
                        TextField(
                          controller: _port,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '9100'),
                          onChanged: (value) {
                            config.port = int.tryParse(value.trim()) ?? 9100;
                            onChanged();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: SearchPickerField(
                      label: config.transport == PrinterTransport.usb ? 'طابعة ويندوز (RAW)' : 'طابعة ويندوز (PDF)',
                      value: config.printerName.isEmpty ? null : config.printerName,
                      placeholder: loadingPrinters ? 'جارٍ قراءة الطابعات...' : 'اختر الطابعة...',
                      options: [for (final name in printers) PickerOption(name, name)],
                      onChanged: (value) {
                        config.printerName = value;
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: loadingPrinters ? null : widget.onRefreshPrinters,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'قراءة الطابعات المثبتة',
                  ),
                ],
              ),
              if (printers.isEmpty && !loadingPrinters)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('لم يتم العثور على طابعات مثبتة. ثبّت تعريف الطابعة في ويندوز ثم اضغط تحديث.',
                      style: TextStyle(color: PosColors.muted, fontSize: 11.5)),
                ),
            ],
            const SizedBox(height: 14),
            const FieldLabel('عرض الورق'),
            SegmentedButton<PaperWidth>(
              segments: [
                for (final width in PaperWidth.values)
                  ButtonSegment(value: width, label: Text('${width.label} (${width.dots} نقطة)')),
              ],
              selected: {config.width},
              onSelectionChanged: (selection) {
                config.width = selection.first;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: config.kickDrawer,
              onChanged: config.transport == PrinterTransport.pdf
                  ? null
                  : (value) {
                      config.kickDrawer = value;
                      onChanged();
                    },
              title: const Text('فتح درج النقود مع كل إيصال', style: TextStyle(fontSize: 13)),
              subtitle: config.transport == PrinterTransport.pdf
                  ? const Text('غير متاح في وضع PDF', style: TextStyle(fontSize: 11))
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || !config.isConfigured ? null : widget.onTest,
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('طباعة تجريبية'),
                  ),
                ),
                const SizedBox(width: 10),
                StatusPill(
                  label: config.isConfigured ? config.describe : 'غير مكتملة',
                  color: config.isConfigured ? PosColors.success : PosColors.muted,
                  icon: config.isConfigured ? Icons.check_circle_outline : Icons.error_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}