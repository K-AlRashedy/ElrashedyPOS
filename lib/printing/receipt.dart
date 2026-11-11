import '../core/money.dart';
import '../core/ticket.dart';

enum ReceiptAlign { right, center, left }

enum ReceiptSize {
  small(20),
  normal(24),
  large(30),
  huge(40);

  const ReceiptSize(this.dots);
  final int dots;
}

class ReceiptElement {
  const ReceiptElement.text(
    this.text, {
    this.align = ReceiptAlign.right,
    this.size = ReceiptSize.normal,
    this.bold = false,
  })  : divider = false,
        dots = 0;

  const ReceiptElement.divider()
      : text = '',
        align = ReceiptAlign.center,
        size = ReceiptSize.normal,
        bold = false,
        divider = true,
        dots = 0;

  const ReceiptElement.gap([this.dots = 8])
      : text = '',
        align = ReceiptAlign.center,
        size = ReceiptSize.normal,
        bold = false,
        divider = false;

  final String text;
  final ReceiptAlign align;
  final ReceiptSize size;
  final bool bold;
  final bool divider;
  final int dots;

  bool get isGap => text.isEmpty && !divider;
}

const Map<String, String> orderTypeLabels = {
  'dine_in': 'صالة',
  'takeaway': 'تيك أواي',
  'delivery': 'دليفري',
};

const Map<String, String> paymentLabels = {
  'cash': 'نقدي',
  'visa': 'Visa',
  'instapay': 'InstaPay',
  'wallet': 'Vodafone Cash',
};

String shortTicketId(String clientId) => clientId.split('-').first.toUpperCase();

String formatTicketTime(DateTime moment) {
  final local = moment.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

List<ReceiptElement> buildCustomerReceipt(
  Ticket ticket, {
  required String header,
  required String footer,
}) {
  final elements = <ReceiptElement>[
    ReceiptElement.text(header, align: ReceiptAlign.center, size: ReceiptSize.huge, bold: true),
    ReceiptElement.text(ticket.branchName, align: ReceiptAlign.center, size: ReceiptSize.large),
    const ReceiptElement.divider(),
    ReceiptElement.text(
      [
        orderTypeLabels[ticket.orderType] ?? ticket.orderType,
        if (ticket.table.isNotEmpty) 'طاولة ${ticket.table}',
      ].join(' · '),
      bold: true,
    ),
    ReceiptElement.text('رقم الطلب: ${shortTicketId(ticket.clientId)}', size: ReceiptSize.small),
    ReceiptElement.text(formatTicketTime(ticket.placedAt), size: ReceiptSize.small),
  ];

  if (ticket.customer.isNotEmpty || ticket.phone.isNotEmpty) {
    elements.add(ReceiptElement.text(
      [ticket.customer, ticket.phone].where((part) => part.isNotEmpty).join(' · '),
      size: ReceiptSize.small,
    ));
  }
  if (ticket.address.isNotEmpty) {
    elements.add(ReceiptElement.text(ticket.address, size: ReceiptSize.small));
  }

  elements.add(const ReceiptElement.divider());
  for (final line in ticket.lines) {
    elements.add(ReceiptElement.text('${line.qty} × ${line.name}', bold: true));
    elements.add(ReceiptElement.text(
      '${line.price} × ${line.qty} = ${formatCents(line.subtotalCents)} ج.م',
      align: ReceiptAlign.left,
      size: ReceiptSize.small,
    ));
    if (line.note.isNotEmpty) {
      elements.add(ReceiptElement.text('ملاحظة: ${line.note}', size: ReceiptSize.small));
    }
  }
  elements.add(const ReceiptElement.divider());

  elements.add(ReceiptElement.text('الإجمالي: ${ticket.total} ج.م', size: ReceiptSize.large, bold: true));
  elements.add(ReceiptElement.text('الدفع: ${paymentLabels[ticket.payment] ?? ticket.payment}'));
  if (ticket.payment == 'cash') {
    elements.add(ReceiptElement.text('المدفوع: ${ticket.tendered} ج.م', size: ReceiptSize.small));
    if (ticket.changeCents > 0) {
      elements.add(ReceiptElement.text('المتبقي للعميل: ${ticket.change} ج.م', size: ReceiptSize.small, bold: true));
    }
  }
  elements.add(ReceiptElement.text(
    ticket.synced && ticket.serverId != null
        ? 'رقم البيع: ${ticket.serverId}'
        : 'محفوظ محلياً — لم تتم المزامنة',
    size: ReceiptSize.small,
  ));
  if (footer.isNotEmpty) {
    elements
      ..add(const ReceiptElement.gap())
      ..add(ReceiptElement.text(footer, align: ReceiptAlign.center, size: ReceiptSize.small));
  }
  return elements;
}

List<ReceiptElement> buildKitchenReceipt(Ticket ticket) {
  final elements = <ReceiptElement>[
    const ReceiptElement.text('طلب المطبخ', align: ReceiptAlign.center, size: ReceiptSize.huge, bold: true),
    ReceiptElement.text(ticket.branchName, align: ReceiptAlign.center, size: ReceiptSize.large),
    const ReceiptElement.divider(),
    ReceiptElement.text(
      [
        orderTypeLabels[ticket.orderType] ?? ticket.orderType,
        if (ticket.table.isNotEmpty) 'طاولة ${ticket.table}',
      ].join(' · '),
      size: ReceiptSize.large,
      bold: true,
    ),
    ReceiptElement.text('رقم الطلب: ${shortTicketId(ticket.clientId)}', size: ReceiptSize.small),
    ReceiptElement.text(formatTicketTime(ticket.placedAt), size: ReceiptSize.small),
    const ReceiptElement.divider(),
  ];
  for (final line in ticket.lines) {
    elements.add(ReceiptElement.text('${line.qty} × ${line.name}', size: ReceiptSize.large, bold: true));
    if (line.note.isNotEmpty) {
      elements.add(ReceiptElement.text('** ${line.note}', size: ReceiptSize.normal, bold: true));
    }
  }
  elements.add(const ReceiptElement.divider());
  return elements;
}

List<ReceiptElement> buildTestReceipt(String target) => [
      const ReceiptElement.text('الرشيدي', align: ReceiptAlign.center, size: ReceiptSize.huge, bold: true),
      const ReceiptElement.text('طباعة تجريبية', align: ReceiptAlign.center, size: ReceiptSize.large),
      const ReceiptElement.divider(),
      ReceiptElement.text('الطابعة: $target'),
      ReceiptElement.text(formatTicketTime(DateTime.now()), size: ReceiptSize.small),
      const ReceiptElement.text('اختبار اللغة العربية والأرقام ١٢٣ 123', size: ReceiptSize.small),
      const ReceiptElement.divider(),
      const ReceiptElement.text('إذا ظهر هذا السطر فالطابعة تعمل.', align: ReceiptAlign.center),
    ];