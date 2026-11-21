package com.privateagent.private_agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.telephony.TelephonyManager
import android.util.Log

/**
 * Call screening & ringer announcer receiver.
 * 100% mirrors Maya's `com.getmaya.android.core.PhoneStateReceiver`.
 */
class PhoneCallReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneCallReceiver"
        var onCallStateChanged: ((state: String, incomingNumber: String?) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            val stateStr = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            val incomingNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)

            Log.d(TAG, "Phone state: $stateStr, Number: $incomingNumber")

            if (stateStr == TelephonyManager.EXTRA_STATE_RINGING) {
                // Duck ringer volume smoothly for assistant announcement
                try {
                    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_RING)
                    if (currentVol > 2) {
                        audioManager.setStreamVolume(AudioManager.STREAM_RING, 2, 0)
                    }
                } catch (_: Exception) {}
            }

            onCallStateChanged?.invoke(stateStr.orEmpty(), incomingNumber)
        }
    }
}
