import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../models/commitment.dart';
import 'alarm_scheduler.dart';
import '../services/notification_service.dart';

/// Watchdog que mantém os alarmes vivos em background.
///
/// PROBLEMA QUE RESOLVE:
/// Android (e OEMs como Realme/Xiaomi/Samsung) periodicamente cancela alarmes
/// do AlarmManager ou congela processos em background. O `alarm` package usa
/// Foreground Service (mais resistente), mas OEMs agressivos podem matar até
/// isso. Este watchdog é a rede de segurança.
///
/// ESTRATÉGIA (IMPORTANTE — não conflita com o `alarm` package):
/// O watchdog NÃO recria alarmes do zero. Em vez disso:
/// 1. Lê os compromissos do SharedPreferences
/// 2. Para cada um, verifica se o alarme ainda existe no `alarm` package
/// 3. SOMENTE se o alarme NÃO existe mais, re-agenda
///
/// Isso evita race conditions onde o WorkManager recriaria alarmes que o
/// Foreground Service já está tocando, causando duplicatas ou conflitos.
class AlarmWatchdog {
  static const String taskName = 'agenda_amiga_rearm';

  /// Registra a tarefa periódica. Chamar UMA VEZ após NotificationService.init().
  static Future<void> register() async {
    await Workmanager().initialize(alarmWatchdogCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
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
