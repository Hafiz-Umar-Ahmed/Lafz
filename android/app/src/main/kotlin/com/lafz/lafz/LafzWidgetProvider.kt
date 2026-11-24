package com.lafz.lafz

import android.app.PendingIntent
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.widget.RemoteViews
import java.io.File

class LafzWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_SHUFFLE_WIDGET) {
            shuffleWidgetQuote(context)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
        val quote = prefs.getString("quote", "No quote yet — open Lafz to begin.") ?: "No quote yet — open Lafz to begin."
        val attribution = prefs.getString("attribution", "") ?: ""
        val bgColor = prefs.getInt("bg_color", Color.parseColor("#CC1E232B"))
        val textColor = prefs.getInt("text_color", Color.WHITE)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val launchPendingIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                context, 0, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else null

        val shuffleIntent = Intent(context, LafzWidgetProvider::class.java).apply {
            action = ACTION_SHUFFLE_WIDGET
        }
        val shufflePendingIntent = PendingIntent.getBroadcast(
            context, 1, shuffleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)
            views.setInt(R.id.widget_root, "setBackgroundColor", bgColor)
            views.setTextViewText(R.id.quote_text, quote)
            views.setTextColor(R.id.quote_text, textColor)
            views.setTextViewText(R.id.attribution_text, attribution)
            views.setTextColor(R.id.attribution_text, adjustAlpha(textColor, 0.7f))

            if (launchPendingIntent != null) {
                views.setOnClickPendingIntent(R.id.quote_text, launchPendingIntent)
            }
            views.setOnClickPendingIntent(R.id.btn_widget_shuffle, shufflePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun shuffleWidgetQuote(context: Context) {
        val prefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
        val currentQuote = prefs.getString("quote", "") ?: ""

        val dbFile = findDatabaseFile(context)
        var newQuote = ""
        var newAttr = ""

        if (dbFile != null && dbFile.exists()) {
            var db: SQLiteDatabase? = null
            try {
                db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)

                val rotationPrefs = context.getSharedPreferences("lafz_rotation_prefs", Context.MODE_PRIVATE)
                val rotateMode = rotationPrefs.getString("rotation_mode", "standard")

                val queryWithExclusion = when (rotateMode) {
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

                var cursor = db.rawQuery(queryWithExclusion, arrayOf(currentQuote))
                if (!cursor.moveToFirst()) {
                    cursor.close()
                    // Fallback to any published quote without exclusion (e.g. if only 1 quote exists)
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
                    newQuote = cursor.getString(cursor.getColumnIndexOrThrow("text"))
                    newAttr = cursor.getString(cursor.getColumnIndexOrThrow("attribution"))
                }
                cursor.close()
            } catch (e: Exception) {
                Log.e("LafzWidget", "Error querying SQLite database: ${e.message}", e)
            } finally {
                db?.close()
            }
        }

        // If database was not reachable or had no records, pick from curated fallback quotes avoiding current
        if (newQuote.isEmpty()) {
            val available = FALLBACK_QUOTES.filter { it.first != currentQuote }
            val chosen = if (available.isNotEmpty()) available.random() else FALLBACK_QUOTES.random()
            newQuote = chosen.first
            newAttr = chosen.second
        }

        val formattedAttr = if (newAttr.startsWith("—") || newAttr.startsWith("-")) newAttr else "— $newAttr"

        prefs.edit()
            .putString("quote", newQuote)
            .putString("attribution", formattedAttr)
            .putLong("last_rotated_at", System.currentTimeMillis())
            .putString("last_rotated_by", "WidgetButton")
            .apply()

        refreshAllWidgets(context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private fun adjustAlpha(color: Int, factor: Float): Int {
        val alpha = (Color.alpha(color) * factor).toInt()
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
    }

    companion object {
        const val ACTION_SHUFFLE_WIDGET = "com.lafz.lafz.ACTION_SHUFFLE_WIDGET"

        private val FALLBACK_QUOTES = listOf(
            Pair("The only true wisdom is in knowing you know nothing.", "Socrates"),
            Pair("Verily, with hardship comes ease.", "The Holy Quran (94:6)"),
            Pair("Waste no more time arguing what a good man should be. Be one.", "Marcus Aurelius"),
            Pair("He who has a why to live can bear almost any how.", "Friedrich Nietzsche"),
            Pair("The best of people are those that bring most benefit to the rest of mankind.", "Prophet Muhammad (ﷺ)"),
            Pair("Knowledge is that which benefits, not that which is memorized.", "Imam Al-Shafi'i"),
            Pair("It is not death that a man should fear, but he should fear never beginning to live.", "Marcus Aurelius"),
            Pair("Do not be embarrassed by how many times you stumble; what matters is getting back up.", "Ali ibn Abi Talib")
        )

        /**
         * Resolves the SQLite database file across standard Android database paths and Flutter path_provider paths.
         */
        fun findDatabaseFile(context: Context): File? {
            val candidates = listOf(
                // 1. Flutter path_provider getApplicationDocumentsDirectory() (e.g. /data/user/0/<pkg>/app_flutter/lafz.db)
                File(context.filesDir.parentFile, "app_flutter/lafz.db"),
                File(context.applicationInfo.dataDir, "app_flutter/lafz.db"),
                File(context.filesDir, "app_flutter/lafz.db"),
                // 2. Standard Android databases directory (e.g. /data/user/0/<pkg>/databases/lafz.db)
                context.getDatabasePath("lafz.db"),
                File(context.applicationInfo.dataDir, "databases/lafz.db"),
                File(context.filesDir.parentFile, "databases/lafz.db"),
                // 3. Root files directory
                File(context.filesDir, "lafz.db")
            )
            return candidates.firstOrNull { it.exists() && it.length() > 0 }
        }

        fun refreshAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, LafzWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                val provider = LafzWidgetProvider()
                provider.onUpdate(context, manager, ids)
            }
        }
    }
}

