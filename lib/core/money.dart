/// Money helpers that mirror the browser terminal's integer-cent arithmetic.
library;

int toCents(Object value) {
  final number = value is num ? value.toDouble() : double.parse(value.toString());
  return (number * 100).round();
}

String formatCents(int cents) => (cents / 100).toStringAsFixed(2);

int lineTotalCents(Object price, Object qty) {
  final quantity = qty is num ? qty.toDouble() : double.parse(qty.toString());
  return (toCents(price) * quantity).round();
}

String formatQty(num qty) {
  final rounded = (qty * 1000).round() / 1000;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

num parseQty(Object value) {
  final quantity = value is num ? value : num.parse(value.toString());
  return (quantity * 1000).round() / 1000;
}

bool isValidQty(Object value) {
  final num quantity;
  try {
    quantity = value is num ? value : num.parse(value.toString());
  } catch (_) {
    return false;
  }
  if (!quantity.isFinite || quantity <= 0 || quantity > 1000) return false;
  return (quantity * 1000 - (quantity * 1000).round()).abs() < 0.00001;
}