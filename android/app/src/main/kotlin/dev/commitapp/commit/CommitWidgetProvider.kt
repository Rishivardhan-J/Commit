package dev.commitapp.commit

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** 2x2 home-screen widget: streak, today's progress, tap to open the app. */
class CommitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.commit_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "0") ?: "0")
                setTextViewText(R.id.widget_today, widgetData.getString("today", "Open Commit") ?: "Open Commit")
                setTextViewText(R.id.widget_cta, widgetData.getString("cta", "Open Commit") ?: "Open Commit")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
