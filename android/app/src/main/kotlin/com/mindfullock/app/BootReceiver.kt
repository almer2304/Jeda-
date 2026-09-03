package com.mindfullock.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == "android.intent.action.QUICKBOOT_POWERON" || 
            action == "com.htc.intent.action.QUICKBOOT_POWERON" ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            
            // 1. Restart App Monitor Service if rules exist
            val jsonString = prefs.getString("blocked_rules_json", null)
            if (jsonString != null && jsonString != "[]") {
                val serviceIntent = Intent(context, AppMonitorService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }

            // 2. Restart DNS Filter (VPN) if it was enabled
            val dnsEnabled = prefs.getBoolean("dns_filter_enabled", false)
            if (dnsEnabled) {
                val dnsIntent = Intent(context, DnsFilterService::class.java)
                context.startService(dnsIntent)
            }
        }
    }
}