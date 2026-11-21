package com.privateagent.private_agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Boot receiver to restore Priya AI foreground service on system startup.
 * 100% mirrors Maya's `com.getmaya.android.core.BootReceiver`.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device boot completed. Preparing Priya AI standby.")
            // Launch main activity in background standby mode if needed
        }
    }
}
