package com.privateagent.private_agent

import android.content.Intent
import android.media.MediaPlayer
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Flutter -> [AgentAccessibilityService] via the
 * `com.privateagent/accessibility` MethodChannel.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "com.privateagent/accessibility"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val service = AgentAccessibilityService.instance
                when (call.method) {
                    "isServiceEnabled" -> result.success(
                        AgentAccessibilityService.isConnected
                    )

                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }

                    "openAppInfoSettings" -> {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    }

                    "getScreenSize" -> {
                        val metrics = resources.displayMetrics
                        result.success(
                            mapOf(
                                "width" to metrics.widthPixels,
                                "height" to metrics.heightPixels
                            )
                        )
                    }

                    "dumpScreen" -> {
                        if (service == null) {
                            result.error(
                                "SERVICE_OFF",
                                "PrivateAgent accessibility service is not enabled",
                                null
                            )
                        } else {
                            try {
                                result.success(service.dumpScreen())
                            } catch (e: Exception) {
                                result.error("DUMP_FAILED", e.message, null)
                            }
                        }
                    }

                    "takeScreenshot" -> {
                        if (service == null) {
                            result.error(
                                "SERVICE_OFF",
                                "PrivateAgent accessibility service is not enabled",
                                null
                            )
                        } else {
                            service.takeScreenshotBase64(result)
                        }
                    }

                    "clickAt" -> {
                        val x = (call.argument<Number>("x") ?: 0).toFloat()
                        val y = (call.argument<Number>("y") ?: 0).toFloat()
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.clickAt(x, y, result)
                        }
                    }

                    "swipe" -> {
                        val sx = (call.argument<Number>("startX") ?: 0).toFloat()
                        val sy = (call.argument<Number>("startY") ?: 0).toFloat()
                        val ex = (call.argument<Number>("endX") ?: 0).toFloat()
                        val ey = (call.argument<Number>("endY") ?: 0).toFloat()
                        val duration = (call.argument<Number>("durationMs") ?: 350).toLong()
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.swipe(sx, sy, ex, ey, duration, result)
                        }
                    }

                    "scroll" -> {
                        val direction = call.argument<String>("direction") ?: "down"
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.scroll(direction, result)
                        }
                    }

                    "typeText" -> {
                        val text = call.argument<String>("text") ?: ""
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            result.success(service.typeText(text))
                        }
                    }

                    "pressKey" -> {
                        val key = call.argument<String>("key") ?: ""
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            result.success(service.pressKey(key))
                        }
                    }

                    "playAudio" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            try {
                                mediaPlayer?.release()
                                mediaPlayer = MediaPlayer().apply {
                                    setDataSource(path)
                                    prepare()
                                    start()
                                    setOnCompletionListener { mp ->
                                        mp.release()
                                        if (mediaPlayer == mp) {
                                            mediaPlayer = null
                                        }
                                    }
                                }
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("AUDIO_ERROR", e.localizedMessage, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "Missing audio path", null)
                        }
                    }

                    "stopAudio" -> {
                        try {
                            if (mediaPlayer?.isPlaying == true) {
                                mediaPlayer?.stop()
                            }
                            mediaPlayer?.release()
                            mediaPlayer = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
