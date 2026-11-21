package com.privateagent.private_agent

import android.app.Notification
import android.app.RemoteInput
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Reads incoming notifications (WhatsApp, Telegram, SMS, Calls)
 * and allows Priya to announce them in Bengali and reply via inline RemoteInput.
 */
class PriyaNotificationListenerService : NotificationListenerService() {

    data class NotificationItem(
        val key: String,
        val packageName: String,
        val appLabel: String,
        val title: String,
        val text: String,
        val timestamp: Long,
        val canReply: Boolean,
        val isCall: Boolean
    )

    data class CachedReplyAction(
        val action: Notification.Action,
        val remoteInput: RemoteInput,
        val packageName: String,
        val title: String
    )

    companion object {
        @Volatile
        var instance: PriyaNotificationListenerService? = null
        @Volatile
        var isConnected: Boolean = false

        val monitoredPackages = setOf(
            "com.whatsapp",
            "com.whatsapp.w4b",
            "org.telegram.messenger",
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.samsung.android.dialer",
            "com.instagram.android",
            "org.thoughtcrime.securesms"
        )

        private val ignoredTexts = setOf(
            "new message", "new messages", "message", "messages",
            "checking for new messages", "you may have new messages",
            "sending message", "waiting for messages", "waiting for message",
            "নতুন বার্তা", "মেসেজ পাঠানো হচ্ছে"
        )

        val recentNotifications = CopyOnWriteArrayList<NotificationItem>()
        val replyActions = ConcurrentHashMap<String, CachedReplyAction>()

        fun sendDirectReply(context: Context, key: String, replyText: String): Boolean {
            val cached = replyActions[key] ?: return false
            return try {
                val intent = Intent()
                val bundle = Bundle()
                bundle.putCharSequence(cached.remoteInput.resultKey, replyText)
                RemoteInput.addResultsToIntent(arrayOf(cached.remoteInput), intent, bundle)
                cached.action.actionIntent.send(context, 0, intent)
                true
            } catch (e: Exception) {
                false
            }
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        isConnected = true
    }

    override fun onListenerDisconnected() {
        isConnected = false
        if (instance == this) {
            instance = null
        }
        try {
            requestRebind(ComponentName(this, PriyaNotificationListenerService::class.java))
        } catch (_: Exception) {}
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        isConnected = false
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.isOngoing) return

        val pkg = sbn.packageName
        if (!monitoredPackages.contains(pkg)) return

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""

        if (title.isEmpty() && text.isEmpty()) return
        if (title.equals("WhatsApp", ignoreCase = true) || title.equals("Telegram", ignoreCase = true)) return

        val lowerText = text.lowercase()
        if (ignoredTexts.contains(lowerText)) return

        val isCall = (notification.category == Notification.CATEGORY_CALL)

        var replyAction: Notification.Action? = null
        var foundRemoteInput: RemoteInput? = null

        notification.actions?.forEach { action ->
            action.remoteInputs?.forEach { remoteInput ->
                if (remoteInput.allowFreeFormInput) {
                    replyAction = action
                    foundRemoteInput = remoteInput
                }
            }
        }

        val key = sbn.key
        if (replyAction != null && foundRemoteInput != null) {
            replyActions[key] = CachedReplyAction(
                action = replyAction!!,
                remoteInput = foundRemoteInput!!,
                packageName = pkg,
                title = title
            )
            // Limit cache size
            if (replyActions.size > 50) {
                val oldestKey = replyActions.keys.firstOrNull()
                if (oldestKey != null) replyActions.remove(oldestKey)
            }
        }

        var appLabel = pkg
        try {
            val appInfo = packageManager.getApplicationInfo(pkg, 0)
            appLabel = packageManager.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {}

        val item = NotificationItem(
            key = key,
            packageName = pkg,
            appLabel = appLabel,
            title = title,
            text = text,
            timestamp = sbn.postTime,
            canReply = (foundRemoteInput != null),
            isCall = isCall
        )

        recentNotifications.add(0, item)
        if (recentNotifications.size > 50) {
            recentNotifications.removeAt(recentNotifications.size - 1)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        if (sbn != null) {
            replyActions.remove(sbn.key)
        }
    }
}
