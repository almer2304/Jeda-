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
    @Volatile
    private var lastBlockedOverlayShownTime: Long = 0L

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var safetyCheckJob: Job? = null

    companion object {
        @Volatile
        var isServiceRunning: Boolean = false
            private set

        @Volatile
        private var activeService: JedaAccessibilityService? = null

        fun sendUserToHome(): Boolean {
            return activeService?.performGlobalAction(GLOBAL_ACTION_HOME) ?: false
        }

        fun clearBlockedState() {
            activeService?.let {
                it.currentlyBlockedPackage = ""
                it.lastForegroundPackage = ""
                it.lastBlockedOverlayShownTime = 0L
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        initServiceState()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        initServiceState()
    }

    private fun initServiceState() {
        isServiceRunning = true
        activeService = this
        overlayManager = OverlayManager.getInstance(this)
        BlockRulesManager.loadRules(this)
        BootReceiver.scheduleWatchdogAlarm(this, 180_000L)
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
                    var currentPkg = lastForegroundPackage
                    if (currentPkg.isEmpty() || LauncherHelper.isLauncher(this@JedaAccessibilityService, currentPkg)) {
                        val activeNode = try { rootInActiveWindow } catch (e: Exception) { null }
                        val activePkg = activeNode?.packageName?.toString()
                        activeNode?.recycle()
                        if (!activePkg.isNullOrEmpty() && !LauncherHelper.isLauncherOrSystem(this@JedaAccessibilityService, activePkg)) {
                            currentPkg = activePkg
                            lastForegroundPackage = activePkg
                        } else {
                            // Fallback to UsageStatsHelper for video/SurfaceView apps like TikTok where rootInActiveWindow can be null
                            val usagePkg = UsageStatsHelper.getForegroundApp(this@JedaAccessibilityService)
                            if (!usagePkg.isNullOrEmpty() && !LauncherHelper.isLauncherOrSystem(this@JedaAccessibilityService, usagePkg)) {
                                currentPkg = usagePkg
                                lastForegroundPackage = usagePkg
                            }
                        }
                    }

                    // 1. Ignore if empty, Jeda's own overlay/views, or SystemUI
                    if (currentPkg.isEmpty() || currentPkg == this@JedaAccessibilityService.packageName || LauncherHelper.isSystemUi(currentPkg)) {
                        continue
                    }

                    // 2. If user is actually on the home screen launcher
                    if (LauncherHelper.isLauncher(this@JedaAccessibilityService, currentPkg)) {
                        val now = System.currentTimeMillis()
                        val homeClickedRecently = overlayManager.lastHomeClickTime >= lastBlockedOverlayShownTime
                        if (overlayManager.isShowing() && (homeClickedRecently || now - lastBlockedOverlayShownTime > 1500L)) {
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

                    // 3. Quota tracking: Every 1 second in foreground (debounced in BlockRulesManager)
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

                    // 4. Blocking check
                    val isBlocked = BlockRulesManager.isAppBlocked(currentPkg, this@JedaAccessibilityService)

                    if (isBlocked) {
                        if (!overlayManager.isShowing()) {
                            currentlyBlockedPackage = currentPkg
                            lastBlockedOverlayShownTime = System.currentTimeMillis()
                            overlayManager.showOverlay(currentPkg)
                            broadcastBlockedEvent(currentPkg)
                        }
                    } else {
                        // Only hide if the blocked app is no longer blocked (e.g. expired) or user switched to an allowed app
                        if (overlayManager.isShowing() && !BlockRulesManager.isAppBlocked(currentlyBlockedPackage, this@JedaAccessibilityService)) {
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
        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            return
        }

        var packageName = event.packageName?.toString()
        val isFromRootFallback = packageName.isNullOrEmpty()
        if (isFromRootFallback) {
            val rootNode = try { rootInActiveWindow } catch (e: Exception) { null }
            packageName = rootNode?.packageName?.toString()
            rootNode?.recycle()
        }
        if (packageName.isNullOrEmpty()) return

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

        // === 2. Skip our own package (DO NOT hide overlay when our own overlay view is showing!) ===
        if (packageName == this.packageName) {
            return
        }

        // === 3. Skip System UI (notifications shade, status bar, volume dialog) ===
        if (LauncherHelper.isSystemUi(packageName)) {
            return
        }

        // === 4. Launcher check: If user actually navigated to Launcher/Home, hide overlay ===
        if (LauncherHelper.isLauncher(this, packageName)) {
            // Ignore spurious TYPE_WINDOWS_CHANGED rootInActiveWindow launcher reads when overlay just attached
            if (isFromRootFallback && overlayManager.isShowing()) {
                return
            }
            val now = System.currentTimeMillis()
            val homeClickedRecently = overlayManager.lastHomeClickTime >= lastBlockedOverlayShownTime
            if (!homeClickedRecently && now - lastBlockedOverlayShownTime < 1200L) {
                // Ignore trailing launcher animation event right after user tapped a blocked app icon
                return
            }
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
            lastForegroundPackage = packageName
            return
        }

        // Update last foreground package
        lastForegroundPackage = packageName

        // === 5. App Blocking Logic ===
        val isBlocked = BlockRulesManager.isAppBlocked(packageName, this)

        if (isBlocked) {
            currentlyBlockedPackage = packageName
            lastBlockedOverlayShownTime = System.currentTimeMillis()
            if (!overlayManager.isShowing()) {
                overlayManager.showOverlay(packageName)
                broadcastBlockedEvent(packageName)
            }
        } else {
            // App is NOT blocked. If user switched to an allowed app, hide overlay.
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

    override fun onUnbind(intent: Intent?): Boolean {
        isServiceRunning = false
        activeService = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceRunning = false
        activeService = null
        safetyCheckJob?.cancel()
        scope.cancel()
    }
}
