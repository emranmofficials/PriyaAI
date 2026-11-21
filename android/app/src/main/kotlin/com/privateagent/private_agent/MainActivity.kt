package com.privateagent.private_agent

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
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
    private var wakeWordManager: PriyaWakeWordManager? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        wakeWordManager = PriyaWakeWordManager(applicationContext) { wakeWord ->
            runOnUiThread {
                channel.invokeMethod("onWakeWordDetected", mapOf("wakeWord" to wakeWord))
            }
        }

        channel.setMethodCallHandler { call, result ->
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

                    "tapText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val optional = call.argument<Boolean>("optional") ?: false
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.tapText(text, optional, result)
                        }
                    }

                    "waitForScreenText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val mode = call.argument<String>("mode") ?: "appear"
                        val timeout = call.argument<Int>("timeoutSeconds") ?: 30
                        if (service == null) {
                            result.error("SERVICE_OFF", "Accessibility service is not enabled", null)
                        } else {
                            service.waitForScreenText(text, mode, timeout, result)
                        }
                    }

                    "isTermuxInstalled" -> {
                        val installed = try {
                            packageManager.getPackageInfo("com.termux", 0)
                            true
                        } catch (_: PackageManager.NameNotFoundException) {
                            false
                        }
                        result.success(installed)
                    }

                    "executeTermuxCommand" -> {
                        val command = call.argument<String>("command") ?: ""
                        val workDir = call.argument<String>("workDir") ?: "/data/data/com.termux/files/home"
                        val background = call.argument<Boolean>("background") ?: true
                        val execId = (System.currentTimeMillis() % 100000).toInt()

                        try {
                            val intent = Intent("com.termux.RUN_COMMAND").apply {
                                setClassName("com.termux", "com.termux.app.RunCommandService")
                                putExtra("com.termux.RUN_COMMAND_PATH", "/data/data/com.termux/files/usr/bin/bash")
                                putExtra("com.termux.RUN_COMMAND_ARGUMENTS", arrayOf("-lc", command))
                                putExtra("com.termux.RUN_COMMAND_WORKDIR", workDir)
                                putExtra("com.termux.RUN_COMMAND_BACKGROUND", background)
                                putExtra("com.termux.RUN_COMMAND_COMMAND_LABEL", "Priya AI")

                                val resultIntent = Intent("com.privateagent.private_agent.TERMUX_RESULT").apply {
                                    setPackage(packageName)
                                    putExtra("priya_exec_id", execId)
                                }

                                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                                } else {
                                    PendingIntent.FLAG_UPDATE_CURRENT
                                }

                                val pending = PendingIntent.getBroadcast(
                                    context,
                                    execId,
                                    resultIntent,
                                    flags
                                )
                                putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", pending)
                            }

                            startService(intent)
                            result.success(mapOf("execId" to execId, "started" to true))
                        } catch (e: Exception) {
                            result.error("TERMUX_ERROR", e.localizedMessage, null)
                        }
                    }

                    "getTermuxHistory" -> {
                        synchronized(TermuxResultReceiver.resultHistory) {
                            result.success(TermuxResultReceiver.resultHistory.toList())
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

                    "isNotificationListenerEnabled" -> {
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val enabled = flat?.contains(packageName) == true
                        result.success(enabled)
                    }

                    "openNotificationListenerSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }

                    "getRecentNotifications" -> {
                        val notifs = PriyaNotificationListenerService.recentNotifications.map {
                            mapOf(
                                "key" to it.key,
                                "packageName" to it.packageName,
                                "appLabel" to it.appLabel,
                                "title" to it.title,
                                "text" to it.text,
                                "timestamp" to it.timestamp,
                                "canReply" to it.canReply,
                                "isCall" to it.isCall
                            )
                        }
                        result.success(notifs)
                    }

                    "sendDirectReply" -> {
                        val key = call.argument<String>("key") ?: ""
                        val replyText = call.argument<String>("replyText") ?: ""
                        val sent = PriyaNotificationListenerService.sendDirectReply(applicationContext, key, replyText)
                        result.success(sent)
                    }

                    "answerCall" -> {
                        result.success(PriyaCallManager.acceptCall(applicationContext))
                    }

                    "rejectCall" -> {
                        result.success(PriyaCallManager.endCall(applicationContext))
                    }

                    "duckRinger" -> {
                        PriyaCallManager.duckRinger(applicationContext)
                        result.success(true)
                    }

                    "restoreRinger" -> {
                        PriyaCallManager.restoreRinger(applicationContext)
                        result.success(true)
                    }

                    "startWakeWordDetection" -> {
                        wakeWordManager?.start()
                        result.success(true)
                    }

                    "stopWakeWordDetection" -> {
                        wakeWordManager?.stop()
                        result.success(true)
                    }

                    "isWakeWordDetectionRunning" -> {
                        result.success(wakeWordManager?.isListening() ?: false)
                    }

                    "unlockScreen" -> {
                        try {
                            val intent = Intent(this, PriyaUnlockActivity::class.java).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNLOCK_FAILED", e.localizedMessage, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        try {
            wakeWordManager?.stop()
            wakeWordManager = null
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
