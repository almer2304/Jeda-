package com.mindfullock.app

import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.Process

object UsageStatsHelper {

    @Volatile
    private var cachedForegroundPackage: String? = null
    @Volatile
    private var cachedForegroundClass: String? = null
    @Volatile
    private var lastResetTime: Long = 0L

    fun resetCache() {
        cachedForegroundPackage = null
        cachedForegroundClass = null
        lastResetTime = System.currentTimeMillis()
    }

    fun getForegroundApp(context: Context): String? {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            val isInteractive = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                powerManager?.isInteractive ?: true
            } else {
                @Suppress("DEPRECATION")
                powerManager?.isScreenOn ?: true
            }
            if (!isInteractive || keyguardManager?.isKeyguardLocked == true) {
                cachedForegroundPackage = null
                cachedForegroundClass = null
                return null
            }

            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()
            val startTime = maxOf(endTime - 60000L, lastResetTime)

            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            var currentForeground: String? = null
            var currentClass: String? = null
            var latestTimestamp = 0L
            var sawAnyTransition = false

            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                val pkg = event.packageName ?: continue
                if (pkg == context.packageName || LauncherHelper.isSystemUi(pkg)) {
                    continue
                }

                if (event.timeStamp >= latestTimestamp) {
                    when (event.eventType) {
                        UsageEvents.Event.ACTIVITY_RESUMED,
                        UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                            currentForeground = pkg
                            currentClass = event.className
                            latestTimestamp = event.timeStamp
                            sawAnyTransition = true
                        }
                        UsageEvents.Event.ACTIVITY_PAUSED,
                        UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                            if (pkg == currentForeground &&
                                (currentClass == null || event.className == null || event.className == currentClass)
                            ) {
                                currentForeground = null
                                currentClass = null
                            }
                            latestTimestamp = event.timeStamp
                            sawAnyTransition = true
                        }
                    }
                }
            }

            if (currentForeground != null) {
                cachedForegroundPackage = currentForeground
                cachedForegroundClass = currentClass
                return currentForeground
            }

            if (sawAnyTransition) {
                cachedForegroundPackage = null
                cachedForegroundClass = null
                return null
            }

            return cachedForegroundPackage
        } catch (e: Exception) {
            e.printStackTrace()
            return cachedForegroundPackage
        }
    }

    fun isPermissionGranted(context: Context): Boolean {
        try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }
}