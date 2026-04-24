import 'package:intl/intl.dart';

class AppTime {
  const AppTime._();

  static final DateFormat _dateTimeFormatter = DateFormat(
    'yyyy/MM/dd HH:mm',
    'zh_CN',
  );

  static DateTime? parseUtcString(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }
    return parsed.toLocal();
  }

  static DateTime toUtc(DateTime value) {
    return value.isUtc ? value : value.toUtc();
  }

  static String toUtcIsoString(DateTime value) {
    return toUtc(value).toIso8601String();
  }

  static DateTime parseToLocalDateTime(Object? value, {DateTime? fallback}) {
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    return fallback ?? DateTime.now();
  }

  static String formatUtcStringToBeijing(
    String? value, {
    String fallback = '--',
  }) {
    final localTime = parseUtcString(value);
    if (localTime == null) {
      return fallback;
    }
    return _dateTimeFormatter.format(localTime);
  }

  static String formatUtcDateTimeToBeijing(
    DateTime? value, {
    String fallback = '--',
  }) {
    if (value == null) {
      return fallback;
    }
    return _dateTimeFormatter.format(value.toLocal());
  }
}
