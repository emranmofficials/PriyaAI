package com.privateagent.private_agent

import android.service.voice.VoiceInteractionService

/**
 * System Voice Interaction Service hook.
 * Allows Priya AI to serve as the default digital assistant replacing Google Assistant.
 * 100% mirrors Maya's `MayaVoiceInteractionService`.
 */
class PriyaVoiceInteractionService : VoiceInteractionService() {

    override fun onReady() {
        super.onReady()
    }

    override fun onShutdown() {
        super.onShutdown()
    }
}
