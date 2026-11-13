package com.dvdsalviato.ukeep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget "Ukeep" per la schermata Home: giorni insieme e cose da fare oggi. */
class UkeepWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.ukeep_widget).apply {
                setTextViewText(R.id.w_together, widgetData.getString("together", "Ukeep"))
                setTextViewText(R.id.w_count, widgetData.getString("count", "Apri Ukeep per aggiornare"))
                setTextViewText(R.id.w_tasks, widgetData.getString("tasks", ""))
                setTextViewText(R.id.w_next, widgetData.getString("next", ""))
                val pending = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.w_root, pending)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
