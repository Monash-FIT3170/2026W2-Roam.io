package com.fit3170.roamio

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIVE_ACTIVITY_CHANNEL,
        )
        liveActivityChannel = channel

        channel.setMethodCallHandler { call, result ->
            @Suppress("UNCHECKED_CAST")
            val arguments = call.arguments as? Map<String, Any?> ?: emptyMap()

            when (call.method) {
                "isSupported" -> result.success(true)
                "consumePendingAction" -> {
                    result.success(pendingLiveActivityAction)
                    pendingLiveActivityAction = null
                }
                "ackPendingAction" -> {
                    pendingLiveActivityAction = null
                    result.success(null)
                }
                "start" -> {
                    val intent = JourneyForegroundService.intentFor(
                        this,
                        JourneyForegroundService.ACTION_START,
                        arguments,
                        fromFlutter = true,
                    )
                    ContextCompat.startForegroundService(this, intent)
                    result.success("android_journey")
                }
                "update" -> {
                    startService(
                        JourneyForegroundService.intentFor(
                            this,
                            JourneyForegroundService.ACTION_UPDATE,
                            arguments,
                            fromFlutter = true,
                        ),
                    )
                    result.success(null)
                }
                "pause" -> {
                    startService(
                        JourneyForegroundService.intentFor(
                            this,
                            JourneyForegroundService.ACTION_PAUSE,
                            arguments,
                            fromFlutter = true,
                        ),
                    )
                    result.success(null)
                }
                "resume" -> {
                    startService(
                        JourneyForegroundService.intentFor(
                            this,
                            JourneyForegroundService.ACTION_RESUME,
                            arguments,
                            fromFlutter = true,
                        ),
                    )
                    result.success(null)
                }
                "stop" -> {
                    startService(
                        JourneyForegroundService.intentFor(
                            this,
                            JourneyForegroundService.ACTION_STOP,
                            arguments,
                            fromFlutter = true,
                        ),
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        liveActivityChannel = null
        super.onDestroy()
    }

    companion object {
        private const val LIVE_ACTIVITY_CHANNEL = "com.fit3170.roamio/live_activity"
        private var liveActivityChannel: MethodChannel? = null
        private var pendingLiveActivityAction: String? = null

        /** Sends a lock-screen notification action back to JourneyController. */
        fun dispatchLiveActivityAction(action: String) {
            pendingLiveActivityAction = action
            val channel = liveActivityChannel ?: return

            channel.invokeMethod(
                "onAction",
                mapOf("action" to action),
            )
        }
    }
}
