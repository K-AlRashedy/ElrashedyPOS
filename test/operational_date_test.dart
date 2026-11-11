import 'package:elrashedy_pos/core/operational_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the operational day rolls over at 09:30 local time', () {
    expect(operationalDateIso(DateTime(2026, 3, 10, 9, 29)), '2026-03-09');
    expect(operationalDateIso(DateTime(2026, 3, 10, 9, 30)), '2026-03-10');
    expect(operationalDateIso(DateTime(2026, 3, 10, 23, 59)), '2026-03-10');
    expect(operationalDateIso(DateTime(2026, 3, 10, 0, 5)), '2026-03-09');
  });

  test('rollover crosses month and year boundaries', () {
    expect(operationalDateIso(DateTime(2026, 1, 1, 2, 0)), '2025-12-31');
    expect(operationalDateIso(DateTime(2026, 3, 1, 8, 0)), '2026-02-28');
  });
}