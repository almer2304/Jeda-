package com.mindfullock.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager

class JedaDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence? {
        val broadcastIntent = Intent("JEDA_ADMIN_DISABLE_REQUESTED")
        LocalBroadcastManager.getInstance(context).sendBroadcast(broadcastIntent)
        context.sendBroadcast(broadcastIntent)

        showBypassWarningNotification(context)

        return "🛡️ PERINGATAN BODYGUARD:\nPenonaktifan paksa Device Admin tidak diizinkan dari pengaturan HP. Gunakan alur resmi di menu Pengaturan Jeda untuk menjaga komitmen fokus Anda."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }

    companion object {
        fun showBypassWarningNotification(context: Context) {
            try {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channelId = "jeda_security_alerts"

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        channelId,
                        "Keamanan & Anti-Bypass",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Notifikasi saat ada upaya menonaktifkan perlindungan Jeda"
                        enableVibration(true)
                    }
                    notificationManager.createNotificationChannel(channel)
                }

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("action", "ADMIN_DISABLE_ATTEMPT")
                    putExtra("route", "/forced_uninstall_warning")
                }

                val pendingIntent = PendingIntent.getActivity(
                    context,
                    1002,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )

                val notification = NotificationCompat.Builder(context, channelId)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle("🛡️ Mode Bodyguard Aktif!")
                    .setContentText("Upaya menonaktifkan Device Admin terdeteksi.")
                    .setStyle(NotificationCompat.BigTextStyle().bigText("Upaya menonaktifkan Device Admin terdeteksi dari pengaturan HP. Mode Bodyguard mencegah pembatalan impulsif ini untuk menjaga fokusmu."))
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setContentIntent(pendingIntent)
                    .build()

                notificationManager.notify(9001, notification)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}