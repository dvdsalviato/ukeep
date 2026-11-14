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

/** Widget "Lista": le voci di una lista, si spuntano toccandole; "Cambia" passa alla lista dopo. */
class UkeepListWidget : HomeWidgetProvider() {
    private val rows = intArrayOf(R.id.l_row0, R.id.l_row1, R.id.l_row2, R.id.l_row3, R.id.l_row4, R.id.l_row5, R.id.l_row6, R.id.l_row7)
    private val texts = intArrayOf(R.id.l_t0, R.id.l_t1, R.id.l_t2, R.id.l_t3, R.id.l_t4, R.id.l_t5, R.id.l_t6, R.id.l_t7)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val arr = try {
            JSONArray(widgetData.getString("wl_items", "[]") ?: "[]")
        } catch (e: Exception) {
            JSONArray()
        }
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.ukeep_list_widget)
            views.setTextViewText(R.id.l_title, widgetData.getString("wl_title", "Lista"))
            views.setTextViewText(R.id.l_more, widgetData.getString("wl_more", ""))
            val listId = widgetData.getString("wl_id", "") ?: ""
            for (i in rows.indices) {
                if (i < arr.length()) {
                    val o = arr.getJSONObject(i)
                    views.setViewVisibility(rows[i], View.VISIBLE)
                    views.setTextViewText(texts[i], o.optString("t"))
                    views.setOnClickPendingIntent(
                        rows[i],
                        HomeWidgetBackgroundIntent.getBroadcast(
                            context, Uri.parse("ukeep://litem?l=" + Uri.encode(listId) + "&id=" + Uri.encode(o.optString("id")))
                        )
                    )
                } else {
                    views.setViewVisibility(rows[i], View.GONE)
                }
            }
            views.setViewVisibility(R.id.l_empty, if (arr.length() == 0) View.VISIBLE else View.GONE)
            val open = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.l_header, open)
            views.setOnClickPendingIntent(R.id.l_empty, open)
            views.setOnClickPendingIntent(
                R.id.l_switch,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("ukeep://nextlist"))
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
