package com.mindfullock.app

import android.content.Context
import android.content.Intent
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object BlockRulesManager {
    private val blockedRules = mutableListOf<JSONObject>()
    @Volatile
    private var lastLoadedJson: String? = null
    @Volatile
    private var lastQuotaTickMillis: Long = 0L

    private fun getTodayDateString(): String {
        val calendar = Calendar.getInstance()
        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH) + 1
        val day = calendar.get(Calendar.DAY_OF_MONTH)
        return String.format("%04d-%02d-%02d", year, month, day)
    }

    @Synchronized
    fun checkAndResetDailyQuotas(context: Context? = null) {
        val todayStr = getTodayDateString()
        var updated = false
        for (rule in blockedRules) {
            if (rule.optBoolean("isQuota", false)) {
                val lastResetDate = rule.optString("lastResetDate", "")
                if (lastResetDate != todayStr) {
                    rule.put("usedTodaySeconds", 0)
                    rule.put("lastResetDate", todayStr)
                    updated = true
                }
            }
        }
        if (updated && context != null) {
            try {
                val jsonArray = JSONArray(blockedRules)
                val newJson = jsonArray.toString()
                lastLoadedJson = newJson
                val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                prefs.edit().putString("blocked_rules_json", newJson).apply()

                val intent = Intent("QUOTA_RESET_EVENT")
                LocalBroadcastManager.getInstance(context).sendBroadcast(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    @Synchronized
    fun loadRules(context: Context) {
        try {
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("blocked_rules_json", null)
            if (jsonString != null) {
                if (jsonString != lastLoadedJson || blockedRules.isEmpty()) {
                    updateRules(jsonString)
                }
            }
            checkAndResetDailyQuotas(context)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Synchronized
    fun updateRules(jsonString: String) {
        try {
            val array = JSONArray(jsonString)
            blockedRules.clear()
            for (i in 0 until array.length()) {
                blockedRules.add(array.getJSONObject(i))
            }
            lastLoadedJson = jsonString
            checkAndResetDailyQuotas(null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Synchronized
    fun getRuleForPackage(packageName: String): JSONObject? {
        var fallback: JSONObject? = null
        for (rule in blockedRules) {
            if (rule.optString("packageName") == packageName) {
                if (checkRuleBlocked(rule)) {
                    return rule
                }
                if (fallback == null) {
                    fallback = rule
                }
            }
        }
        return fallback
    }

    @Synchronized
    fun isAppBlocked(packageName: String, context: Context? = null): Boolean {
        if (context != null) {
            loadRules(context)
        } else {
            checkAndResetDailyQuotas(null)
        }

        for (rule in blockedRules) {
            if (rule.optString("packageName") == packageName) {
                if (checkRuleBlocked(rule)) {
                    return true
                }
            }
        }
        return false
    }

    @Synchronized
    fun hasAnyActiveRules(context: Context): Boolean {
        loadRules(context)
        return blockedRules.isNotEmpty()
    }

    private fun checkRuleBlocked(rule: JSONObject): Boolean {
        val isQuota = rule.optBoolean("isQuota", false)
        if (isQuota) {
            val emergencyUntilMillis = rule.optLong("emergencyUntilMillis", 0)
            if (System.currentTimeMillis() < emergencyUntilMillis) {
                return false // Emergency pass active
            }
            val dailyQuotaSeconds = rule.optInt("dailyQuotaSeconds", 0)
            val usedTodaySeconds = rule.optInt("usedTodaySeconds", 0)
            return usedTodaySeconds >= dailyQuotaSeconds
        }

        val isScheduled = rule.optBoolean("isScheduled", false)
        if (isScheduled) {
            val calendar = Calendar.getInstance()
            val currentDay = calendar.get(Calendar.DAY_OF_WEEK)
            val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
            val currentMinute = calendar.get(Calendar.MINUTE)
            val currentTimeMin = currentHour * 60 + currentMinute
            
            val startMin = rule.optInt("startHour") * 60 + rule.optInt("startMinute")
            val endMin = rule.optInt("endHour") * 60 + rule.optInt("endMinute")
            
            val daysArray = rule.optJSONArray("days") ?: JSONArray()
            val hasDay: (Int) -> Boolean = { day ->
                var found = false
                for (i in 0 until daysArray.length()) {
                    if (daysArray.getInt(i) == day) {
                        found = true
                        break
                    }
                }
                found
            }
            
            if (startMin <= endMin) {
                if (hasDay(currentDay) && currentTimeMin in startMin..endMin) {
                    return true
                }
            } else {
                // Interval crosses midnight (e.g. 19:30 to 16:35)
                // Part A: Started today before midnight
                if (hasDay(currentDay) && currentTimeMin >= startMin) {
                    return true
                }
                // Part B: Started yesterday and ending today after midnight
                val prevDay = if (currentDay == Calendar.SUNDAY) Calendar.SATURDAY else currentDay - 1
                if (hasDay(prevDay) && currentTimeMin <= endMin) {
                    return true
                }
            }
        } else {
            val endTime = rule.optLong("endTimeMillis", 0)
            if (endTime == 0L || System.currentTimeMillis() < endTime) {
                return true
            }
        }
        return false
    }

    @Synchronized
    fun incrementQuotaUsage(packageName: String, seconds: Int, context: Context? = null) {
        val now = System.currentTimeMillis()
        if (now - lastQuotaTickMillis < 850L) {
            return // Debounce when both AccessibilityService and AppMonitorService are active
        }
        lastQuotaTickMillis = now

        if (context != null) {
            loadRules(context)
        } else {
            checkAndResetDailyQuotas(null)
        }

        var updated = false
        for (rule in blockedRules) {
            if (rule.optString("packageName") == packageName && rule.optBoolean("isQuota", false)) {
                val current = rule.optInt("usedTodaySeconds", 0)
                rule.put("usedTodaySeconds", current + seconds)
                updated = true
            }
        }
        if (updated && context != null) {
            try {
                val jsonArray = JSONArray(blockedRules)
                val newJson = jsonArray.toString()
                lastLoadedJson = newJson
                val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
                prefs.edit().putString("blocked_rules_json", newJson).apply()

                val intent = Intent("QUOTA_USAGE_TICK")
                intent.putExtra("package_name", packageName)
                intent.putExtra("seconds", seconds)
                LocalBroadcastManager.getInstance(context).sendBroadcast(intent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
