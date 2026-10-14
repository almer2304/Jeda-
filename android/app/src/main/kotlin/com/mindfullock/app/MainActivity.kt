package com.mindfullock.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.provider.Settings.Secure
import android.text.TextUtils
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.mindfullock/control"
    private val EVENT_CHANNEL = "com.mindfullock/app_events"
    private val VPN_REQUEST_CODE = 1001
    
    private var eventSink: EventChannel.EventSink? = null

    private val blockEventReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "APP_BLOCKED_EVENT") {
                val packageName = intent.getStringExtra("package_name")
                if (packageName != null) {
                    runOnUiThread {
                        eventSink?.success(packageName)
                    }
                }
            } else if (intent?.action == "JEDA_ADMIN_DISABLE_REQUESTED") {
                runOnUiThread {
                    eventSink?.success("ADMIN_DISABLE_REQUESTED")
                }
            } else if (intent?.action == "USE_EMERGENCY_TICKET") {
                val quotaId = intent.getStringExtra("quota_id") ?: ""
                val durationMinutes = intent.getIntExtra("duration_minutes", 5)
                runOnUiThread {
                    eventSink?.success("EMERGENCY_TICKET_USED:$quotaId:$durationMinutes")
                }
            } else if (intent?.action == "QUOTA_USAGE_TICK") {
                val packageName = intent.getStringExtra("package_name") ?: ""
                val seconds = intent.getIntExtra("seconds", 0)
                runOnUiThread {
                    eventSink?.success("QUOTA_USAGE:$packageName:$seconds")
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkAndSendAdminAttempt(intent)
    }

    override fun onResume() {
        super.onResume()
        checkAndSendAdminAttempt(intent)
    }

    private fun checkAndSendAdminAttempt(currIntent: Intent?) {
        if (currIntent?.getStringExtra("action") == "ADMIN_DISABLE_ATTEMPT" ||
            currIntent?.getStringExtra("route") == "/forced_uninstall_warning") {
            currIntent.removeExtra("action")
            currIntent.removeExtra("route")
            runOnUiThread {
                eventSink?.success("ADMIN_DISABLE_REQUESTED")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val filter = IntentFilter()
        filter.addAction("APP_BLOCKED_EVENT")
        filter.addAction("JEDA_ADMIN_DISABLE_REQUESTED")
        filter.addAction("USE_EMERGENCY_TICKET")
        filter.addAction("QUOTA_USAGE_TICK")
        LocalBroadcastManager.getInstance(this).registerReceiver(blockEventReceiver, filter)
        // Also register globally for the device admin broadcast
        registerReceiver(blockEventReceiver, IntentFilter("JEDA_ADMIN_DISABLE_REQUESTED"))

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startMonitoring" -> {
                        val args = call.arguments as? Map<*, *>
                        val blockedRules = args?.get("blocked_packages") as? List<Map<String, Any>>
                        val intent = Intent(this, AppMonitorService::class.java)
                        if (blockedRules != null) {
                            val jsonArray = JSONArray()
                            for (map in blockedRules) {
                                val obj = JSONObject()
                                for ((k, v) in map) {
                                    if (v is List<*>) {
                                        val innerArray = JSONArray()
                                        for (item in v) innerArray.put(item)
                                        obj.put(k, innerArray)
                                    } else {
                                        obj.put(k, v)
                                    }
                                }
                                jsonArray.put(obj)
                            }
                            intent.putExtra("blocked_packages", jsonArray.toString())
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopMonitoring" -> {
                        stopService(Intent(this, AppMonitorService::class.java))
                        result.success(null)
                    }
                    "updateBlockedList" -> {
                        val args = call.arguments as? Map<*, *>
                        val blockedRules = args?.get("blocked_packages") as? List<Map<String, Any>>
                        if (blockedRules != null) {
                            val jsonArray = JSONArray()
                            for (map in blockedRules) {
                                val obj = JSONObject()
                                for ((k, v) in map) {
                                    if (v is List<*>) {
                                        val innerArray = JSONArray()
                                        for (item in v) innerArray.put(item)
                                        obj.put(k, innerArray)
                                    } else {
                                        obj.put(k, v)
                                    }
                                }
                                jsonArray.put(obj)
                            }
                            val intent = Intent("UPDATE_BLOCKED_LIST")
                            intent.putExtra("blocked_packages", jsonArray.toString())
                            LocalBroadcastManager.getInstance(this).sendBroadcast(intent)
                        }
                        result.success(null)
                    }
                    "checkUsagePermission" -> {
                        result.success(UsageStatsHelper.isPermissionGranted(this))
                    }
                    "openUsageSettings" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "checkOverlayPermission" -> {
                        val overlayManager = OverlayManager.getInstance(this)
                        result.success(overlayManager.isPermissionGranted())
                    }
                    "openOverlaySettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                        }
                        result.success(null)
                    }
                    "checkBatteryOptimization" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        } else {
                            result.success(true)
                        }
                    }
                    "openBatterySettings" -> {
                        try {
                            val intent = Intent().apply {
                                setClassName("com.itel.powermanager", "com.itel.powermanager.PowerManagerActivity")
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                } else {
                                    startActivity(Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS))
                                }
                            } catch (e2: Exception) {
                                e2.printStackTrace()
                            }
                        }
                        result.success(null)
                    }
                    "getInstalledApps" -> {
                        val pm = packageManager
                        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                        val appList = mutableListOf<Map<String, String>>()
                        for (app in apps) {
                            // Filter out system apps
                            if ((app.flags and ApplicationInfo.FLAG_SYSTEM) == 0 && (app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) == 0) {
                                val appMap = mapOf(
                                    "name" to app.loadLabel(pm).toString(),
                                    "packageName" to app.packageName
                                )
                                appList.add(appMap)
                            }
                        }
                        result.success(appList)
                    }
                    "startVpnService" -> {
                        val vpnIntent = VpnService.prepare(this)
                        if (vpnIntent != null) {
                            startActivityForResult(vpnIntent, VPN_REQUEST_CODE)
                        } else {
                            DnsFilterService.start(this)
                        }
                        result.success(null)
                    }
                    "stopVpnService" -> {
                        DnsFilterService.stop(this)
                        result.success(null)
                    }
                    "checkVpnStatus" -> {
                        result.success(DnsFilterService.isRunning)
                    }
                    "checkDeviceAdminPermission" -> {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val compName = ComponentName(this, JedaDeviceAdminReceiver::class.java)
                        result.success(dpm.isAdminActive(compName))
                    }
                    "requestDeviceAdminPermission" -> {
                        val compName = ComponentName(this, JedaDeviceAdminReceiver::class.java)
                        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, compName)
                        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Jeda membutuhkan ini agar tidak mudah dihapus saat Anda sedang terdistraksi.")
                        startActivity(intent)
                        result.success(null)
                    }
                    "checkAccessibilityPermission" -> {
                        var accessibilityEnabled = 0
                        val service = "$packageName/${JedaAccessibilityService::class.java.canonicalName}"
                        try {
                            accessibilityEnabled = Secure.getInt(contentResolver, android.provider.Settings.Secure.ACCESSIBILITY_ENABLED)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                        var isEnabled = false
                        if (accessibilityEnabled == 1) {
                            val settingValue = Secure.getString(contentResolver, Secure.ENABLED_ACCESSIBILITY_SERVICES)
                            if (settingValue != null) {
                                val splitter = TextUtils.SimpleStringSplitter(':')
                                splitter.setString(settingValue)
                                while (splitter.hasNext()) {
                                    val accessabilityService = splitter.next()
                                    if (accessabilityService.equals(service, ignoreCase = true)) {
                                        isEnabled = true
                                    }
                                }
                            }
                        }
                        result.success(isEnabled)
                    }
                    "requestAccessibilityPermission" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    }
                    "removeDeviceAdmin" -> {
                        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val compName = ComponentName(this, JedaDeviceAdminReceiver::class.java)
                        if (dpm.isAdminActive(compName)) {
                            dpm.removeActiveAdmin(compName)
                        }
                        result.success(null)
                    }
                    "getNativeQuotaUsage" -> {
                        BlockRulesManager.checkAndResetDailyQuotas(this)
                        val prefs = getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                        val jsonString = prefs.getString("blocked_rules_json", null)
                        val usageMap = mutableMapOf<String, Int>()
                        if (jsonString != null) {
                            try {
                                val array = JSONArray(jsonString)
                                for (i in 0 until array.length()) {
                                    val obj = array.getJSONObject(i)
                                    if (obj.optBoolean("isQuota", false)) {
                                        val pkg = obj.optString("packageName")
                                        val used = obj.optInt("usedTodaySeconds", 0)
                                        if (pkg.isNotEmpty()) {
                                            usageMap[pkg] = used
                                        }
                                    }
                                }
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                        result.success(usageMap)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("ERROR", e.message, null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE && resultCode == RESULT_OK) {
            DnsFilterService.start(this)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(blockEventReceiver)
    }
}
