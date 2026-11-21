package com.privateagent.private_agent

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager

/**
 * Automatically wakes up the phone screen and requests keyguard dismissal.
 * 100% mirrors Maya's `com.getmaya.android.ui.UnlockActivity`.
 */
class PriyaUnlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager?.isInteractive == false) {
                @Suppress("DEPRECATION")
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "priya:unlock"
                )
                wakeLock.acquire(10000L)
                wakeLock.release()
            }
        } catch (_: Exception) {}

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (keyguardManager?.isKeyguardLocked == true) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                keyguardManager.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        super.onDismissSucceeded()
                        finish()
                        overridePendingTransition(0, 0)
                    }

                    override fun onDismissError() {
                        super.onDismissError()
                        finish()
                        overridePendingTransition(0, 0)
                    }

                    override fun onDismissCancelled() {
                        super.onDismissCancelled()
                        finish()
                        overridePendingTransition(0, 0)
                    }
                })
            } else {
                finish()
            }
        } else {
            finish()
        }
    }
}
