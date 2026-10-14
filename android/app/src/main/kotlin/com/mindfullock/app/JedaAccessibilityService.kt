package com.mindfullock.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import kotlinx.coroutines.*

class JedaAccessibilityService : AccessibilityService() {

    private lateinit var overlayManager: OverlayManager

    @Volatile
    private var lastForegroundPackage: String = ""
    @Volatile
    private var currentlyBlockedPackage: String = ""

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var safetyCheckJob: Job? = null

    companion object {
        @Volatile
        var isServiceRunning: Boolean = false
            private set

        @Volatile
        private var activeService: JedaAccessibilityService? = null

        fun clearBlockedState() {
            activeService?.let {
                it.currentlyBlockedPackage = ""
                it.lastForegroundPackage = ""
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        activeService = this
        overlayManager = OverlayManager.getInstance(this)
        BlockRulesManager.loadRules(this)
        startSafetyCheckLoop()
    }

    private fun startSafetyCheckLoop() {
        safetyCheckJob?.cancel()
        safetyCheckJob = scope.launch {
            var quotaTrackingPkg = ""
            var quotaSeconds = 0
            while (isActive) {
                delay(1000)
                try {
                    val currentPkg = lastForegroundPackage

                    // 1. If exiting or empty or launcher/system, hide overlay and do not block
                    if (currentPkg.isEmpty() ||
                        overlayManager.isExitingBlockedApp(currentPkg) ||
                        LauncherHelper.isLauncherOrSystem(this@JedaAccessibilityService, currentPkg)) {
                        
                        if (overlayManager.isShowing()) {
                            overlayManager.hideOverlay()
                            currentlyBlockedPackage = ""
                        }
                        if (quotaTrackingPkg.isNotEmpty() && quotaSeconds > 0) {
                            BlockRulesManager.incrementQuotaUsage(quotaTrackingPkg, quotaSeconds, this@JedaAccessibilityService)
                            quotaTrackingPkg = ""
                            quotaSeconds = 0
                        }
                        continue
                    }

                    // 2. Quota tracking: Every 1 second in foreground
                    if (currentPkg == quotaTrackingPkg) {
                        quotaSeconds++
                        if (quotaSeconds >= 1) {
                            BlockRulesManager.incrementQuotaUsage(quotaTrackingPkg, quotaSeconds, this@JedaAccessibilityService)
                            quotaSeconds = 0
                        }
                    } else {
                        if (quotaTrackingPkg.isNotEmpty() && quotaSeconds > 0) {
                            BlockRulesManager.incrementQuotaUsage(quotaTrackingPkg, quotaSeconds, this@JedaAccessibilityService)
                        }
                        quotaTrackingPkg = currentPkg
                        quotaSeconds = 1
                        BlockRulesManager.incrementQuotaUsage(quotaTrackingPkg, quotaSeconds, this@JedaAccessibilityService)
                        quotaSeconds = 0
                    }

                    // 3. Blocking check
                    val isBlocked = BlockRulesManager.isAppBlocked(currentPkg, this@JedaAccessibilityService)

                    if (isBlocked) {
                        if (!overlayManager.isShowing() && !overlayManager.isExitingBlockedApp(currentPkg)) {
                            currentlyBlockedPackage = currentPkg
                            overlayManager.showOverlay(currentPkg)
                            broadcastBlockedEvent(currentPkg)
                        }
                    } else {
                        if (overlayManager.isShowing()) {
                            overlayManager.hideOverlay()
                            currentlyBlockedPackage = ""
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // ONLY respond to TYPE_WINDOW_STATE_CHANGED for app switching.
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            return
        }

        val packageName = event.packageName?.toString() ?: return

        // === 1. Anti-Uninstall Logic ===
        val className = event.className?.toString() ?: ""
        if (packageName == "com.android.settings" &&
            (className.contains("DeviceAdminAdd") || className.contains("DeviceAdminSettings") || className.contains("SubSettings"))) {

            val nodeInfo = rootInActiveWindow
            if (nodeInfo != null) {
                val texts = nodeInfo.findAccessibilityNodeInfosByText("Jeda")
                if (texts.isNotEmpty()) {
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    JedaDeviceAdminReceiver.showBypassWarningNotification(this)
                    val launchIntent = packageManager.getLaunchIntentForPackage(this.packageName)
                    launchIntent?.let {
                        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        it.putExtra("route", "/forced_uninstall_warning")
                        it.putExtra("action", "ADMIN_DISABLE_ATTEMPT")
                        startActivity(it)
                    }
                    val intent = Intent("JEDA_ADMIN_DISABLE_REQUESTED")
                    LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
                    sendBroadcast(intent)
                }
                nodeInfo.recycle()
            }
        }

        // === 2. ALWAYS update lastForegroundPackage ===
        lastForegroundPackage = packageName

        // === 3. Skip our own package ===
        if (packageName == this.packageName) {
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
            return
        }

        // === 4. Launcher & System UI check ===
        if (LauncherHelper.isLauncherOrSystem(this, packageName)) {
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
            return
        }

        // === 5. App Blocking Logic ===
        val isBlocked = BlockRulesManager.isAppBlocked(packageName, this)

        if (isBlocked) {
            currentlyBlockedPackage = packageName
            if (!overlayManager.isShowing() && !overlayManager.isExitingBlockedApp(packageName)) {
                overlayManager.showOverlay(packageName)
                broadcastBlockedEvent(packageName)
            }
        } else {
            // App is NOT blocked. Hide overlay immediately.
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
        }
    }

    private fun broadcastBlockedEvent(packageName: String) {
        val intent = Intent("APP_BLOCKED_EVENT")
        intent.putExtra("package_name", packageName)
        LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        activeService = null
        safetyCheckJob?.cancel()
        scope.cancel()
    }
}
