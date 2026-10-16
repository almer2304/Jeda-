package com.mindfullock.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class OverlayManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val mainHandler = Handler(Looper.getMainLooper())
    
    private var overlayView: View? = null
    @Volatile
    private var isOverlayShowing = false
    private var countDownTimer: CountDownTimer? = null
    private var pendingHomeHideRunnable: Runnable? = null

    @Volatile
    var lastHomeClickTime = 0L
        private set
    @Volatile
    var lastBlockedPackageName = ""
        private set
    @Volatile
    private var lastAttemptIncrementTime = 0L

    companion object {
        @Volatile
        private var instance: OverlayManager? = null

        fun getInstance(context: Context): OverlayManager {
            return instance ?: synchronized(this) {
                instance ?: OverlayManager(context.applicationContext).also { instance = it }
            }
        }
    }

    fun notifyHomeClicked() {
        lastHomeClickTime = System.currentTimeMillis()
    }

    fun clearHomeClickState() {
        lastHomeClickTime = 0L
        lastBlockedPackageName = ""
    }

    fun isExitingBlockedApp(packageName: String): Boolean {
        return false
    }

    fun showOverlay(packageName: String) {
        if (LauncherHelper.isLauncherOrSystem(appContext, packageName)) {
            hideOverlay()
            return
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            showOverlayInternal(packageName)
        } else {
            mainHandler.post {
                showOverlayInternal(packageName)
            }
        }
    }

    private fun showOverlayInternal(packageName: String) {
        if (LauncherHelper.isLauncherOrSystem(appContext, packageName)) {
            hideOverlayInternal()
            return
        }

        pendingHomeHideRunnable?.let {
            mainHandler.removeCallbacks(it)
            pendingHomeHideRunnable = null
        }

        // Sync state: if view is gone but flag is stale, reset
        if (isOverlayShowing && overlayView == null) {
            isOverlayShowing = false
        }

        if (isOverlayShowing) return
        if (!isPermissionGranted()) return

        lastBlockedPackageName = packageName

        val ruleInfo = BlockRulesManager.getRuleForPackage(packageName)
        val isQuota = ruleInfo?.optBoolean("isQuota", false) ?: false
        val dailyCount = incrementAndGetDailyAttemptCount()

        try {
            val windowLayoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            )
            windowLayoutParams.gravity = Gravity.CENTER

            val rootLayout = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#F5F0E8"))
            }

            var appIconView: View? = null
            try {
                val iconDrawable = appContext.packageManager.getApplicationIcon(packageName)
                val iconSize = (72 * appContext.resources.displayMetrics.density).toInt()
                appIconView = ImageView(appContext).apply {
                    setImageDrawable(iconDrawable)
                    layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                        bottomMargin = (8 * appContext.resources.displayMetrics.density).toInt()
                    }
                }
            } catch (e: Exception) {
                appIconView = null
            }

            val emojiText = TextView(appContext).apply {
                text = if (isQuota) "⏳" else "🌿"
                textSize = 64f
                gravity = Gravity.CENTER
            }

            val titleText = TextView(appContext).apply {
                text = if (isQuota) "Jatah Waktu Harian Habis" else "Hei, kamu sedang dalam mode fokus"
                textSize = 20f
                setTextColor(Color.parseColor("#2D2D2D"))
                paint.isFakeBoldText = true
                gravity = Gravity.CENTER
                setPadding(0, 32, 0, 16)
            }

            val groupName = ruleInfo?.optString("groupName", "aplikasi ini") ?: "aplikasi ini"
            val appLabel = resolveAppLabel(packageName, groupName)
            val focusGoal = ruleInfo?.optString("focusGoal", "") ?: ""
            val userDescription = ruleInfo?.optString("description", "") ?: ""

            val subText = TextView(appContext).apply {
                text = if (isQuota)
                    "Kamu telah menggunakan jatah waktu harian untuk $appLabel. Gunakan waktumu dengan bijak hari ini 🌱"
                else
                    "Kamu memilih mengunci $appLabel demi ketenangan dan fokusmu. Tarik napas sejenak sebelum memutuskan."
                textSize = 14f
                setTextColor(Color.parseColor("#2D2D2D"))
                gravity = Gravity.CENTER
                setPadding(36, 0, 36, 12)
                textAlignment = View.TEXT_ALIGNMENT_CENTER
            }

            var psychBox: LinearLayout? = null
            if (focusGoal.isNotEmpty() || userDescription.isNotEmpty()) {
                psychBox = LinearLayout(appContext).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setBackgroundColor(Color.parseColor("#EAE3D5"))
                    setPadding(36, 24, 36, 24)
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        setMargins(64, 4, 64, 16)
                    }
                    if (focusGoal.isNotEmpty()) {
                        addView(TextView(appContext).apply {
                            text = "🎯 Tujuan Fokusmu: $focusGoal"
                            textSize = 13f
                            setTextColor(Color.parseColor("#2D2D2D"))
                            paint.isFakeBoldText = true
                            gravity = Gravity.CENTER
                            textAlignment = View.TEXT_ALIGNMENT_CENTER
                        })
                    }
                    if (userDescription.isNotEmpty()) {
                        addView(TextView(appContext).apply {
                            text = "“$userDescription”"
                            textSize = 12f
                            setTextColor(Color.parseColor("#5A554C"))
                            gravity = Gravity.CENTER
                            textAlignment = View.TEXT_ALIGNMENT_CENTER
                            setPadding(0, if (focusGoal.isNotEmpty()) 8 else 0, 0, 0)
                        })
                    }
                }
            }

            val toleranceText = TextView(appContext).apply {
                text = if (dailyCount < 5) {
                    "🌱 Toleransi lupa hari ini: $dailyCount/4 kali (Streak fokusmu masih aman)"
                } else {
                    "⚠️ Batas toleransi terlampaui ($dailyCount kali hari ini). Streak fokusmu terputus!"
                }
                textSize = 12f
                setTextColor(if (dailyCount < 5) Color.parseColor("#5C7A50") else Color.parseColor("#C94A4A"))
                paint.isFakeBoldText = true
                gravity = Gravity.CENTER
                setPadding(40, 0, 40, 28)
                textAlignment = View.TEXT_ALIGNMENT_CENTER
            }

            val btnContainer = LinearLayout(appContext).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(64, 0, 64, 0)
                }
            }

            val backButton = Button(appContext).apply {
                text = "Kembali ke Beranda"
                setBackgroundColor(Color.parseColor("#87A878"))
                setTextColor(Color.WHITE)
                setOnClickListener {
                    notifyHomeClicked()
                    UsageStatsHelper.resetCache()
                    JedaAccessibilityService.clearBlockedState()

                    val sentHome = JedaAccessibilityService.sendUserToHome()
                    if (!sentHome) {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                        }
                        appContext.startActivity(homeIntent)
                    }

                    // Keep overlay view briefly during OS transition to launcher, then cleanly remove
                    pendingHomeHideRunnable?.let { mainHandler.removeCallbacks(it) }
                    val hideRunnable = Runnable {
                        hideOverlayInternal()
                        pendingHomeHideRunnable = null
                    }
                    pendingHomeHideRunnable = hideRunnable
                    mainHandler.postDelayed(hideRunnable, 150)

                    // If user exceeded tolerance (>= 5 times), pop a WhatsApp-style heads-up notification on Home Screen
                    if (dailyCount >= 5) {
                        mainHandler.postDelayed({
                            showToleranceExceededHeadsUpNotification(packageName, appLabel, dailyCount)
                        }, 400)
                    }
                }
            }
            btnContainer.addView(backButton)

            if (isQuota) {
                val emergencyTickets = ruleInfo?.optInt("emergencyTickets", 0) ?: 0
                val quotaId = ruleInfo?.optString("quotaId", "") ?: ""

                if (emergencyTickets > 0) {
                    val ticketInfoText = TextView(appContext).apply {
                        text = "🎫 Stok Pas Darurat: $emergencyTickets/2 minggu ini"
                        textSize = 12f
                        setTextColor(Color.parseColor("#666666"))
                        gravity = Gravity.CENTER
                        setPadding(0, 16, 0, 8)
                    }

                    val emergencyButton = Button(appContext).apply {
                        text = "Gunakan Pas Darurat (5 Menit)"
                        setBackgroundColor(Color.parseColor("#D9822B"))
                        setTextColor(Color.WHITE)
                        val params = LinearLayout.LayoutParams(
                            LinearLayout.LayoutParams.MATCH_PARENT,
                            LinearLayout.LayoutParams.WRAP_CONTENT
                        ).apply {
                            setMargins(0, 16, 0, 0)
                        }
                        layoutParams = params
                    }

                    emergencyButton.setOnClickListener {
                        emergencyButton.isEnabled = false
                        ticketInfoText.text = "⏳ Mohon tunggu 90 detik (Pendingin Impuls)..."
                        ticketInfoText.setTextColor(Color.parseColor("#D9822B"))

                        countDownTimer?.cancel()
                        countDownTimer = object : CountDownTimer(90000, 1000) {
                            override fun onTick(millisUntilFinished: Long) {
                                val seconds = millisUntilFinished / 1000
                                emergencyButton.text = "Tersisa $seconds detik..."
                            }

                            override fun onFinish() {
                                emergencyButton.isEnabled = true
                                emergencyButton.text = "Buka Akses 5 Menit 🌱"
                                emergencyButton.setBackgroundColor(Color.parseColor("#4CAF50"))

                                emergencyButton.setOnClickListener {
                                    val intent = Intent("USE_EMERGENCY_TICKET")
                                    intent.putExtra("quota_id", quotaId)
                                    intent.putExtra("duration_minutes", 5)
                                    LocalBroadcastManager.getInstance(appContext).sendBroadcast(intent)

                                    ruleInfo?.put("emergencyUntilMillis", System.currentTimeMillis() + (5 * 60 * 1000))
                                    val currentTickets = ruleInfo?.optInt("emergencyTickets", 1) ?: 1
                                    ruleInfo?.put("emergencyTickets", currentTickets - 1)

                                    hideOverlayInternal()
                                }
                            }
                        }.start()
                    }

                    btnContainer.addView(ticketInfoText)
                    btnContainer.addView(emergencyButton)
                } else {
                    val noTicketText = TextView(appContext).apply {
                        text = "❌ Pas Darurat minggu ini sudah habis (0/2). Istirahatlah sejenak 🌱"
                        textSize = 12f
                        setTextColor(Color.RED)
                        gravity = Gravity.CENTER
                        setPadding(0, 16, 0, 0)
                    }
                    btnContainer.addView(noTicketText)
                }
            }

            if (appIconView != null) {
                rootLayout.addView(appIconView)
            } else {
                rootLayout.addView(emojiText)
            }
            rootLayout.addView(titleText)
            rootLayout.addView(subText)
            psychBox?.let { rootLayout.addView(it) }
            rootLayout.addView(toleranceText)
            rootLayout.addView(btnContainer)

            rootLayout.viewTreeObserver.addOnWindowAttachListener(object : ViewTreeObserver.OnWindowAttachListener {
                override fun onWindowAttached() {
                    isOverlayShowing = true
                }
                override fun onWindowDetached() {
                    isOverlayShowing = false
                    overlayView = null
                    countDownTimer?.cancel()
                    countDownTimer = null
                }
            })

            overlayView = rootLayout
            windowManager.addView(overlayView, windowLayoutParams)
            isOverlayShowing = true

            if (dailyCount >= 5) {
                showToleranceExceededHeadsUpNotification(packageName, appLabel, dailyCount)
            }

        } catch (e: WindowManager.BadTokenException) {
            isOverlayShowing = false
            overlayView = null
            e.printStackTrace()
        } catch (e: Exception) {
            isOverlayShowing = false
            overlayView = null
            e.printStackTrace()
        }
    }

    private fun incrementAndGetDailyAttemptCount(): Int {
        val prefs = appContext.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val savedDate = prefs.getString("daily_attempt_date", "") ?: ""
        var count = if (savedDate == today) prefs.getInt("daily_attempt_count", 0) else 0

        val now = System.currentTimeMillis()
        if (now - lastAttemptIncrementTime > 3000L) {
            count += 1
            lastAttemptIncrementTime = now
            prefs.edit()
                .putString("daily_attempt_date", today)
                .putInt("daily_attempt_count", count)
                .apply()
        }
        return count.coerceAtLeast(1)
    }

    private fun resolveAppLabel(packageName: String, fallback: String): String {
        return try {
            val pm = appContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            fallback
        }
    }

    private fun showToleranceExceededHeadsUpNotification(packageName: String, appLabel: String, attemptCount: Int) {
        try {
            val notificationManager = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "jeda_streak_heads_up_v2"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "Peringatan Streak & Fokus",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifikasi pop-up saat batas toleransi membuka aplikasi terkunci terlampaui"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 300, 150, 300)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }

            val pendingIntent = if (launchIntent != null) {
                PendingIntent.getActivity(
                    appContext,
                    2005,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )
            } else null

            val title = "⚠️ Batas Toleransi Terlampaui (${attemptCount}x Hari Ini)"
            val shortBody = "Kamu sudah $attemptCount kali mencoba membuka $appLabel. Streak fokusmu terputus!"
            val bigBody = "Kamu sudah $attemptCount kali mencoba membuka $appLabel yang sedang dikunci hari ini (batas toleransi lupa maks. 4x). Streak fokusmu telah di-reset. Yuk simpan HP-mu dan kembali fokus! 🌱"

            val builder = NotificationCompat.Builder(appContext, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(shortBody)
                .setStyle(NotificationCompat.BigTextStyle().bigText(bigBody))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVibrate(longArrayOf(0, 300, 150, 300))
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setAutoCancel(true)

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent)
            }

            notificationManager.notify(9005, builder.build())
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun hideOverlay() {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            hideOverlayInternal()
        } else {
            mainHandler.post {
                hideOverlayInternal()
            }
        }
    }

    private fun hideOverlayInternal() {
        try {
            pendingHomeHideRunnable?.let {
                mainHandler.removeCallbacks(it)
                pendingHomeHideRunnable = null
            }
            countDownTimer?.cancel()
            countDownTimer = null
            if (overlayView != null) {
                try {
                    windowManager.removeView(overlayView)
                } catch (e: Exception) {
                }
                overlayView = null
                isOverlayShowing = false
            } else {
                isOverlayShowing = false
            }
        } catch (e: Exception) {
            isOverlayShowing = false
            overlayView = null
            e.printStackTrace()
        }
    }

    fun isShowing(): Boolean {
        if (overlayView == null) {
            isOverlayShowing = false
        }
        return isOverlayShowing
    }

    fun isPermissionGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(appContext)
        } else {
            true
        }
    }
}