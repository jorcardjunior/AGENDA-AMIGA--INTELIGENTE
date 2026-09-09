package com.jorcardjr.agenda_amiga_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var savedAlarmVolume = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "agenda_amiga/device",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBrand" -> result.success("${Build.MANUFACTURER} ${Build.MODEL}")
                "boostAlarmAudio" -> result.success(boostAlarmAudio())
                "restoreAlarmAudio" -> result.success(restoreAlarmAudio())
                "isIgnoringBatteryOptimizations" -> result.success(isIgnoringBatteryOptimizations())
                "requestBatteryWhitelist" -> result.success(requestBatteryWhitelist())
                "openAutostartSettings" -> result.success(openAutostartSettings())
                "openBatteryManager" -> result.success(openBatteryManager())
                "isChannelEnabled" -> result.success(isChannelEnabled(call.arguments as? String ?: ""))
                "openChannelSettings" -> result.success(openChannelSettings(call.arguments as? String ?: ""))
                "testDefaultNotification" -> result.success(testDefaultNotification())
                else -> result.notImplemented()
            }
        }
    }

    // ── Audio volume boost ──────────────────────────────────────────────
    private fun boostAlarmAudio(): Boolean {
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return false
        val current = am.getStreamVolume(AudioManager.STREAM_ALARM)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        if (max <= 0) return false
        if (current >= (max * 0.6).toInt()) return true
        savedAlarmVolume = current
        am.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
        return true
    }

    private fun restoreAlarmAudio(): Boolean {
        val am = getSystemService(AUDIO_SERVICE) as? AudioManager ?: return false
        if (savedAlarmVolume >= 0) {
            am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
            savedAlarmVolume = -1
        }
        return true
    }

    // ── Battery / OEM freeze checks ─────────────────────────────────────
    private fun isIgnoringBatteryOptimizations(): Boolean = try {
        val pm = getSystemService(POWER_SERVICE) as? PowerManager
        pm?.isIgnoringBatteryOptimizations(packageName) ?: false
    } catch (_: Throwable) { false }

    private fun requestBatteryWhitelist(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")),
        )
        true
    } catch (_: Throwable) { false }

    private fun openAutostartSettings(): Boolean {
        if (launch("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")) return true
        if (launch("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")) return true
        return openAppDetails()
    }

    private fun openBatteryManager(): Boolean {
        if (launch("com.coloros.oppoguardelf", "com.coloros.oppoguardelf.BatteryActivity")) return true
        if (launch("com.oppo.safe", "com.oppo.safe.battery.BatteryActivity")) return true
        return openAppDetails()
    }

    // ── Channel diagnostics (THE MISSING PIECE) ─────────────────────────
    /**
     * Checks whether a notification channel exists and is enabled.
     * Returns a map the Flutter side can display.
     * Many OEMs silently disable channels, or users accidentally mute them —
     * this is the #1 hidden cause of "alarm doesn't ring" when permissions
     * are green.
     */
    private fun isChannelEnabled(channelId: String): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return mapOf("exists" to true, "enabled" to true, "importance" to 3, "hasSound" to true)
        }
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = nm.getNotificationChannel(channelId) ?: return mapOf(
            "exists" to false, "enabled" to false, "importance" to 0, "hasSound" to false,
        )
        val channelEnabled = channel.importance > NotificationManager.IMPORTANCE_NONE
        val channelHasSound = channel.sound != null
        val channelHasVibration = channel.shouldVibrate()
        return mapOf(
            "exists" to true,
            "enabled" to channelEnabled,
            "importance" to channel.importance,
            "hasSound" to channelHasSound,
            "hasVibration" to channelHasVibration,
        )
    }

    /** Opens the EXACT settings page for a specific notification channel. */
    private fun openChannelSettings(channelId: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
            )
            true
        } catch (_: Throwable) { false }
    }

    /**
     * Posts a test notification on a FRESH DEFAULT channel (bypasses our
     * custom alarm channel entirely). If the user sees this, Android
     * notifications work — the problem is our channel or the scheduling.
     */
    private fun testDefaultNotification(): Boolean {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "agenda_amiga_diag_test"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val existing = nm.getNotificationChannel(channelId)
            if (existing == null) {
                val ch = NotificationChannel(
                    channelId,
                    "Testes de Diagnóstico",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Canal temporário para testar se notificações funcionam"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                }
                nm.createNotificationChannel(ch)
            }
        }
        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🔔 Teste de Notificação Android")
            .setContentText("Se você vê e ouve esta notificação, o Android está funcionando!")
            .setStyle(Notification.BigTextStyle().bigText(
                "Esta notificação foi enviada diretamente pelo Android (sem o plugin Flutter). "
                + "Se ela aparece e toca, o problema está no agendamento do alarme, "
                + "não no sistema de notificações."
            ))
            .setAutoCancel(true)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()
        nm.notify(888888888, notification)
        return true
    }

    // ── Helpers ──────────────────────────────────────────────────────────
    private fun launch(pkg: String, cls: String): Boolean = try {
        val intent = Intent().setClassName(pkg, cls)
        if (intent.resolveActivity(packageManager) != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } else false
    } catch (_: Throwable) { false }

    private fun openAppDetails(): Boolean = try {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")),
        )
        true
    } catch (_: Throwable) { true }
}
