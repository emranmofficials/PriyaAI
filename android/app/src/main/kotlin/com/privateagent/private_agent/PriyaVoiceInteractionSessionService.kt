package com.privateagent.private_agent

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService

/**
 * System Voice Interaction Session controller.
 * 100% mirrors Maya's `MayaVoiceInteractionSessionService`.
 */
class PriyaVoiceInteractionSessionService : VoiceInteractionSessionService() {

    override fun onNewSession(args: Bundle?): VoiceInteractionSession {
        return PriyaVoiceSession(this)
    }

    private class PriyaVoiceSession(context: Context) : VoiceInteractionSession(context) {
        override fun onHandleAssist(data: Bundle?, structure: android.app.assist.AssistStructure?, content: android.app.assist.AssistContent?) {
            super.onHandleAssist(data, structure, content)
            // Trigger Priya main activity or assistant overlay
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("trigger_source", "voice_assistant")
            }
            if (launchIntent != null) {
                context.startActivity(launchIntent)
            }
            hide()
        }
    }
}
