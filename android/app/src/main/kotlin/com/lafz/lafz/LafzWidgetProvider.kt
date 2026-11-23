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
import android.widget.RemoteViews

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
        val dbFile = context.getDatabasePath("lafz.db")
        var newQuote = "The only true wisdom is in knowing you know nothing."
        var newAttr = "Socrates"

        if (dbFile != null && dbFile.exists()) {
            var db: SQLiteDatabase? = null
            try {
                db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
                val cursor = db.rawQuery(
                    "SELECT text, attribution FROM quotes WHERE publication_status = 'published' ORDER BY RANDOM() LIMIT 1",
                    null
                )
                if (cursor.moveToFirst()) {
                    newQuote = cursor.getString(cursor.getColumnIndexOrThrow("text"))
                    newAttr = cursor.getString(cursor.getColumnIndexOrThrow("attribution"))
                }
                cursor.close()
            } catch (_: Exception) {
            } finally {
                db?.close()
            }
        }

        val prefs = context.getSharedPreferences("lafz_widget_prefs", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("quote", newQuote)
            .putString("attribution", "— $newAttr")
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
