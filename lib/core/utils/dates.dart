import 'package:intl/intl.dart';

DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

/// `yyyy-MM-dd` for Postgres `date` columns.
String? formatSqlDate(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole days from today to [target] (negative when past).
int daysUntil(DateTime target, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  return dateOnly(target).difference(today).inDays;
}

String formatLongDate(DateTime d, String locale) => DateFormat.yMMMMd(locale).format(d);
String formatShortDate(DateTime d, String locale) => DateFormat.MMMd(locale).format(d);
String formatMonthYear(DateTime d, String locale) => DateFormat.yMMMM(locale).format(d);
