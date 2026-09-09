import 'dart:convert';
import 'dart:math' as math;

import '../models/commitment.dart';
import '../services/notification_service.dart';
import '../utils/date_formatter.dart';

/// Single source of truth for how a commitment maps to OS alarms.
///
/// Used by BOTH the main app and the background WorkManager watchdog, so the
/// exact alarm ids, payloads and reminder slots are always identical — two
/// re-schedules of the same commitment simply overwrite the same OS alarms
/// (idempotent) instead of stacking duplicates.
///
/// Ids keep a wide gap between the main alarm and its advance reminder:
///   main:                   parsed-int % 1e9            (0 .. 999.999.999)
///   advance reminder:       main + 1e9                  (1e9 .. 2e9 - 1)
int notificationIdFor(String id) =>
    (int.tryParse(id) ?? id.hashCode).abs() % 1000000000;

int reminderNotificationIdFor(String id) => notificationIdFor(id) + 1000000000;

/// True when the commitment keeps recurring (never "completes" permanently).
bool isRecurring(Commitment c) {
  final rec = c.recurrence ?? 'Único';
  return rec != 'Único' || (c.recurrenceDaysOfWeek != null && c.recurrenceDaysOfWeek!.isNotEmpty);
}

/// The next actual fire `DateTime` (with time-of-day) for [c], strictly after
/// [now], or `null` when nothing is left to ring (one-shot in the past or expired).
DateTime? nextFireDateTime(Commitment c, DateTime now) {
  final rec = c.recurrence ?? 'Único';
  final base = DateFormatter.parseDate(c.date);
  final parts = c.time.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  DateTime cand = DateTime(base.year, base.month, base.day, hour, minute);

  // Se tiver data final de recorrência ("por 1 semana", "durante 1 mês"), valida
  DateTime? endDate;
  if (c.recurrenceEndDate != null) {
    endDate = DateTime.tryParse(c.recurrenceEndDate!);
  }

  // 1. Caso de dias específicos da semana (ex: [1,2,3,4,5] para Seg-Sex, [1,4] para Seg e Qui)
  if (c.recurrenceDaysOfWeek != null && c.recurrenceDaysOfWeek!.isNotEmpty) {
    final days = c.recurrenceDaysOfWeek!;
    for (var i = 0; i < 370; i++) {
      final testCand = DateTime(now.year, now.month, now.day, hour, minute).add(Duration(days: i));
      if (testCand.isBefore(cand)) continue; // Não dispara antes da data de início

      if (endDate != null) {
        final candOnly = DateTime(testCand.year, testCand.month, testCand.day);
        final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
        if (candOnly.isAfter(endOnly)) return null;
      }

      if (days.contains(testCand.weekday) && testCand.isAfter(now)) {
        return testCand;
      }
    }
    return null;
  }

  // 2. Compromisso único
  if (rec == 'Único') {
    return cand.isAfter(now) ? cand : null;
  }

  // 3. Outras recorrências
  final dom = c.recurrenceDayOfMonth ?? base.day;
  for (var i = 0; i < 370; i++) {
    if (endDate != null) {
      final candOnly = DateTime(cand.year, cand.month, cand.day);
      final endOnly = DateTime(endDate.year, endDate.month, endDate.day);
      if (candOnly.isAfter(endOnly)) return null;
    }

    if (cand.isAfter(now)) return cand;
    switch (rec) {
      case 'Todos os dias':
        cand = cand.add(const Duration(days: 1));
        break;
      case 'Semanal':
        cand = cand.add(const Duration(days: 7));
        break;
      case 'A cada 2 dias':
        cand = cand.add(const Duration(days: 2));
        break;
      case 'A cada 3 dias':
        cand = cand.add(const Duration(days: 3));
        break;
      case 'Mensal':
        cand = DateTime(cand.year, cand.month + 1,
            math.min(dom, _daysInMonth(cand.year, cand.month + 1)), hour, minute);
        break;
      case 'De hora em hora':
        cand = cand.add(const Duration(hours: 1));
        break;
      case 'A cada 2 horas':
        cand = cand.add(const Duration(hours: 2));
        break;
      case 'A cada 3 horas':
        cand = cand.add(const Duration(hours: 3));
        break;
      default:
        return null;
    }
  }
  return null;
}

int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

/// Schedules (or re-schedules) the main alarm plus the optional advance
/// reminder ("me lembre N dias antes") for a single commitment.
Future<void> scheduleCommitmentAlarms(
    NotificationService ns, Commitment c) async {
  final mainId = notificationIdFor(c.id);

  // Re-scheduling must first drop a previously pending reminder slot.
  await ns.cancel(reminderNotificationIdFor(c.id));

  final now = DateTime.now();
  final next = nextFireDateTime(c, now);

  if (next == null) {
    // Nothing left to ring: ensure no stray alarm is left behind.
    await ns.cancel(mainId);
    return;
  }

  await ns.scheduleAlarm(
    id: mainId,
    title: c.title,
    body: '✋ Hora do compromisso: ${c.title} às ${c.time}. Diga "ok" ou "já ouvi".',
    scheduledTime: next,
    recurrence: null, // cadeia one-shot: a próxima ocorrência é re-tremada
    payload: jsonEncode({
      'id': c.id,
      'title': c.title,
      'time': c.time,
      'recurrence': c.recurrence,
      'recurrenceDayOfMonth': c.recurrenceDayOfMonth,
      'recurrenceDaysOfWeek': c.recurrenceDaysOfWeek,
      'recurrenceEndDate': c.recurrenceEndDate,
    }),
  );

  // Advance reminder: "me lembre 3 dias antes" -> rings N days earlier at the
  // same wall-clock time, announcing the commitment is coming.
  final daysBefore = c.reminderDaysBefore;
  if (daysBefore != null && c.recurrence == null && c.recurrenceDaysOfWeek == null) {
    final reminderAt = next.subtract(Duration(days: daysBefore));
    if (reminderAt.isAfter(now)) {
      await ns.scheduleAlarm(
        id: reminderNotificationIdFor(c.id),
        title: c.title,
        body: 'Lembrete: ${c.title} é daqui a $daysBefore dias.',
        scheduledTime: reminderAt,
        recurrence: null,
        payload: jsonEncode({
          'id': c.id,
          'title': c.title,
          'time': c.time,
          'daysBefore': daysBefore,
          'isReminder': true,
        }),
      );
    }
  }
}
