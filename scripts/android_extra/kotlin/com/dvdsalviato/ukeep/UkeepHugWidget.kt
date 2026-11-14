package com.dvdsalviato.ukeep

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget "Ti penso" 1x1.
 * - normale: 🤗, lo tocchi e parte l'abbraccio al partner;
 * - quando il partner ti pensa: 💛 col suo nome. Toccandolo gli rispondi
 *   (anch'io), con la ✕ in alto lo togli senza rispondere.
 */
class UkeepHugWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val state = widgetData.getString("hug_state", "idle") ?: "idle"
        val recv = state == "recv"
        val sent = state == "sent"
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.ukeep_hug_widget)
            views.setViewVisibility(R.id.h_send, if (recv) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.h_recv, if (recv) View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.h_close, if (recv) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.h_label, if (sent) "Inviato 💌" else "Ti penso")
            views.setTextViewText(R.id.h_from, widgetData.getString("hug_short", "Ti pensa"))
            views.setOnClickPendingIntent(
                R.id.h_send,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("ukeep://hug"))
            )
            views.setOnClickPendingIntent(
                R.id.h_recv,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("ukeep://hugback"))
            )
            views.setOnClickPendingIntent(
                R.id.h_close,
                HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("ukeep://hugclear"))
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
