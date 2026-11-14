package com.dvdsalviato.ukeep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/** Widget "Attività": le cose da fare, si spuntano toccandole. */
class UkeepWidget : HomeWidgetProvider() {
    private val rows = intArrayOf(R.id.w_row0, R.id.w_row1, R.id.w_row2, R.id.w_row3, R.id.w_row4, R.id.w_row5, R.id.w_row6, R.id.w_row7)
    private val texts = intArrayOf(R.id.w_t0, R.id.w_t1, R.id.w_t2, R.id.w_t3, R.id.w_t4, R.id.w_t5, R.id.w_t6, R.id.w_t7)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val arr = try {
            JSONArray(widgetData.getString("tasks_json", "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.ukeep_widget)
            views.setTextViewText(R.id.w_count, widgetData.getString("count", "Attività"))
            views.setTextViewText(R.id.w_next, widgetData.getString("next", ""))
            for (i in rows.indices) {
                if (i < arr.length()) {
                    val o = arr.getJSONObject(i)
                    views.setViewVisibility(rows[i], View.VISIBLE)
                    views.setTextViewText(texts[i], o.optString("t"))
                    views.setOnClickPendingIntent(
                        rows[i],
                        HomeWidgetBackgroundIntent.getBroadcast(
                            context, Uri.parse("ukeep://done?id=" + Uri.encode(o.optString("id")))
                        )
                    )
                } else {
                    views.setViewVisibility(rows[i], View.GONE)
                }
            }
            views.setViewVisibility(R.id.w_empty, if (arr.length() == 0) View.VISIBLE else View.GONE)
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.w_header, open)
            views.setOnClickPendingIntent(R.id.w_empty, open)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
