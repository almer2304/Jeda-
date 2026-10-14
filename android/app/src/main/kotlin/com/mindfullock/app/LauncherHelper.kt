package com.mindfullock.app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager

object LauncherHelper {
    private val cachedLaunchers = mutableSetOf<String>()
    private var lastQueryTime = 0L

    private val knownLauncherKeywords = listOf(
        "launcher",
        "home",
        "desktop",
        "dlauncher",
        "hilauncher",
        "xoslauncher",
        "quickstep"
    )

    private val systemUiPackages = setOf(
        "com.android.systemui",
        "com.google.android.systemui",
        "com.transsion.systemui",
        "com.itel.systemui",
        "android"
    )

    fun isSystemUi(packageName: String?): Boolean {
        if (packageName.isNullOrEmpty()) return false
        return systemUiPackages.any { packageName.startsWith(it, ignoreCase = true) }
    }

    fun isLauncherOrSystem(context: Context, packageName: String?): Boolean {
        if (packageName.isNullOrEmpty()) return true
        if (packageName == context.packageName) return true
        if (isSystemUi(packageName)) return true
        return isLauncher(context, packageName)
    }

    fun isLauncher(context: Context, packageName: String?): Boolean {
        if (packageName.isNullOrEmpty()) return false

        val now = System.currentTimeMillis()
        if (cachedLaunchers.isEmpty() || now - lastQueryTime > 15000) {
            try {
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                }
                val resolveInfos = context.packageManager.queryIntentActivities(
                    intent,
                    PackageManager.MATCH_ALL
                )
                for (info in resolveInfos) {
                    info.activityInfo?.packageName?.let {
                        cachedLaunchers.add(it)
                    }
                }

                val defaultInfo = context.packageManager.resolveActivity(
                    intent,
                    PackageManager.MATCH_DEFAULT_ONLY
                )
                defaultInfo?.activityInfo?.packageName?.let {
                    cachedLaunchers.add(it)
                }
                lastQueryTime = now
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        if (cachedLaunchers.contains(packageName)) return true

        val lower = packageName.lowercase()
        return knownLauncherKeywords.any { lower.contains(it) } ||
                (packageName.startsWith("com.transsion.") && (lower.contains("launcher") || lower.contains("home"))) ||
                (packageName.startsWith("com.itel.") && (lower.contains("launcher") || lower.contains("home")))
    }
}
