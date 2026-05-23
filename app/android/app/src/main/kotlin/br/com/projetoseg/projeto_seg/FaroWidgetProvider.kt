package br.com.projetoseg.projeto_seg

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget de tela inicial do Faro. Mostra:
 *   - Contagem de relatos nas últimas 6h no bairro principal do usuário
 *   - Nome do bairro
 *   - Quando foi atualizado
 *
 * Quando count = -1, exibe "Configure no app". Tap em qualquer estado
 * abre o app na MainActivity.
 *
 * Dados vêm de SharedPreferences gravado pelo Flutter via `home_widget`
 * package — sem rede própria, sem PII além do nome do bairro escolhido
 * pelo próprio usuário.
 */
class FaroWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs: SharedPreferences = HomeWidgetPlugin.getData(context)
        val count = prefs.getInt("count", -1)
        val label = prefs.getString("label", "") ?: ""
        val updatedAt = prefs.getString("updatedAt", null)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.faro_widget)

            when {
                count < 0 -> {
                    views.setTextViewText(R.id.faro_widget_count, "—")
                    views.setTextViewText(
                        R.id.faro_widget_label,
                        "Defina seu bairro principal no app"
                    )
                    views.setTextViewText(R.id.faro_widget_subtitle, "")
                }
                count == 0 -> {
                    views.setTextViewText(R.id.faro_widget_count, "0")
                    views.setTextViewText(R.id.faro_widget_label, label)
                    views.setTextViewText(
                        R.id.faro_widget_subtitle,
                        "sem relatos nas últimas 6h"
                    )
                }
                count == 1 -> {
                    views.setTextViewText(R.id.faro_widget_count, "1")
                    views.setTextViewText(R.id.faro_widget_label, label)
                    views.setTextViewText(
                        R.id.faro_widget_subtitle,
                        "1 relato nas últimas 6h"
                    )
                }
                else -> {
                    views.setTextViewText(R.id.faro_widget_count, count.toString())
                    views.setTextViewText(R.id.faro_widget_label, label)
                    views.setTextViewText(
                        R.id.faro_widget_subtitle,
                        "$count relatos nas últimas 6h"
                    )
                }
            }

            // Tap em qualquer lugar do widget abre o app.
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.faro_widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
