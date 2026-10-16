package com.mindfullock.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_WATCHDOG_CHECK = "com.mindfullock.app.ACTION_WATCHDOG_CHECK"

        fun scheduleWatchdogAlarm(context: Context, delayMs: Long = 180_000L) {
            try {
                val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                val jsonString = prefs.getString("blocked_rules_json", null)
                if (jsonString.isNullOrEmpty() || jsonString == "[]") return

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, BootReceiver::class.java).apply {
                    action = ACTION_WATCHDOG_CHECK
                }
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                val pendingIntent = PendingIntent.getBroadcast(context, 7701, intent, flags)
                val triggerAt = System.currentTimeMillis() + delayMs

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == Intent.ACTION_USER_PRESENT ||
            action == ACTION_WATCHDOG_CHECK
        ) {
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)

            // 1. Restart App Monitor Service if rules exist
            val jsonString = prefs.getString("blocked_rules_json", null)
            if (jsonString != null && jsonString != "[]") {
                try {
                    val serviceIntent = Intent(context, AppMonitorService::class.java).apply {
                        putExtra("blocked_packages", jsonString)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                scheduleWatchdogAlarm(context, 180_000L)
            }

            // 2. Restart DNS Filter (VPN) if it was enabled
            val dnsEnabled = prefs.getBoolean("dns_filter_enabled", false)
            if (dnsEnabled && !DnsFilterService.isRunning) {
                try {
                    val dnsIntent = Intent(context, DnsFilterService::class.java)
                    context.startService(dnsIntent)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}