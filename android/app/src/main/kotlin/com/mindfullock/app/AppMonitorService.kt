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
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForegroundServiceWithNotification()

        BlockRulesManager.loadRules(this)

        LocalBroadcastManager.getInstance(this).registerReceiver(
            updateReceiver,
            IntentFilter("UPDATE_BLOCKED_LIST")
        )
        
        // Start background app monitor loop and watchdog
        startMonitoringLoop()
        startWatchdog()
    }

    private fun startMonitoringLoop() {
        val overlayManager = OverlayManager(this)
        var lastForegroundApp = ""
        var quotaTrackingPackage = ""
        var quotaTrackingSeconds = 0

        scope.launch {
            while (isActive) {
                try {
                    val foregroundApp = UsageStatsHelper.getForegroundApp(this@AppMonitorService)

                    if (foregroundApp != null) {
                        // 1. Quota usage tracking
                        if (foregroundApp == quotaTrackingPackage) {
                            quotaTrackingSeconds++
                            if (quotaTrackingSeconds >= 5) {
                                BlockRulesManager.incrementQuotaUsage(quotaTrackingPackage, quotaTrackingSeconds)
                                quotaTrackingSeconds = 0
                            }
                        } else {
                            if (quotaTrackingPackage.isNotEmpty() && quotaTrackingSeconds > 0) {
                                BlockRulesManager.incrementQuotaUsage(quotaTrackingPackage, quotaTrackingSeconds)
                            }
                            quotaTrackingPackage = foregroundApp
                            quotaTrackingSeconds = 0
                        }

                        // 2. Blocking logic
                        if (foregroundApp == packageName) {
                            // Don't block Jeda itself
                            if (overlayManager.isShowing()) {
                                overlayManager.hideOverlay()
                            }
                        } else {
                            val isBlocked = BlockRulesManager.isAppBlocked(foregroundApp, this@AppMonitorService)
                            if (isBlocked) {
                                if (!overlayManager.isShowing() && !overlayManager.isExitingBlockedApp(foregroundApp)) {
                                    withContext(Dispatchers.Main) {
                                        overlayManager.showOverlay(foregroundApp)
                                    }
                                    val intent = Intent("APP_BLOCKED_EVENT")
                                    intent.putExtra("package_name", foregroundApp)
                                    LocalBroadcastManager.getInstance(this@AppMonitorService).sendBroadcast(intent)
                                }
                            } else {
                                if (overlayManager.isShowing()) {
                                    withContext(Dispatchers.Main) {
                                        overlayManager.hideOverlay()
                                    }
                                }
                            }
                        }
                        lastForegroundApp = foregroundApp
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                delay(1000) // Poll every 1 second
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
        }
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

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val restartServiceIntent = Intent(applicationContext, AppMonitorService::class.java).also {
            it.setPackage(packageName)
        }
        val restartServicePendingIntent = PendingIntent.getService(
            this, 1, restartServiceIntent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmService.set(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 1000,
            restartServicePendingIntent
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(updateReceiver)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
