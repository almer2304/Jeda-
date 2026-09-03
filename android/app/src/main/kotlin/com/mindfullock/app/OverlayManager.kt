package com.mindfullock.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.json.JSONObject

class OverlayManager(private val context: Context) {
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null
    private var isOverlayShowing = false
    private var countDownTimer: CountDownTimer? = null

    @Volatile
    var lastHomeClickTime = 0L
        private set
    @Volatile
    var lastBlockedPackageName = ""
        private set

    fun notifyHomeClicked() {
        lastHomeClickTime = System.currentTimeMillis()
    }

    fun clearHomeClickState() {
        lastHomeClickTime = 0L
        lastBlockedPackageName = ""
    }

    fun isExitingBlockedApp(packageName: String): Boolean {
        if (lastHomeClickTime == 0L) return false
        val elapsed = System.currentTimeMillis() - lastHomeClickTime
        return elapsed < 600 && packageName == lastBlockedPackageName
    }

    fun showOverlay(packageName: String) {
        if (isExitingBlockedApp(packageName)) return

        // Sync state: if view is gone but flag is stale, reset
        if (isOverlayShowing && overlayView == null) {
            isOverlayShowing = false
        }

        // If overlay is already showing for this package, do nothing
        if (isOverlayShowing) return

        if (!isPermissionGranted()) return

        lastBlockedPackageName = packageName

        val ruleInfo = BlockRulesManager.getRuleForPackage(packageName)
        val isQuota = ruleInfo?.optBoolean("isQuota", false) ?: false

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

            val rootLayout = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#F5F0E8"))
            }

            val emojiText = TextView(context).apply {
                text = if (isQuota) "⏳" else "🌿"
                textSize = 64f
                gravity = Gravity.CENTER
            }

            val titleText = TextView(context).apply {
                text = if (isQuota) "Jatah Waktu Harian Habis" else "Hei, kamu sedang dalam mode fokus"
                textSize = 20f
                setTextColor(Color.parseColor("#2D2D2D"))
                paint.isFakeBoldText = true
                gravity = Gravity.CENTER
                setPadding(0, 32, 0, 16)
            }

            val groupName = ruleInfo?.optString("groupName", "aplikasi ini") ?: "aplikasi ini"
            val subText = TextView(context).apply {
                text = if (isQuota)
                    "Kamu telah menggunakan jatah waktu harian untuk $groupName. Gunakan waktumu dengan bijak hari ini 🌱"
                else
                    "Kamu memilih mengunci $groupName. Tunggu sampai waktunya habis ya!"
                textSize = 14f
                setTextColor(Color.parseColor("#2D2D2D"))
                gravity = Gravity.CENTER
                setPadding(32, 0, 32, 32)
                textAlignment = View.TEXT_ALIGNMENT_CENTER
            }

            val btnContainer = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(64, 0, 64, 0)
                }
            }

            val backButton = Button(context).apply {
                text = "Kembali ke Beranda"
                setBackgroundColor(Color.parseColor("#87A878"))
                setTextColor(Color.WHITE)
                setOnClickListener {
                    notifyHomeClicked()
                    hideOverlay()
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(homeIntent)
                }
            }
            btnContainer.addView(backButton)

            if (isQuota) {
                val emergencyTickets = ruleInfo?.optInt("emergencyTickets", 0) ?: 0
                val quotaId = ruleInfo?.optString("quotaId", "") ?: ""

                if (emergencyTickets > 0) {
                    val ticketInfoText = TextView(context).apply {
                        text = "🎫 Stok Pas Darurat: $emergencyTickets/2 minggu ini"
                        textSize = 12f
                        setTextColor(Color.parseColor("#666666"))
                        gravity = Gravity.CENTER
                        setPadding(0, 16, 0, 8)
                    }

                    val emergencyButton = Button(context).apply {
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
                                    LocalBroadcastManager.getInstance(context).sendBroadcast(intent)

                                    ruleInfo?.put("emergencyUntilMillis", System.currentTimeMillis() + (5 * 60 * 1000))
                                    val currentTickets = ruleInfo?.optInt("emergencyTickets", 1) ?: 1
                                    ruleInfo?.put("emergencyTickets", currentTickets - 1)

                                    hideOverlay()
                                }
                            }
                        }.start()
                    }

                    btnContainer.addView(ticketInfoText)
                    btnContainer.addView(emergencyButton)
                } else {
                    val noTicketText = TextView(context).apply {
                        text = "❌ Pas Darurat minggu ini sudah habis (0/2). Istirahatlah sejenak 🌱"
                        textSize = 12f
                        setTextColor(Color.RED)
                        gravity = Gravity.CENTER
                        setPadding(0, 16, 0, 0)
                    }
                    btnContainer.addView(noTicketText)
                }
            }

            rootLayout.addView(emojiText)
            rootLayout.addView(titleText)
            rootLayout.addView(subText)
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

    fun hideOverlay() {
        try {
            countDownTimer?.cancel()
            countDownTimer = null
            if (overlayView != null) {
                try {
                    windowManager.removeView(overlayView)
                } catch (e: IllegalArgumentException) {
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
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }
}