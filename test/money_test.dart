import 'package:elrashedy_pos/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('integer-cent arithmetic matches the browser terminal', () {
    test('toCents rounds half up like Math.round', () {
      expect(toCents('12.34'), 1234);
      expect(toCents('12.345'), 1235);
      expect(toCents(0), 0);
      expect(toCents('10'), 1000);
    });

    test('line total multiplies cents by quantity then rounds', () {
      expect(lineTotalCents('10.00', '1.5'), 1500);
      expect(lineTotalCents('0.10', '3'), 30);
      expect(lineTotalCents('33.33', '0.003'), 10);
      expect(lineTotalCents('7.50', '2'), 1500);
    });

    test('formatCents always prints two decimals', () {
      expect(formatCents(0), '0.00');
      expect(formatCents(5), '0.05');
      expect(formatCents(16000), '160.00');
    });
  });

  group('quantity rules mirror pos_sync', () {
    test('accepts up to three decimals between 0.001 and 1000', () {
      expect(isValidQty('1'), isTrue);
      expect(isValidQty('0.001'), isTrue);
      expect(isValidQty('1000'), isTrue);
      expect(isValidQty('2.5'), isTrue);
    });

    test('rejects zero, negatives, overflow and extra precision', () {
      expect(isValidQty('0'), isFalse);
      expect(isValidQty('-1'), isFalse);
      expect(isValidQty('1000.001'), isFalse);
      expect(isValidQty('1.0005'), isFalse);
      expect(isValidQty('abc'), isFalse);
      expect(isValidQty(''), isFalse);
    });

    test('formatQty drops trailing zeros without losing precision', () {
      expect(formatQty(1), '1');
      expect(formatQty(1.5), '1.5');
      expect(formatQty(0.001), '0.001');
      expect(formatQty(1.2345), '1.235');
      expect(formatQty(1000), '1000');
    });

    test('parseQty rounds to three decimals', () {
      expect(parseQty('1.23456'), 1.235);
      expect(parseQty(2), 2);
    });
  });
}