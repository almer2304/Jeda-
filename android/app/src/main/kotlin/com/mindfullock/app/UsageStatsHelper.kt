package com.mindfullock.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

object UsageStatsHelper {

    @Volatile
    private var cachedForegroundPackage: String? = null
    @Volatile
    private var lastObservedEventTime: Long = 0L

    fun resetCache() {
        cachedForegroundPackage = null
        lastObservedEventTime = System.currentTimeMillis()
    }

    fun getForegroundApp(context: Context): String? {
        try {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val endTime = System.currentTimeMillis()
            val startTime = endTime - 10000 // 10 seconds event search window

            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()
            var currentForeground: String? = null
            var latestTimestamp = 0L

            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                if (event.timeStamp >= latestTimestamp) {
                    when (event.eventType) {
                        UsageEvents.Event.ACTIVITY_RESUMED,
                        UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                            currentForeground = event.packageName
                            latestTimestamp = event.timeStamp
                        }
                        UsageEvents.Event.ACTIVITY_PAUSED,
                        UsageEvents.Event.ACTIVITY_STOPPED,
                        UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                            if (event.packageName == currentForeground) {
                                currentForeground = null
                            }
                            latestTimestamp = event.timeStamp
                        }
                    }
                }
            }

            if (currentForeground != null) {
                cachedForegroundPackage = currentForeground
                lastObservedEventTime = latestTimestamp
                return currentForeground
            }

            // No active resumed app found in recent events
            // Clear stale cache and return null
            cachedForegroundPackage = null
            return null
        } catch (e: Exception) {
            e.printStackTrace()
            return null
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