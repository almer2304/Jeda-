package com.mindfullock.app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class JedaDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence? {
        val broadcastIntent = Intent("JEDA_ADMIN_DISABLE_REQUESTED")
        context.sendBroadcast(broadcastIntent)
        return "Peringatan! Menonaktifkan Jeda akan membuat Anda kembali rentan terhadap distraksi."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}