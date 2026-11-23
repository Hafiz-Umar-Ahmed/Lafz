package com.lafz.lafz

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

/**
 * "Quick Rotation" home-screen widget. Each tile opens the app through a deep
 * link (lafz://lafz.app/hub/<action>). Flutter runs the action, then closes.
 */
class LafzHubWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hub_widget)
            bindTile(context, views, R.id.tile_favorites, "favorites", 101)
            bindTile(context, views, R.id.tile_collection, "collection", 102)
            bindTile(context, views, R.id.tile_random, "random", 103)
            bindTile(context, views, R.id.tile_widget, "widget", 104)
            bindTile(context, views, R.id.tile_both, "both", 105)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindTile(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        action: String,
        requestCode: Int
    ) {
        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("lafz://lafz.app/hub/$action"),
            context,
            MainActivity::class.java
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(viewId, pendingIntent)
    }
}
