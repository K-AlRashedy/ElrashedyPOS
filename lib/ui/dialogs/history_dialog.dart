import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ticket.dart';
import '../../printing/receipt.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showHistoryDialog(BuildContext context) => showPosDialog<void>(
      context,
      title: 'الطلبات السابقة',
      width: 720,
      child: const _HistoryList(),
    );

class _HistoryList extends StatefulWidget {
  const _HistoryList();

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  List<Ticket> _tickets = [];
  bool _loading = true;
  bool _onlyPending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    final user = app.user;
    if (user == null) return;
    final tickets = await app.db.tickets(user.id);
    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _loading = false;
    });
  }

  Future<void> _sync() async {
    final app = context.read<AppState>();
    await app.syncNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final printer = app.printer;
    final visible = _onlyPending ? _tickets.where((ticket) => !ticket.synced).toList() : _tickets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            StatusPill(
              label: '${app.pendingCount} بانتظار المزامنة',
              color: app.pendingCount == 0 ? PosColors.success : PosColors.warning,
              icon: app.pendingCount == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('غير المتزامن فقط'),
              selected: _onlyPending,
              onSelected: (value) => setState(() => _onlyPending = value),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _sync,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('مزامنة الآن'),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 19), tooltip: 'تحديث'),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
        else if (visible.isEmpty)
          const EmptyHint('لا توجد طلبات محفوظة على هذا الجهاز بعد.', icon: Icons.receipt_long_outlined)
        else
          for (final ticket in visible.take(60))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ticket.synced ? PosColors.border : PosColors.warning.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${ticket.branchName} · ${orderTypeLabels[ticket.orderType] ?? ticket.orderType}'
                            '${ticket.table.isEmpty ? '' : ' · طاولة ${ticket.table}'}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        Text('${ticket.total} ج.م',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: PosColors.brand)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(formatTicketTime(ticket.placedAt),
                            style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
                        const SizedBox(width: 8),
                        Text('#${shortTicketId(ticket.clientId)}',
                            style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
                        const Spacer(),
                        StatusPill(
                          label: ticket.synced ? 'تمت المزامنة #${ticket.serverId}' : 'بانتظار المزامنة',
                          color: ticket.synced ? PosColors.success : PosColors.warning,
                        ),
                      ],
                    ),
                    if (ticket.error != null) ...[
                      const SizedBox(height: 6),
                      Text(ticket.error!,
                          style: const TextStyle(color: PosColors.danger, fontSize: 11.5, height: 1.5)),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: printer.busy
                              ? null
                              : () => printer.printTicket(ticket, kitchen: false, force: true),
                          icon: const Icon(Icons.receipt_outlined, size: 16),
                          label: const Text('إيصال للعميل'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: printer.busy
                              ? null
                              : () => printer.printTicket(ticket, kitchen: true, force: true),
                          icon: const Icon(Icons.soup_kitchen_outlined, size: 16),
                          label: const Text('شيك المطبخ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        if (visible.length > 60)
          Text('يتم عرض أحدث 60 طلباً من أصل ${visible.length}.',
              style: const TextStyle(color: PosColors.muted, fontSize: 11.5)),
      ],
    );
  }
}