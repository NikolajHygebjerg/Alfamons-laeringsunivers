/// Logik for hvornår en `recurring_tasks`-række skal give opgaver på en given dato.
class RecurringTaskSchedule {
  RecurringTaskSchedule._();

  static const String modeEveryDay = 'every_day';
  static const String modeWeekdays = 'weekdays';
  static const String modeSpecificDates = 'specific_dates';

  /// Om denne plan skal materialiseres på [date] (kun dato-delen bruges).
  static bool appliesToDate(Map<String, dynamic> row, DateTime date) {
    final mode = row['schedule_mode'] as String? ?? modeEveryDay;

    if (mode == modeEveryDay) return true;

    if (mode == modeWeekdays) {
      final wd = date.weekday; // 1 = mandag … 7 = søndag
      final list = row['weekdays'];
      if (list == null || list is! List || list.isEmpty) {
        // Ældre rækker uden data: opfør som hver dag
        return true;
      }
      final days = list.map((e) => (e as num).toInt()).toSet();
      return days.contains(wd);
    }

    if (mode == modeSpecificDates) {
      final key = _dateKey(date);
      final raw = row['specific_dates'];
      if (raw == null || raw is! List || raw.isEmpty) return false;
      for (final e in raw) {
        if (_normalizeDateString(e) == key) return true;
      }
      return false;
    }

    return true;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _normalizeDateString(Object e) {
    final s = e.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  /// Kort tekst til undertitel i admin.
  static String summary(Map<String, dynamic> row) {
    final mode = row['schedule_mode'] as String? ?? modeEveryDay;
    if (mode == modeEveryDay) return 'Hver dag';

    if (mode == modeWeekdays) {
      const names = ['', 'Man', 'Tir', 'Ons', 'Tor', 'Fre', 'Lør', 'Søn'];
      final list = row['weekdays'];
      if (list == null || list is! List || list.isEmpty) return 'Hver dag';
      final nums = list.map((e) => (e as num).toInt()).toList()..sort();
      return nums.map((n) => names[n.clamp(1, 7)]).join(', ');
    }

    if (mode == modeSpecificDates) {
      final raw = row['specific_dates'];
      if (raw == null || raw is! List) return 'Bestemte datoer';
      final n = raw.length;
      if (n == 0) return 'Ingen datoer valgt';
      if (n <= 3) {
        return raw.map((e) => _normalizeDateString(e)).join(', ');
      }
      return '$n valgte datoer';
    }

    return '';
  }
}
