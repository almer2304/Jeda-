package com.mindfullock.app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

object BlockRulesManager {
    private val blockedRules = mutableListOf<JSONObject>()

    fun loadRules(context: Context) {
        try {
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("blocked_rules_json", null)
            if (jsonString != null) {
                updateRules(jsonString)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun updateRules(jsonString: String) {
        try {
            val array = JSONArray(jsonString)
            blockedRules.clear()
            for (i in 0 until array.length()) {
                blockedRules.add(array.getJSONObject(i))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun getRuleForPackage(packageName: String): JSONObject? {
        for (rule in blockedRules) {
            if (rule.optString("packageName") == packageName) {
                return rule
            }
        }
        return null
    }

    fun isAppBlocked(packageName: String, context: Context? = null): Boolean {
        if (blockedRules.isEmpty() && context != null) {
            loadRules(context)
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
            var dayMatch = false
            for (i in 0 until daysArray.length()) {
                if (daysArray.getInt(i) == currentDay) {
                    dayMatch = true
                    break
                }
            }
            
            if (dayMatch) {
                if (startMin <= endMin) {
                    if (currentTimeMin in startMin..endMin) return true
                } else {
                    if (currentTimeMin >= startMin || currentTimeMin <= endMin) return true
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

    fun incrementQuotaUsage(packageName: String, seconds: Int) {
        for (rule in blockedRules) {
            if (rule.optString("packageName") == packageName && rule.optBoolean("isQuota", false)) {
                val current = rule.optInt("usedTodaySeconds", 0)
                rule.put("usedTodaySeconds", current + seconds)
            }
        }
    }
}
