/// The operational day rolls over at 09:30 local time, matching the server.
library;

DateTime operationalDateOf(DateTime moment) {
  final local = moment.toLocal();
  final beforeCutoff = local.hour < 9 || (local.hour == 9 && local.minute < 30);
  final day = beforeCutoff ? local.subtract(const Duration(days: 1)) : local;
  return DateTime(day.year, day.month, day.day);
}

String operationalDateIso(DateTime moment) {
  final date = operationalDateOf(moment);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}