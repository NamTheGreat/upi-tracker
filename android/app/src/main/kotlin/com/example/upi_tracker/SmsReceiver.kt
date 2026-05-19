package com.example.upi_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.dart.DartExecutor

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL = "com.upitracker/sms"
        private var methodChannel: MethodChannel? = null
        
        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("UPITracker", "SmsReceiver.onReceive called with action: ${intent?.action}")
        
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            val fullMessage = messages?.joinToString("") { it.messageBody ?: "" } ?: return
            
            Log.d("UPITracker", "SMS received: $fullMessage")
            
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onSmsReceived", mapOf("body" to fullMessage))
            } else {
                Log.w("UPITracker", "MethodChannel is null - app may not be running")
            }
        }
    }
}