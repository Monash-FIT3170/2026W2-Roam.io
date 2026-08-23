package com.fit3170.roamio

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import kotlin.math.roundToInt

/**
 * Keeps an active Journey visible as an ongoing Android notification and keeps
 * the process in foreground-service priority while location tracking is active.
 */
class JourneyForegroundService : Service() {
    private var journeyId: String = "journey"
    private var transportMode: String = "Walk"
    private var elapsedSeconds: Int = 0
    private var distanceMeters: Double = 0.0
    private var tilesUnlocked: Int = 0
    private var xpEarned: Int = 0
    private var isPaused: Boolean = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        readState(intent)
        val fromFlutter = intent.getBooleanExtra(EXTRA_FROM_FLUTTER, false)

        when (intent.action) {
            ACTION_START -> {
                isPaused = false
                promoteToForeground()
            }
            ACTION_UPDATE -> updateNotification()
            ACTION_PAUSE -> {
                isPaused = true
                updateNotification()
                if (!fromFlutter) {
                    MainActivity.dispatchLiveActivityAction("pause")
                }
            }
            ACTION_RESUME -> {
                isPaused = false
                updateNotification()
                if (!fromFlutter) {
                    MainActivity.dispatchLiveActivityAction("resume")
                }
            }
            ACTION_STOP -> {
                if (!fromFlutter) {
                    MainActivity.dispatchLiveActivityAction("stop")
                }
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    private fun promoteToForeground() {
        val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        } else {
            0
        }

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(),
            serviceType,
        )
    }

    private fun updateNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun buildNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (isPaused) "Journey Paused" else "Journey in Progress")
            .setContentText(buildMetricText())
            .setStyle(NotificationCompat.BigTextStyle().bigText(buildMetricText()))
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setWhen(System.currentTimeMillis() - elapsedSeconds * 1000L)
            .setShowWhen(!isPaused)
            .setUsesChronometer(!isPaused)
            .setContentIntent(openAppPendingIntent())
            .setRequestPromotedOngoing(true)
            .setShortCriticalText(shortDistance())
            .addAction(
                if (isPaused) {
                    NotificationCompat.Action(
                        0,
                        "Resume",
                        actionPendingIntent(ACTION_RESUME, REQUEST_RESUME),
                    )
                } else {
                    NotificationCompat.Action(
                        0,
                        "Pause",
                        actionPendingIntent(ACTION_PAUSE, REQUEST_PAUSE),
                    )
                },
            )
            .addAction(
                NotificationCompat.Action(
                    0,
                    "Stop",
                    actionPendingIntent(ACTION_STOP, REQUEST_STOP),
                ),
            )
            .build()

    private fun buildMetricText(): String {
        val duration = formatDuration(elapsedSeconds)
        val distance = formatDistance(distanceMeters)
        return "$distance • $duration • $tilesUnlocked tiles • $xpEarned XP • $transportMode"
    }

    private fun shortDistance(): String {
        return if (distanceMeters >= 1000) {
            "%.1fkm".format(distanceMeters / 1000.0)
        } else {
            "${distanceMeters.roundToInt()}m"
        }
    }

    private fun openAppPendingIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        } ?: Intent(this, MainActivity::class.java)

        return PendingIntent.getActivity(
            this,
            REQUEST_OPEN,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun actionPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, JourneyForegroundService::class.java).apply {
            this.action = action
            putExtra(EXTRA_FROM_FLUTTER, false)
        }

        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun readState(intent: Intent) {
        journeyId = intent.getStringExtra(EXTRA_JOURNEY_ID) ?: journeyId
        transportMode = intent.getStringExtra(EXTRA_TRANSPORT_MODE) ?: transportMode
        elapsedSeconds = intent.getIntExtra(EXTRA_ELAPSED_SECONDS, elapsedSeconds)
        distanceMeters = intent.getDoubleExtra(EXTRA_DISTANCE_METERS, distanceMeters)
        tilesUnlocked = intent.getIntExtra(EXTRA_TILES_UNLOCKED, tilesUnlocked)
        xpEarned = intent.getIntExtra(EXTRA_XP_EARNED, xpEarned)
        if (intent.hasExtra(EXTRA_IS_PAUSED)) {
            isPaused = intent.getBooleanExtra(EXTRA_IS_PAUSED, isPaused)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Live Journey",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Ongoing Journey tracking and controls"
            setSound(null, null)
            enableVibration(false)
        }

        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    companion object {
        const val ACTION_START = "com.fit3170.roamio.live.START"
        const val ACTION_UPDATE = "com.fit3170.roamio.live.UPDATE"
        const val ACTION_PAUSE = "com.fit3170.roamio.live.PAUSE"
        const val ACTION_RESUME = "com.fit3170.roamio.live.RESUME"
        const val ACTION_STOP = "com.fit3170.roamio.live.STOP"

        private const val CHANNEL_ID = "journey_live_activity"
        private const val NOTIFICATION_ID = 7401

        private const val REQUEST_OPEN = 7401
        private const val REQUEST_PAUSE = 7402
        private const val REQUEST_RESUME = 7403
        private const val REQUEST_STOP = 7404

        private const val EXTRA_JOURNEY_ID = "journeyId"
        private const val EXTRA_TRANSPORT_MODE = "transportMode"
        private const val EXTRA_ELAPSED_SECONDS = "elapsedSeconds"
        private const val EXTRA_DISTANCE_METERS = "distanceMeters"
        private const val EXTRA_TILES_UNLOCKED = "tilesUnlocked"
        private const val EXTRA_XP_EARNED = "xpEarned"
        private const val EXTRA_IS_PAUSED = "isPaused"
        private const val EXTRA_FROM_FLUTTER = "fromFlutter"

        fun intentFor(
            context: Context,
            action: String,
            arguments: Map<String, Any?>,
            fromFlutter: Boolean,
        ): Intent {
            return Intent(context, JourneyForegroundService::class.java).apply {
                this.action = action
                putExtra(EXTRA_JOURNEY_ID, arguments[EXTRA_JOURNEY_ID] as? String)
                putExtra(EXTRA_TRANSPORT_MODE, arguments[EXTRA_TRANSPORT_MODE] as? String)
                putExtra(
                    EXTRA_ELAPSED_SECONDS,
                    (arguments[EXTRA_ELAPSED_SECONDS] as? Number)?.toInt() ?: 0,
                )
                putExtra(
                    EXTRA_DISTANCE_METERS,
                    (arguments[EXTRA_DISTANCE_METERS] as? Number)?.toDouble() ?: 0.0,
                )
                putExtra(
                    EXTRA_TILES_UNLOCKED,
                    (arguments[EXTRA_TILES_UNLOCKED] as? Number)?.toInt() ?: 0,
                )
                putExtra(
                    EXTRA_XP_EARNED,
                    (arguments[EXTRA_XP_EARNED] as? Number)?.toInt() ?: 0,
                )
                putExtra(EXTRA_IS_PAUSED, arguments[EXTRA_IS_PAUSED] as? Boolean ?: false)
                putExtra(EXTRA_FROM_FLUTTER, fromFlutter)
            }
        }

        private fun formatDuration(totalSeconds: Int): String {
            val hours = totalSeconds / 3600
            val minutes = (totalSeconds % 3600) / 60
            val seconds = totalSeconds % 60
            return if (hours > 0) {
                "%d:%02d:%02d".format(hours, minutes, seconds)
            } else {
                "%02d:%02d".format(minutes, seconds)
            }
        }

        private fun formatDistance(meters: Double): String {
            return if (meters >= 1000) {
                "%.2f km".format(meters / 1000.0)
            } else {
                "${meters.roundToInt()} m"
            }
        }
    }
}
