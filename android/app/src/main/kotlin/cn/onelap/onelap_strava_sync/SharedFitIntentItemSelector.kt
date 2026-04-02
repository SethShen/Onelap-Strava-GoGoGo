package cn.onelap.onelap_strava_sync

import android.content.Intent

object SharedFitIntentItemSelector {
    fun <T> select(
        action: String?,
        extraStreamItem: T?,
        clipDataItems: List<T?>,
        dataItem: T?,
    ): List<T> {
        val nonNullClipDataItems: List<T> = clipDataItems.filterNotNull()
        return when (action) {
            Intent.ACTION_SEND -> {
                if (extraStreamItem != null) {
                    listOf(extraStreamItem)
                } else if (nonNullClipDataItems.isNotEmpty()) {
                    nonNullClipDataItems.distinct()
                } else {
                    listOfNotNull(dataItem)
                }
            }

            Intent.ACTION_VIEW -> (listOfNotNull(dataItem) + nonNullClipDataItems).distinct()
            else -> emptyList()
        }
    }
}
