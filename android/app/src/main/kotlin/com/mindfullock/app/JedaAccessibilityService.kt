package com.mindfullock.app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.PackageManager
import android.view.accessibility.AccessibilityEvent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import kotlinx.coroutines.*

class JedaAccessibilityService : AccessibilityService() {

    private lateinit var overlayManager: OverlayManager

    private var lastForegroundPackage: String = ""
    private var currentlyBlockedPackage: String = ""

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var safetyCheckJob: Job? = null

    // System UI packages (notification shade, status bar, recents menu)
    private val systemUiPackages = setOf(
        "com.android.systemui"
    )

    // Fallback launcher packages list
    private val launcherPackagesFallback = setOf(
        "com.android.launcher",
        "com.android.launcher2",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.sec.android.app.launcher",
        "com.miui.home",
        "com.huawei.android.launcher",
        "com.oppo.launcher",
        "com.vivo.launcher",
        "com.oneplus.launcher",
        "com.nothing.launcher",
        "com.transsion.hilauncher",
        "com.transsion.XOSLauncher",
        "com.teslacoilsw.launcher"
    )

    private fun isLauncherPackage(packageName: String): Boolean {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            val defaultLauncher = resolveInfo?.activityInfo?.packageName
            if (defaultLauncher != null && packageName == defaultLauncher) {
                return true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return launcherPackagesFallback.any { packageName.startsWith(it) }
    }

    override fun onCreate() {
        super.onCreate()
        overlayManager = OverlayManager(this)
        BlockRulesManager.loadRules(this)
        startSafetyCheckLoop()
    }

    private fun startSafetyCheckLoop() {
        safetyCheckJob?.cancel()
        safetyCheckJob = scope.launch {
            while (isActive) {
                delay(1500)
                try {
                    val foregroundPkg = UsageStatsHelper.getForegroundApp(this@JedaAccessibilityService)
                        ?: continue

                    if (foregroundPkg == this@JedaAccessibilityService.packageName) {
                        if (overlayManager.isShowing()) {
                            overlayManager.hideOverlay()
                            currentlyBlockedPackage = ""
                        }
                        continue
                    }

                    if (isLauncherPackage(foregroundPkg)) {
                        if (overlayManager.isShowing()) {
                            overlayManager.hideOverlay()
                            currentlyBlockedPackage = ""
                        }
                        continue
                    }

                    val isBlocked = BlockRulesManager.isAppBlocked(foregroundPkg)

                    if (isBlocked) {
                        if (!overlayManager.isShowing() && !overlayManager.isExitingBlockedApp(foregroundPkg)) {
                            currentlyBlockedPackage = foregroundPkg
                            overlayManager.showOverlay(foregroundPkg)
                            broadcastBlockedEvent(foregroundPkg)
                        }
                    } else {
                        if (overlayManager.isShowing()) {
                            if (!systemUiPackages.any { foregroundPkg.startsWith(it) }) {
                                overlayManager.hideOverlay()
                                currentlyBlockedPackage = ""
                            }
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
        // TYPE_WINDOWS_CHANGED triggers on every overlay/window buffer creation (gralloc allocation),
        // which was causing rapid show/hide glitching.
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
                    val launchIntent = packageManager.getLaunchIntentForPackage(this.packageName)
                    launchIntent?.let {
                        it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        it.putExtra("route", "/forced_uninstall_warning")
                        startActivity(it)
                    }
                }
                nodeInfo.recycle()
            }
        }

        // === 2. Skip our own package ===
        if (packageName == this.packageName) {
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
            return
        }

        // === 3. Launcher check ===
        if (isLauncherPackage(packageName)) {
            if (overlayManager.isShowing()) {
                overlayManager.hideOverlay()
                currentlyBlockedPackage = ""
            }
            return
        }

        // === 4. Pure System UI check ===
        val isSystemUi = systemUiPackages.any { packageName.startsWith(it) }
        if (isSystemUi) {
            return
        }

        // === 5. App Blocking Logic ===
        lastForegroundPackage = packageName
        val isBlocked = BlockRulesManager.isAppBlocked(packageName, this)

        if (isBlocked) {
            currentlyBlockedPackage = packageName
            if (!overlayManager.isShowing() && !overlayManager.isExitingBlockedApp(packageName)) {
                overlayManager.showOverlay(packageName)
                broadcastBlockedEvent(packageName)
            }
        } else {
            // App is NOT blocked. Ensure we don't prematurely hide overlay if the user is still in the blocked app
            if (overlayManager.isShowing()) {
                val currentBlocked = currentlyBlockedPackage
                scope.launch {
                    delay(200)
                    try {
                        val trueForeground = UsageStatsHelper.getForegroundApp(this@JedaAccessibilityService)
                        if (trueForeground != null) {
                            if (!BlockRulesManager.isAppBlocked(trueForeground, this@JedaAccessibilityService) &&
                                !systemUiPackages.any { trueForeground.startsWith(it) }) {
                                overlayManager.hideOverlay()
                                currentlyBlockedPackage = ""
                            }
                        } else if (currentBlocked.isNotEmpty() && !BlockRulesManager.isAppBlocked(packageName, this@JedaAccessibilityService)) {
                            overlayManager.hideOverlay()
                            currentlyBlockedPackage = ""
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
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
        safetyCheckJob?.cancel()
        scope.cancel()
    }
}
