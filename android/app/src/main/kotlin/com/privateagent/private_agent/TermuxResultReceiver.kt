package com.privateagent.private_agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log

/**
 * BroadcastReceiver for Termux `com.termux.RUN_COMMAND` results.
 * 100% mirrors Maya's `com.getmaya.android.termux.TermuxResultReceiver`.
 */
class TermuxResultReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "TermuxResultReceiver"

        /** Listener callback for live Termux execution results. */
        var onResultListener: ((execId: Int, stdout: String, stderr: String, exitCode: Int) -> Unit)? = null

        /** In-memory log cache for terminal reel. */
        val resultHistory = mutableListOf<Map<String, Any>>()
    }

    override fun onReceive(context: Context, intent: Intent) {
        val execId = intent.getIntExtra("priya_exec_id", -1)
        val resultBundle: Bundle? = intent.getBundleExtra("result")

        val stdout = resultBundle?.getString("stdout").orEmpty()
        val stderr = resultBundle?.getString("stderr").orEmpty()
        val exitCode = resultBundle?.getInt("exitCode", 0) ?: 0

        Log.d(TAG, "Termux execution #$execId finished with exitCode=$exitCode")

        val record = mapOf(
            "execId" to execId,
            "stdout" to stdout,
            "stderr" to stderr,
            "exitCode" to exitCode,
            "timestamp" to System.currentTimeMillis()
        )

        synchronized(resultHistory) {
            resultHistory.add(record)
            if (resultHistory.size > 100) resultHistory.removeAt(0)
        }

        onResultListener?.invoke(execId, stdout, stderr, exitCode)
    }
}
