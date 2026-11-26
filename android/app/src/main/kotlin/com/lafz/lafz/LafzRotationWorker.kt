package com.lafz.lafz

import android.app.WallpaperManager
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class LafzRotationWorker(
    private val context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            // 1. Fetch next quote from database or shared preferences
            val quoteData = fetchNextQuote()

            val quoteText = quoteData["text"] ?: "The only true wisdom is in knowing you know nothing."
            val attribution = quoteData["attribution"] ?: "Socrates"

            // 2. Update Widget preferences and refresh widgets
            val widgetPrefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
            widgetPrefs.edit()
                .putString("quote", quoteText)
                .putString("attribution", "— $attribution")
                .putLong("last_rotated_at", System.currentTimeMillis())
                .putString("last_rotated_by", "WorkManager")
                .apply()

            LafzWidgetProvider.refreshAllWidgets(context)

            // 3. Update Wallpaper if rotation is enabled
            val rotationPrefs = context.getSharedPreferences("lafz_rotation_prefs", Context.MODE_PRIVATE)
            val isWallpaperRotationEnabled = rotationPrefs.getBoolean("wallpaper_rotation_enabled", true)

            if (isWallpaperRotationEnabled) {
                renderAndSetWallpaper(quoteText, attribution)
            }

            // 4. Record execution log for UI health checks
            val workerPrefs = context.getSharedPreferences("lafz_worker_prefs", Context.MODE_PRIVATE)
            workerPrefs.edit()
                .putLong("last_run_timestamp", System.currentTimeMillis())
                .putString("last_run_quote", quoteText)
                .putString("last_run_attribution", attribution)
                .putString("last_run_status", "SUCCESS")
                .apply()

            Result.success()
        } catch (e: Exception) {
            val workerPrefs = context.getSharedPreferences("lafz_worker_prefs", Context.MODE_PRIVATE)
            workerPrefs.edit()
                .putLong("last_run_timestamp", System.currentTimeMillis())
                .putString("last_run_status", "ERROR: ${e.localizedMessage}")
                .apply()
            Result.retry()
        }
    }

    private fun fetchNextQuote(): Map<String, String> {
        val dbFile = LafzWidgetProvider.findDatabaseFile(context)
        if (dbFile != null && dbFile.exists()) {
            var db: SQLiteDatabase? = null
            try {
                db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                
                val widgetPrefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
                val currentQuote = widgetPrefs.getString("quote", "") ?: ""

                val rotationPrefs = context.getSharedPreferences("lafz_rotation_prefs", Context.MODE_PRIVATE)
                val rotateMode = rotationPrefs.getString("rotation_mode", "standard")

                val query = when (rotateMode) {
                    "favorites" -> """
                        SELECT q.text, q.attribution FROM quotes q
                        INNER JOIN favorites f ON q.id = f.quote_id
                        WHERE f.deleted_at IS NULL AND q.text != ?
                        ORDER BY RANDOM() LIMIT 1
                    """.trimIndent()
                    else -> """
                        SELECT text, attribution FROM quotes
                        WHERE publication_status = 'published' AND text != ?
                        ORDER BY RANDOM() LIMIT 1
                    """.trimIndent()
                }

                var cursor = db.rawQuery(query, arrayOf(currentQuote))
                if (!cursor.moveToFirst()) {
                    cursor.close()
                    // Fallback to any published quote without exclusion
                    val fallbackQuery = when (rotateMode) {
                        "favorites" -> """
                            SELECT q.text, q.attribution FROM quotes q
                            INNER JOIN favorites f ON q.id = f.quote_id
                            WHERE f.deleted_at IS NULL
                            ORDER BY RANDOM() LIMIT 1
                        """.trimIndent()
                        else -> """
                            SELECT text, attribution FROM quotes
                            WHERE publication_status = 'published'
                            ORDER BY RANDOM() LIMIT 1
                        """.trimIndent()
                    }
                    cursor = db.rawQuery(fallbackQuery, null)
                }

                if (cursor.moveToFirst()) {
                    val text = cursor.getString(cursor.getColumnIndexOrThrow("text"))
                    val attr = cursor.getString(cursor.getColumnIndexOrThrow("attribution"))
                    cursor.close()
                    return mapOf("text" to text, "attribution" to attr)
                }
                cursor.close()
            } catch (_: Exception) {
            } finally {
                db?.close()
            }
        }

        val widgetPrefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
        val fallbackText = widgetPrefs.getString("quote", "The only true wisdom is in knowing you know nothing.") ?: "The only true wisdom is in knowing you know nothing."
        val fallbackAttr = widgetPrefs.getString("attribution", "Socrates") ?: "Socrates"
        return mapOf("text" to fallbackText, "attribution" to fallbackAttr)
    }

    private fun renderAndSetWallpaper(quoteText: String, attribution: String) {
        var bitmap: Bitmap? = null
        try {
            val wm = WallpaperManager.getInstance(context)
            val displayMetrics = context.resources.displayMetrics
            val width = if (wm.desiredMinimumWidth > 0) wm.desiredMinimumWidth else displayMetrics.widthPixels
            val height = if (wm.desiredMinimumHeight > 0) wm.desiredMinimumHeight else displayMetrics.heightPixels

            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            bitmap = bmp
            val canvas = Canvas(bmp)

            val bgPaint = Paint().apply {
                color = Color.parseColor("#121417")
            }
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

            val textPaint = TextPaint().apply {
                color = Color.parseColor("#F5F1E8")
                textSize = (width * 0.055f).coerceIn(40f, 64f)
                isAntiAlias = true
            }

            val margin = (width * 0.12f).toInt()
            val textWidth = width - (margin * 2)

            val textLayout = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                StaticLayout.Builder.obtain(quoteText, 0, quoteText.length, textPaint, textWidth)
                    .setAlignment(Layout.Alignment.ALIGN_CENTER)
                    .setLineSpacing(0f, 1.3f)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                StaticLayout(
                    quoteText,
                    textPaint,
                    textWidth,
                    Layout.Alignment.ALIGN_CENTER,
                    1.3f,
                    0f,
                    false
                )
            }

            val textY = (height - textLayout.height) / 2f
            canvas.save()
            canvas.translate(margin.toFloat(), textY)
            textLayout.draw(canvas)
            canvas.restore()

            val attrPaint = TextPaint().apply {
                color = Color.parseColor("#C29B38")
                textSize = (width * 0.038f).coerceIn(28f, 42f)
                isAntiAlias = true
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText("— $attribution", (width / 2).toFloat(), textY + textLayout.height + (width * 0.08f), attrPaint)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                wm.setBitmap(bmp, null, true, WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK)
            } else {
                wm.setBitmap(bmp)
            }
        } catch (_: Exception) {
        } finally {
            bitmap?.recycle()
        }
    }
}
