package com.mindfullock.app

import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class DnsFilterService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnThread: Thread? = null
    private val blockedDomains = mutableListOf<String>()

    companion object {
        var isRunning = false

        fun start(context: Context) {
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("dns_filter_enabled", true).apply()
            
            val intent = Intent(context, DnsFilterService::class.java)
            context.startService(intent)
        }

        fun stop(context: Context) {
            val prefs = context.getSharedPreferences("JedaNativePrefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("dns_filter_enabled", false).apply()

            val intent = Intent(context, DnsFilterService::class.java)
            context.stopService(intent)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            loadBlockedDomains()
            setupVpn()
            startDnsThread()
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Ensure service restarts if app is swiped away
        val restartServiceIntent = Intent(applicationContext, DnsFilterService::class.java).also {
            it.setPackage(packageName)
        }
        val restartServicePendingIntent = android.app.PendingIntent.getService(
            this, 2, restartServiceIntent,
            android.app.PendingIntent.FLAG_ONE_SHOT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        val alarmService = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmService.set(
            android.app.AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 1000,
            restartServicePendingIntent
        )
    }

    private fun loadBlockedDomains() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val customDomains = prefs.getString("flutter_blocked_domains", "[]")
    }

    private fun setupVpn() {
        try {
            val builder = Builder()
                .addAddress("10.0.0.2", 32)
                // Add an IPv6 dummy address so IPv6 DNS can be configured
                .addAddress("fd00:1:fd00:1:fd00:1:fd00:1", 128)
                // REMOVED addRoute to avoid capturing DNS packets in our TUN interface,
                // letting the system natively route them over the physical network.
                .setMtu(1500)
                // CleanBrowsing Family Filter (Blocks Adult, Malware, and Gambling)
                .addDnsServer("185.228.168.168")
                .addDnsServer("185.228.169.168")
                // CleanBrowsing Family Filter IPv6 (Prevents IPv6 leak bypass)
                .addDnsServer("2a0d:2a00:1::")
                .addDnsServer("2a0d:2a00:2::")
                .setSession("Jeda DNS")
            
            vpnInterface = builder.establish()
            isRunning = true
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun startDnsThread() {
        vpnThread = thread {
            try {
                vpnInterface?.let { pfd ->
                    val inputStream = FileInputStream(pfd.fileDescriptor)
                    val buffer = ByteBuffer.allocate(32767)
                    
                    while (isRunning) {
                        // Keep reading to empty the buffer if any rogue packet arrives,
                        // but since we didn't addRoute, this shouldn't receive much/anything.
                        inputStream.read(buffer.array())
                        buffer.clear()
                    }
                }
            } catch (e: Exception) {
                // Ignore thread interruptions on close
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        vpnThread?.interrupt()
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
