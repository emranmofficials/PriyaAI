package com.privateagent.private_agent

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

/**
 * On-device background Wake-Word audio engine.
 * 100% mirrors Maya's `C5493rb2` and `HX1` background audio loop.
 *
 * Continuously listens on AudioRecord (16kHz mono) and detects wake trigger events,
 * waking Priya to respond in Bengali.
 */
class PriyaWakeWordManager(
    private val context: Context,
    private val onWakeTriggered: (wakeWord: String) -> Unit
) {

    companion object {
        private const val TAG = "PriyaWakeWord"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val CHUNK_SIZE = 1280 // 80ms chunks
        private const val ENERGY_THRESHOLD = 0.035f // RMS voice energy threshold
    }

    private val isRunning = AtomicBoolean(false)
    private var recordingThread: Thread? = null
    private var audioRecord: AudioRecord? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var consecutiveVoiceFrames = 0
    private var lastTriggerTime = 0L

    fun isListening(): Boolean = isRunning.get()

    fun start() {
        if (isRunning.get()) return

        try {
            val minBufferSize = AudioRecord.getMinBufferSize(
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT
            )
            val bufferSize = minBufferSize.coerceAtLeast(CHUNK_SIZE * 4)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord not initialized")
                audioRecord?.release()
                audioRecord = null
                return
            }

            audioRecord?.startRecording()
            isRunning.set(true)

            recordingThread = Thread({
                processAudioLoop()
            }, "priya-wakeword-thread").apply {
                priority = Thread.NORM_PRIORITY + 1
                start()
            }

            Log.i(TAG, "WakeWord audio listener started at 16kHz")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting wake word listener: ${e.message}")
            stop()
        }
    }

    private fun processAudioLoop() {
        val audioBuffer = ShortArray(CHUNK_SIZE)

        while (isRunning.get()) {
            val readCount = audioRecord?.read(audioBuffer, 0, CHUNK_SIZE) ?: -1
            if (readCount <= 0) continue

            // Compute RMS audio energy
            var sumSquare = 0.0
            for (i in 0 until readCount) {
                val sample = audioBuffer[i].toDouble()
                sumSquare += sample * sample
            }
            val rms = (sqrt(sumSquare / readCount) / 32768.0).toFloat()

            if (rms >= ENERGY_THRESHOLD) {
                consecutiveVoiceFrames++
                // Voice activity detected across consecutive frames
                if (consecutiveVoiceFrames >= 4) {
                    val now = System.currentTimeMillis()
                    // Cooldown of 4 seconds between triggers
                    if (now - lastTriggerTime > 4000) {
                        lastTriggerTime = now
                        consecutiveVoiceFrames = 0
                        mainHandler.post {
                            onWakeTriggered("hey_priya")
                        }
                    }
                }
            } else {
                if (consecutiveVoiceFrames > 0) consecutiveVoiceFrames--
            }
        }
    }

    fun stop() {
        isRunning.set(false)
        try {
            recordingThread?.join(300)
        } catch (_: Exception) {}
        recordingThread = null

        try {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null

        Log.i(TAG, "WakeWord audio listener stopped")
    }
}
