import '../models/commitment.dart';

/// Centralises "does this commitment fire today / at this time?" logic so the
/// alarm checks and the calendar/list/briefing views all agree.
class ScheduleMatcher {
  /// The next day (YYYY-MM-DD) on or after [refDay] when this commitment is
  /// scheduled to occur, for the given recurrence type.
  static String? nextOccurrenceDate(Commitment c, DateTime refDay) {
    final rec = c.recurrence ?? 'Único';
    final date = DateTime.parse(c.date);

    // Se tiver end date e refDay já passou do end date, nada a agendar
    if (c.recurrenceEndDate != null) {
      final end = DateTime.parse(c.recurrenceEndDate!);
      final refOnly = DateTime(refDay.year, refDay.month, refDay.day);
      final endOnly = DateTime(end.year, end.month, end.day);
      if (refOnly.isAfter(endOnly)) return null;
    }

    // Dias específicos da semana (ex: Segunda a Sexta [1,2,3,4,5], Segunda e Quinta [1,4])
    if (c.recurrenceDaysOfWeek != null && c.recurrenceDaysOfWeek!.isNotEmpty) {
      final days = c.recurrenceDaysOfWeek!;
      for (int i = 0; i < 14; i++) {
        final cand = refDay.add(Duration(days: i));
        if (days.contains(cand.weekday)) {
          if (c.recurrenceEndDate != null) {
            final end = DateTime.parse(c.recurrenceEndDate!);
            if (cand.isAfter(end)) return null;
          }
          return _fmt(cand);
        }
      }
      return null;
    }

    switch (rec) {
      case 'Semanal':
        // Same weekday every week.
        final diff = (date.weekday - refDay.weekday) % 7;
        final d = refDay.add(Duration(days: diff));
        return _fmt(d);
      case 'Mensal':
        // Same day of month every month.
        final dom = c.recurrenceDayOfMonth ?? date.day;
        final daysIn = _daysInMonth(refDay.year, refDay.month);
        final day = dom > daysIn ? daysIn : dom;
        final d = DateTime(refDay.year, refDay.month, day);
        return _fmt(d);
      case 'A cada 2 dias':
        final diff = refDay.difference(date).inDays;
        if (diff < 0) return _fmt(date);
        if (diff % 2 == 0) return _fmt(refDay);
        return _fmt(refDay.add(const Duration(days: 1)));
      case 'A cada 3 dias':
        final diff = refDay.difference(date).inDays;
        if (diff < 0) return _fmt(date);
        if (diff % 3 == 0) return _fmt(refDay);
        return _fmt(refDay.add(Duration(days: 3 - (diff % 3))));
      case 'Todos os dias':
      case 'De hora em hora':
      case 'A cada 2 horas':
      case 'A cada 3 horas':
        return _fmt(refDay);
      default:
        return c.date;
    }
  }

  /// Whether this commitment is scheduled to occur on [day] (YYYY-MM-DD).
  static bool occursOn(Commitment c, String day) {
    final parsed = DateTime.tryParse(day);
    if (parsed == null) return false;

    // Respeita data limite de término se houver
    if (c.recurrenceEndDate != null) {
      final end = DateTime.tryParse(c.recurrenceEndDate!);
      if (end != null) {
        final parsedOnly = DateTime(parsed.year, parsed.month, parsed.day);
        final endOnly = DateTime(end.year, end.month, end.day);
        if (parsedOnly.isAfter(endOnly)) return false;
      }
    }

    // Dias específicos da semana (ex: [1,2,3,4,5] para Seg-Sex, [1,4] para Seg e Qui)
    if (c.recurrenceDaysOfWeek != null && c.recurrenceDaysOfWeek!.isNotEmpty) {
      final startDate = DateTime.tryParse(c.date);
      if (startDate != null) {
        final parsedOnly = DateTime(parsed.year, parsed.month, parsed.day);
        final startOnly = DateTime(startDate.year, startDate.month, startDate.day);
        if (parsedOnly.isBefore(startOnly)) return false;
      }
      return c.recurrenceDaysOfWeek!.contains(parsed.weekday);
    }

    final rec = c.recurrence ?? 'Único';
    switch (rec) {
      case 'Mensal':
        final dom = c.recurrenceDayOfMonth ?? DateTime.parse(c.date).day;
        final daysIn = _daysInMonth(parsed.year, parsed.month);
        return parsed.day == (dom > daysIn ? daysIn : dom);
      case 'Semanal':
        return parsed.weekday == DateTime.parse(c.date).weekday;
      case 'A cada 2 dias':
        final diff = parsed.difference(DateTime.parse(c.date)).inDays;
        return diff >= 0 && diff % 2 == 0;
      case 'A cada 3 dias':
        final diff = parsed.difference(DateTime.parse(c.date)).inDays;
        return diff >= 0 && diff % 3 == 0;
      case 'Todos os dias':
      case 'De hora em hora':
      case 'A cada 2 horas':
      case 'A cada 3 horas':
        return true;
      default:
        return c.date == day;
    }
  }

  /// Matches the HH:MM wall-clock time (used by the in-app timer check).
  static bool matchesTime(Commitment c, DateTime now) {
    final parts = c.time.split(':');
    return int.tryParse(parts[0]) == now.hour &&
        int.tryParse(parts[1]) == now.minute;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;
}
