import 'dart:async';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:alarm/utils/alarm_set.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Serviço centralizado de alarmes e notificações.
///
/// RESPONSABILIDADES:
/// 1. Inicializar o `alarm` package (Foreground Service + AlarmManager)
/// 2. Inicializar o `flutter_local_notifications` (fallback + diagnóstico)
/// 3. Agendar/cancelar alarmes via `alarm` package como PRIMÁRIO
/// 4. Fallback para `flutter_local_notifications` se o `alarm` falhar
/// 5. Fornecer diagnóstico de canais e permissões
///
/// O `alarm` package usa STREAM_ALARM nativo via Foreground Service —
/// não há conflito de AudioFocus com audioplayers porque o alarm package
/// é quem controla o áudio diretamente pelo AudioManager nativo.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ── Dependências ────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  // ── Estado ──────────────────────────────────────────────────────────
  bool _initialized = false;
  StreamSubscription<AlarmSet>? _alarmRingSubscription;

  /// Channel version bumped on purpose: Android notification channels are
  /// immutable once created. If an older version of the app created the
  /// channel without sound/vibration, REINSTALLING DOES NOT RESET IT and every
  /// alarm after that is permanently silent. A fresh channel id forces Android
  /// to create the channel again with the current (correct) sound config.
  static const String alarmChannelId = 'agenda_amiga_alarms_v3';
  static const String alarmChannelName = 'Alarmes de Compromissos e Remédios';

  /// Last outcome of [scheduleAlarm]: which scheduling mode actually worked.
  /// Exposed so the diagnostic UI can show exactly what happened.
  String lastScheduleResult = 'not_called_yet';

  /// Fired when the user taps a notification while the app is running.
  void Function(int notificationId, String payload)? onNotificationTap;

  /// Callback to invoke when an alarm fires via the Foreground Service.
  /// Set by main.dart to show the AlarmModal.
  void Function(int alarmId, String payload)? onAlarmFired;

  /// Map of alarm ID -> payload for the `alarm` package alarms.
  /// Needed because the `alarm` package only passes the ID to the ring stream,
  /// not the payload.
  final Map<int, String> _alarmPayloads = {};

  // ════════════════════════════════════════════════════════════════════════
  // INICIALIZAÇÃO
  // ════════════════════════════════════════════════════════════════════════

  /// Inicializa TODOS os serviços de alarme. Chamar UMA VEZ no app start.
  ///
  /// Ordem crítica:
  /// 1. Timezone (necessário para FLN)
  /// 2. Alarm package (Foreground Service)
  /// 3. FLN (fallback + diagnóstico)
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Timezone
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    // 2. Alarm package — FOREGROUND SERVICE (o mais importante)
    //    Isso cria o AlarmReceiver, BootReceiver e AlarmService nativos.
    //    O AlarmService usa foregroundServiceType="mediaPlayback" para
    //    tocar áudio via STREAM_ALARM mesmo com app fechado.
    await Alarm.init();

    // Escuta o ring stream: quando o Foreground Service dispara o alarme,
    // recebemos o ID e chamamos o callback do main.dart para mostrar o modal.
    _alarmRingSubscription?.cancel();
    _alarmRingSubscription = Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        final payload = _alarmPayloads[alarm.id] ?? '';
        onAlarmFired?.call(alarm.id, payload);
      }
    });

    // 3. Flutter Local Notifications — FALLBACK + DIAGNÓSTICO
    //    Usado apenas como backup se o alarm package falhar,
    //    e para verificações de diagnóstico (canais, permissões).
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _fln.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        final id = details.id ?? 0;
        final payload = details.payload;
        onNotificationTap?.call(id, payload ?? '');
      },
    );

    // Se o app foi lançado por uma notificação, processa o payload.
    final launch = await _fln.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final payload = launch!.notificationResponse?.payload ?? '';
      if (payload.isNotEmpty) {
        onNotificationTap?.call(0, payload);
      }
    }
  }

  void dispose() {
    _alarmRingSubscription?.cancel();
  }

  // ════════════════════════════════════════════════════════════════════════
  // AGENDAMENTO DE ALARMES
  // ════════════════════════════════════════════════════════════════════════

  /// Agenda um alarme usando o `alarm` package como PRIMÁRIO.
  ///
  /// O `alarm` package usa:
  /// - AlarmManager para agendamento preciso
  /// - Foreground Service para tocar o áudio
  /// - STREAM_ALARM nativo (funciona em silencioso/DND)
  /// - fullScreenIntent para ligar a tela
  ///
  /// Se o `alarm` package falhar, fallback para `flutter_local_notifications`.
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? recurrence,
    String payload = '',
  }) async {
    // ═══════════════════════════════════════════════════════════════════
    // CAMINHO PRIMÁRIO: alarm package (Foreground Service)
    // ═══════════════════════════════════════════════════════════════════
    try {
      final alarmSettings = AlarmSettings(
        id: id,
        dateTime: scheduledTime,
        // O alarm package toca este áudio via STREAM_ALARM nativo.
        // Não há conflito de AudioFocus porque o Foreground Service
        // controla o AudioManager diretamente no Kotlin.
        assetAudioPath: 'assets/sounds/alarm_sound.wav',
        loopAudio: true,
        vibrate: true,
        // Liga a tela quando o alarme dispara (full screen intent).
        androidFullScreenIntent: true,
        // Mostra aviso se o app for morto pelo sistema.
        warningNotificationOnKill: Platform.isAndroid,
        // Configurações de volume: fade de 3s, volume 80%, forçado.
        volumeSettings: VolumeSettings.fade(
          volume: 0.8,
          fadeDuration: const Duration(seconds: 3),
          volumeEnforced: true,
        ),
        // Notificação do Foreground Service.
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: 'Parar Alarme',
          icon: 'notification_icon',
        ),
      );

      // Armazena o payload para recuperar quando o alarme disparar.
      _alarmPayloads[id] = payload;

      await Alarm.set(alarmSettings: alarmSettings);
      lastScheduleResult = 'alarm_package';
      return;
    } catch (_) {
      // Se o alarm package falhar, continua para o fallback.
    }

    // ═══════════════════════════════════════════════════════════════════
    // FALLBACK: flutter_local_notifications (zonedSchedule)
    // ═══════════════════════════════════════════════════════════════════
    try {
      final details = _buildFallbackAndroidDetails();
      final platformDetails = NotificationDetails(android: details);

      DateTimeComponents? match;
      if (recurrence == 'Todos os dias') {
        match = DateTimeComponents.time;
      } else if (recurrence == 'Semanal') {
        match = DateTimeComponents.dayOfWeekAndTime;
      } else if (recurrence == 'Mensal') {
        match = DateTimeComponents.dayOfMonthAndTime;
      }

      final scheduleMode = match == null
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.exactAllowWhileIdle;

      await _fln.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: platformDetails,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: match,
        payload: payload,
      );
      lastScheduleResult = 'alarmClock_fallback';
    } catch (_) {
      // ═══════════════════════════════════════════════════════════════════
      // ÚLTIMO RECURSO: notificação imediata
      // ═══════════════════════════════════════════════════════════════════
      try {
        final details = _buildFallbackAndroidDetails();
        final platformDetails = NotificationDetails(android: details);
        await _fln.show(id: id, title: title, body: body, notificationDetails: platformDetails);
        lastScheduleResult = 'immediate_fallback';
      } catch (__) {
        lastScheduleResult = 'all_failed';
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // CANCELAMENTO
  // ════════════════════════════════════════════════════════════════════════

  /// Cancela um alarme específico em TODOS os sistemas (alarm package + FLN).
  Future<void> cancel(int id) async {
    // Cancela no alarm package (Foreground Service)
    try {
      await Alarm.stop(id);
    } catch (_) {}
    _alarmPayloads.remove(id);

    // Cancela no FLN (fallback)
    await _fln.cancel(id: id);
  }

  /// Cancela TODOS os alarmes em TODOS os sistemas.
  Future<void> cancelAll() async {
    // Para todos os alarmes do alarm package
    try {
      final alarms = await Alarm.getAlarms();
      for (final alarm in alarms) {
        await Alarm.stop(alarm.id);
      }
    } catch (_) {}
    _alarmPayloads.clear();

    // Cancela todas as notificações do FLN
    await _fln.cancelAll();
  }

  // ════════════════════════════════════════════════════════════════════════
  // NOTIFICAÇÕES IMEDIATAS (para testes e diagnóstico)
  // ════════════════════════════════════════════════════════════════════════

  /// Mostra uma notificação imediata (não agendada).
  Future<void> showImmediate({
    required String title,
    required String body,
    int id = 1,
  }) async {
    final details = _buildFallbackAndroidDetails();
    final platformDetails = NotificationDetails(android: details);
    await _fln.show(id: id, title: title, body: body, notificationDetails: platformDetails);
  }

  // ════════════════════════════════════════════════════════════════════════
  // DIAGNÓSTICO (chamadas via MethodChannel para Kotlin)
  // ════════════════════════════════════════════════════════════════════════

  /// Marca do dispositivo (Samsung, Xiaomi, Realme, etc.)
  Future<String> deviceBrand() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      final brand = await channel.invokeMethod<String>('getBrand');
      return brand ?? 'Android';
    } catch (_) {
      return 'Android';
    }
  }

  /// Verifica se o canal de notificação está habilitado no OS.
  Future<Map<String, dynamic>> isChannelEnabled(String channelId) async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      final raw = await channel.invokeMethod('isChannelEnabled', channelId);
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
      return {'exists': false, 'enabled': false};
    } catch (_) {
      return {'exists': false, 'enabled': false};
    }
  }

  /// Abre as configurações de um canal de notificação específico.
  Future<bool> openChannelSettings(String channelId) async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('openChannelSettings', channelId) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Envia uma notificação de teste no canal padrão (bypassa canal custom).
  Future<bool> testDefaultNotification() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('testDefaultNotification') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verifica permissões de alarme via FLN.
  Future<Map<String, bool?>> alarmPermissionsStatus() async {
    final impl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notificationsEnabled = await impl?.areNotificationsEnabled();
    final exactAllowed = await impl?.canScheduleExactNotifications();
    return {
      'notificationsEnabled': notificationsEnabled,
      'exactAlarmAllowed': exactAllowed,
    };
  }

  /// Abre as configurações de notificação do app.
  Future<bool> openAppNotificationSettings() async {
    final impl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.openAppNotificationSettings() ?? false;
  }

  /// Pede permissão de notificações (Android 13+).
  Future<void> requestNotificationPermission() async {
    final impl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await impl?.requestNotificationsPermission();
  }

  /// Pede permissão de alarme exato.
  Future<bool> requestExactAlarmPermission() async {
    final impl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await impl?.requestExactAlarmsPermission() ?? false;
  }

  /// Pede permissão de full screen intent.
  Future<void> requestFullScreenIntentPermission() async {
    final impl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await impl?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  /// Verifica se o app está isento de otimização de bateria.
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Abre o dialog de pedido de isenção de bateria.
  Future<bool> requestBatteryWhitelist() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('requestBatteryWhitelist') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre configurações de autostart (OPPO/Realme/OnePlus).
  Future<bool> openAutostartSettings() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('openAutostartSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre gerenciamento de bateria do app (Realme/OPPO).
  Future<bool> openBatteryManager() async {
    try {
      const channel = MethodChannel('agenda_amiga/device');
      return await channel.invokeMethod('openBatteryManager') ?? false;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ════════════════════════════════════════════════════════════════════════

  /// Configurações do canal de notificação para o FALLBACK (FLN).
  /// O `alarm` package tem seu próprio canal — este é apenas backup.
  static const AndroidNotificationDetails _fallbackAndroidDetails =
      AndroidNotificationDetails(
    alarmChannelId,
    alarmChannelName,
    channelDescription: 'Alarmes com privilégio 24h para lembretes importantes',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    visibility: NotificationVisibility.public,
    sound: RawResourceAndroidNotificationSound('alarm_sound'),
    playSound: true,
    category: AndroidNotificationCategory.alarm,
  );

  AndroidNotificationDetails _buildFallbackAndroidDetails() {
    return _fallbackAndroidDetails;
  }
}
