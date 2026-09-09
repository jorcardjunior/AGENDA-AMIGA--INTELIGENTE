import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Resultado completo da verificação de permissões do alarme.
class AlarmPermissionStatus {
  final bool notificationsEnabled;
  final bool exactAlarmAllowed;
  final bool batteryOptimizationDisabled;
  final bool alarmPackageInitialized;

  const AlarmPermissionStatus({
    required this.notificationsEnabled,
    required this.exactAlarmAllowed,
    required this.batteryOptimizationDisabled,
    required this.alarmPackageInitialized,
  });

  /// true somente quando TODAS as permissões críticas estão OK.
  bool get allGranted =>
      notificationsEnabled &&
      exactAlarmAllowed &&
      batteryOptimizationDisabled &&
      alarmPackageInitialized;

  /// Lista de permissões que NÃO estão OK.
  List<String> get missing {
    final m = <String>[];
    if (!notificationsEnabled) m.add('Notificações');
    if (!exactAlarmAllowed) m.add('Alarme Exato');
    if (!batteryOptimizationDisabled) m.add('Otimização de Bateria');
    if (!alarmPackageInitialized) m.add('Serviço de Alarme');
    return m;
  }
}

/// Serviço centralizado que verifica e pede TODAS as permissões necessárias
/// para o alarme funcionar em 100% dos cenários Android.
class PermissionGuard {
  PermissionGuard._();

  static const _channel = MethodChannel('agenda_amiga/device');
  static final _fln = FlutterLocalNotificationsPlugin();

  // ════════════════════════════════════════════════════════════════════════
  // VERIFICAÇÃO (somente leitura)
  // ════════════════════════════════════════════════════════════════════════

  static Future<AlarmPermissionStatus> check() async {
    final results = await Future.wait([
      _checkNotifications(),
      _checkExactAlarm(),
      _checkBatteryOptimization(),
      _checkAlarmPackage(),
    ]);
    return AlarmPermissionStatus(
      notificationsEnabled: results[0],
      exactAlarmAllowed: results[1],
      batteryOptimizationDisabled: results[2],
      alarmPackageInitialized: results[3],
    );
  }

  static Future<bool> _checkNotifications() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkExactAlarm() async {
    if (!Platform.isAndroid) return true;
    try {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      return result == true;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> _checkAlarmPackage() async {
    try {
      await Alarm.getAlarms();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PEDIDO DE PERMISSÕES
  // ════════════════════════════════════════════════════════════════════════

  /// Pede todas as permissões críticas de uma vez.
  static Future<void> requestAll() async {
    if (!Platform.isAndroid) return;

    final android = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // 1. Notificações (Android 13+)
    try { await android?.requestNotificationsPermission(); } catch (_) {}

    // 2. Alarme exato (Android 12+)
    try { await android?.requestExactAlarmsPermission(); } catch (_) {}

    // 3. Otimização de bateria — abre ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
    try { await _channel.invokeMethod('requestBatteryWhitelist'); } catch (_) {}

    // 4. Full screen intent (Android 14+)
    try { await android?.requestFullScreenIntentPermission(); } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════════════
  // ABRIR CONFIGURAÇÕES MANUALMENTE
  // ════════════════════════════════════════════════════════════════════════

  static Future<bool> openNotificationSettings() async {
    try {
      final android = _fln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.openAppNotificationSettings() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAutostartSettings() async {
    try {
      return await _channel.invokeMethod('openAutostartSettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBatteryManager() async {
    try {
      return await _channel.invokeMethod('openBatteryManager') ?? false;
    } catch (_) {
      return false;
    }
  }
}
