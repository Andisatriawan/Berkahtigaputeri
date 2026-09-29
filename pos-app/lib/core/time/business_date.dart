// lib/core/time/business_date.dart

/// Business-date helper for Indonesian WIB operations.
///
/// Asia/Jakarta does not observe daylight saving time, so WIB is always UTC+7.
class BusinessDate {
  BusinessDate._();

  static const String timezoneId = 'Asia/Jakarta';
  static const Duration wibOffset = Duration(hours: 7);

  static String fromUtc(DateTime occurredAtUtc) {
    final local = occurredAtUtc.toUtc().add(wibOffset);
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
