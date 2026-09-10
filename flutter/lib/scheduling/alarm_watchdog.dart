import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/commitment.dart';
import 'alarm_scheduler.dart';
import '../services/notification_service.dart';

/// Watchdog que mantém os alarmes vivos em background.
class AlarmWatchdog {
  static const String taskName = 'agenda_amiga_rearm';

  /// Registra a tarefa periódica. Chamar UMA VEZ após NotificationService.init().
  static Future<void> register() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(alarmWatchdogCallbackDispatcher);
      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(minutes: 15),
      );
    } catch (_) {}
  }

  /// Verifica e re-armazena alarmes faltantes.
  ///
  /// Seguro para chamar do background isolate (WorkManager) ou do UI isolate.
  /// Idempotente: não cria duplicatas porque usa os mesmos IDs.
  static Future<void> rearmAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('commitments');
    if (raw == null || raw.isEmpty) return;

    final list = jsonDecode(raw) as List<dynamic>;
    final commitments = list
        .map((e) => Commitment.fromJson(e as Map<String, dynamic>))
        .toList();

    // 1. Obtém todos os alarmes atualmente registrados no `alarm` package.
    List<AlarmSettings> existingAlarms;
    try {
      existingAlarms = await Alarm.getAlarms();
    } catch (_) {
      // Se não conseguir listar, assume que precisa re-agendar tudo.
      existingAlarms = [];
    }
    final existingIds = existingAlarms.map((a) => a.id).toSet();

    // 2. Para cada compromisso não-concluído, verifica se o alarme existe.
    final ns = NotificationService();
    await ns.init();

    for (final c in commitments) {
      if (c.completed) continue;

      final mainId = notificationIdFor(c.id);

      // Se o alarme JÁ existe no `alarm` package, NÃO re-agenda.
      // O Foreground Service já está cuidando dele.
      if (existingIds.contains(mainId)) continue;

      // Se o alarme NÃO existe, re-agenda (foi cancelado pelo OEM ou pelo sistema).
      try {
        await scheduleCommitmentAlarms(ns, c);
      } catch (_) {
        // Um compromisso ruim nunca deve parar toda a verificação.
      }
    }
  }
}

/// Entry point que o WorkManager chama no background isolate.
/// DEVE ser top-level com @pragma('vm:entry-point') (AOT tree-shaking).
@pragma('vm:entry-point')
void alarmWatchdogCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == AlarmWatchdog.taskName) {
      await AlarmWatchdog.rearmAll();
    }
    return true;
  });
}
