package com.mindfullock.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import kotlinx.coroutines.*

class AppMonitorService : Service() {

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    private val updateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "UPDATE_BLOCKED_LIST") {
                val extras = intent.getStringExtra("blocked_packages")
                if (extras != null) {
                    BlockRulesManager.updateRules(extras)
                    // Persist it
                    val prefs = getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("blocked_rules_json", extras).apply()
                    BootReceiver.scheduleWatchdogAlarm(this@AppMonitorService, 180_000L)
                }
            }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            BlockRulesManager.loadRules(this@AppMonitorService)
            BootReceiver.scheduleWatchdogAlarm(this@AppMonitorService, 180_000L)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundServiceWithNotification()

        BlockRulesManager.loadRules(this)
        BootReceiver.scheduleWatchdogAlarm(this, 180_000L)

        LocalBroadcastManager.getInstance(this).registerReceiver(
            updateReceiver,
            IntentFilter("UPDATE_BLOCKED_LIST")
        )
        try {
            val screenFilter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_USER_PRESENT)
                addAction(Intent.ACTION_TIME_CHANGED)
                addAction(Intent.ACTION_TIMEZONE_CHANGED)
            }
            registerReceiver(screenReceiver, screenFilter)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        // Start background app monitor loop and watchdog
        startMonitoringLoop()
        startWatchdog()
    }

    private fun startMonitoringLoop() {
        val overlayManager = OverlayManager.getInstance(this)
        var quotaTrackingApp = ""
        var quotaAccumulatedMs = 0L
        var lastCheckTime = System.currentTimeMillis()

        scope.launch {
            while (isActive) {
                try {
                    val now = System.currentTimeMillis()
                    val deltaMs = (now - lastCheckTime).coerceAtLeast(0L)
                    lastCheckTime = now

                    val foregroundApp = UsageStatsHelper.getForegroundApp(this@AppMonitorService)

                    if (foregroundApp != null && foregroundApp != this@AppMonitorService.packageName && !LauncherHelper.isSystemUi(foregroundApp)) {
                        if (LauncherHelper.isLauncher(this@AppMonitorService, foregroundApp)) {
                            // User is on home screen launcher
                            if (overlayManager.isShowing()) {
                                withContext(Dispatchers.Main) {
                                    overlayManager.hideOverlay()
                                }
                            }
                            if (quotaTrackingApp.isNotEmpty() && quotaAccumulatedMs >= 1000L) {
                                val seconds = (quotaAccumulatedMs / 1000L).toInt()
                                BlockRulesManager.incrementQuotaUsage(quotaTrackingApp, seconds, this@AppMonitorService)
                            }
                            quotaTrackingApp = ""
                            quotaAccumulatedMs = 0L
                        } else {
                            // 1. Quota usage tracking (Accumulate and flush every second)
                            if (foregroundApp == quotaTrackingApp) {
                                quotaAccumulatedMs += deltaMs
                                if (quotaAccumulatedMs >= 1000L) {
                                    val seconds = (quotaAccumulatedMs / 1000L).toInt()
                                    BlockRulesManager.incrementQuotaUsage(foregroundApp, seconds, this@AppMonitorService)
                                    quotaAccumulatedMs %= 1000L
                                }
                            } else {
                                if (quotaTrackingApp.isNotEmpty() && quotaAccumulatedMs >= 1000L) {
                                    val seconds = (quotaAccumulatedMs / 1000L).toInt()
                                    BlockRulesManager.incrementQuotaUsage(quotaTrackingApp, seconds, this@AppMonitorService)
                                }
                                quotaTrackingApp = foregroundApp
                                quotaAccumulatedMs = 0L
                            }

                            // 2. Blocking logic (Always active even alongside AccessibilityService for zero-gap reliability)
                            val isBlocked = BlockRulesManager.isAppBlocked(foregroundApp, this@AppMonitorService)
                            if (isBlocked) {
                                if (!overlayManager.isShowing()) {
                                    withContext(Dispatchers.Main) {
                                        overlayManager.showOverlay(foregroundApp)
                                    }
                                    val intent = Intent("APP_BLOCKED_EVENT")
                                    intent.putExtra("package_name", foregroundApp)
                                    LocalBroadcastManager.getInstance(this@AppMonitorService).sendBroadcast(intent)
                                }
                            } else {
                                // Only hide if the blocked app is no longer blocked or user switched to an allowed app
                                if (overlayManager.isShowing() && !BlockRulesManager.isAppBlocked(overlayManager.lastBlockedPackageName, this@AppMonitorService)) {
                                    withContext(Dispatchers.Main) {
                                        overlayManager.hideOverlay()
                                    }
                                }
                            }
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                delay(300) // Poll every 300ms for snappy detection
            }
        }
    }

    private fun startWatchdog() {
        scope.launch {
            while (isActive) {
                try {
                    val prefs = getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                    val dnsEnabled = prefs.getBoolean("dns_filter_enabled", false)
                    if (dnsEnabled && !DnsFilterService.isRunning) {
                        val dnsIntent = Intent(this@AppMonitorService, DnsFilterService::class.java)
                        startService(dnsIntent)
                    }
                    BootReceiver.scheduleWatchdogAlarm(this@AppMonitorService, 180_000L)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                delay(60000) // Check every 60 seconds (Save battery)
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra("blocked_packages")?.let {
            BlockRulesManager.updateRules(it)
            val prefs = getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            prefs.edit().putString("blocked_rules_json", it).apply()
        } ?: run {
            BlockRulesManager.loadRules(this)
        }
        BootReceiver.scheduleWatchdogAlarm(this, 180_000L)
        return START_STICKY
    }

    private fun startForegroundServiceWithNotification() {
        val notification = NotificationCompat.Builder(this, "mindfullock_service")
            .setContentTitle("Jeda aktif \uD83C\uDF3F")
            .setContentText("Menjaga fokusmu dengan hemat baterai")
            .setSmallIcon(android.R.drawable.ic_secure)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
            
        startForeground(1, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "mindfullock_service",
                "Jeda Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoring background tasks for Jeda"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun scheduleImmediateRestartIfNeeded() {
        try {
            if (!BlockRulesManager.hasAnyActiveRules(this)) return

            BootReceiver.scheduleWatchdogAlarm(this, 1500L)

            val restartServiceIntent = Intent(applicationContext, AppMonitorService::class.java).also {
                it.setPackage(packageName)
            }
            val flags = PendingIntent.FLAG_ONE_SHOT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val restartServicePendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PendingIntent.getForegroundService(this, 1, restartServiceIntent, flags)
            } else {
                PendingIntent.getService(this, 1, restartServiceIntent, flags)
            }
            val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = System.currentTimeMillis() + 1000L
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmService.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, restartServicePendingIntent)
            } else {
                alarmService.set(AlarmManager.RTC_WAKEUP, triggerAt, restartServicePendingIntent)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        scheduleImmediateRestartIfNeeded()
    }

    override fun onDestroy() {
        scheduleImmediateRestartIfNeeded()
        super.onDestroy()
        scope.cancel()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(updateReceiver)
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
