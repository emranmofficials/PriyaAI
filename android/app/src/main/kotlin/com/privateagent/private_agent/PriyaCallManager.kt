package com.privateagent.private_agent

import android.content.Context
import android.media.AudioManager
import android.os.Build
import android.telecom.TelecomManager

/**
 * Handles incoming call actions: Accept, Reject, Duck Ringer Volume.
 */
object PriyaCallManager {

    private var previousVolume: Int? = null

    fun acceptCall(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                telecomManager?.acceptRingingCall()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    fun endCall(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager
                telecomManager?.endCall()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    fun duckRinger(context: Context) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            if (previousVolume == null) {
                previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
            }
            audioManager.setStreamVolume(
                AudioManager.STREAM_RING,
                (previousVolume!! / 3).coerceAtLeast(1),
                0
            )
        } catch (_: Exception) {}
    }

    fun restoreRinger(context: Context) {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            previousVolume?.let { vol ->
                audioManager.setStreamVolume(AudioManager.STREAM_RING, vol, 0)
                previousVolume = null
            }
        } catch (_: Exception) {}
    }
}
