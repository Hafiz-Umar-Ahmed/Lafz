package com.lafz.lafz

import android.app.WallpaperManager
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.work.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val WALLPAPER_CHANNEL = "com.lafz.lafz/wallpaper"
    private val WIDGET_CHANNEL = "com.lafz.lafz/widget"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Wallpaper Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WALLPAPER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setWallpaper" -> {
                    val imageBytes = call.argument<ByteArray>("image")
                    val destination = call.argument<String>("destination") ?: "lock"
                    if (imageBytes != null && imageBytes.isNotEmpty()) {
                        Thread {
                            var bitmap: android.graphics.Bitmap? = null
                            try {
                                bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                                if (bitmap == null) {
                                    mainHandler.post {
                                        result.error("WALLPAPER_ERROR", "Failed to decode wallpaper image", null)
                                    }
                                    return@Thread
                                }
                                val wm = WallpaperManager.getInstance(applicationContext)
                                val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    when (destination) {
                                        "home" -> wm.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM) > 0
                                        "lock" -> wm.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK) > 0
                                        else -> {
                                            val combined = wm.setBitmap(
                                                bitmap,
                                                null,
                                                true,
                                                WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                                            )
                                            if (combined > 0) {
                                                true
                                            } else {
                                                // Fallback for OEMs that reject combined flags
                                                val homeOk = wm.setBitmap(bitmap, null, true, WallpaperManager.FLAG_SYSTEM) > 0
                                                val lockOk = wm.setBitmap(bitmap, null, true, WallpaperManager.FLAG_LOCK) > 0
                                                homeOk || lockOk
                                            }
                                        }
                                    }
                                } else {
                                    wm.setBitmap(bitmap)
                                    true
                                }
                                mainHandler.post { result.success(ok) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("WALLPAPER_ERROR", e.localizedMessage, null)
                                }
                            } finally {
                                bitmap?.recycle()
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Image bytes cannot be null or empty", null)
                    }
                }
                "getBatteryOptimizationStatus" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    val status = mapOf(
                        "isIgnoringBatteryOptimizations" to isIgnoring,
                        "canScheduleExactAlarms" to true
                    )
                    result.success(status)
                }
                "openBatterySettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_ERROR", e.localizedMessage, null)
                    }
                }
                "scheduleWorkManager" -> {
                    val intervalHours = (call.argument<Int>("intervalHours") ?: 12).toLong()
                    try {
                        val constraints = Constraints.Builder()
                            .setRequiresBatteryNotLow(false)
                            .build()
                        val workRequest = PeriodicWorkRequestBuilder<LafzRotationWorker>(
                            intervalHours, TimeUnit.HOURS
                        ).setConstraints(constraints).build()

                        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                            "lafz_rotation_worker",
                            ExistingPeriodicWorkPolicy.UPDATE,
                            workRequest
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WORKMANAGER_ERROR", e.localizedMessage, null)
                    }
                }
                "triggerWorkManagerNow" -> {
                    try {
                        val workRequest = OneTimeWorkRequestBuilder<LafzRotationWorker>().build()
                        WorkManager.getInstance(applicationContext).enqueueUniqueWork(
                            "lafz_one_time_rotation",
                            ExistingWorkPolicy.REPLACE,
                            workRequest
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WORKMANAGER_ERROR", e.localizedMessage, null)
                    }
                }
                "getWorkManagerStatus" -> {
                    try {
                        val prefs = getSharedPreferences("lafz_worker_prefs", Context.MODE_PRIVATE)
                        val lastRun = prefs.getLong("last_run_timestamp", 0L)
                        val lastQuote = prefs.getString("last_run_quote", null)
                        val lastAttr = prefs.getString("last_run_attribution", null)
                        val lastStatus = prefs.getString("last_run_status", "IDLE")

                        val status = mapOf(
                            "isScheduled" to true,
                            "lastRunTimestamp" to lastRun,
                            "lastQuote" to lastQuote,
                            "lastAttribution" to lastAttr,
                            "lastStatus" to lastStatus
                        )
                        result.success(status)
                    } catch (e: Exception) {
                        result.error("STATUS_ERROR", e.localizedMessage, null)
                    }
                }
                "setRotationMode" -> {
                    val mode = call.argument<String>("mode") ?: "standard"
                    val prefs = getSharedPreferences("lafz_rotation_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("rotation_mode", mode).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Widget Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val prefs = getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                        .putString("quote", call.argument<String>("quote"))
                        .putString("attribution", call.argument<String>("attribution"))
                        .putString("collection", call.argument<String>("collection"))

                    // Handle background color
                    val bgColorStr = call.argument<String>("bg_color")
                    if (bgColorStr != null) {
                        try {
                            editor.putInt("bg_color", Color.parseColor(bgColorStr))
                        } catch (_: Exception) {}
                    }

                    // Handle text color
                    val textColorStr = call.argument<String>("text_color")
                    if (textColorStr != null) {
                        try {
                            editor.putInt("text_color", Color.parseColor(textColorStr))
                        } catch (_: Exception) {}
                    }

                    editor.apply()

                    // Immediately refresh all widgets
                    LafzWidgetProvider.refreshAllWidgets(applicationContext)

                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
