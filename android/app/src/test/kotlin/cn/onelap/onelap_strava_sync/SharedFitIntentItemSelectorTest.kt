package cn.onelap.onelap_strava_sync

import android.content.Intent
import org.junit.Assert.assertEquals
import org.junit.Test

class SharedFitIntentItemSelectorTest {
    @Test
    fun `returns all clip data items for send intents when extra stream is absent`() {
        val items: List<String> = SharedFitIntentItemSelector.select(
            action = Intent.ACTION_SEND,
            extraStreamItem = null,
            clipDataItems = listOf("first", "second"),
            dataItem = null,
        )

        assertEquals(listOf("first", "second"), items)
    }

    @Test
    fun `keeps later valid items after null clip data entries`() {
        val items: List<String> = SharedFitIntentItemSelector.select(
            action = Intent.ACTION_VIEW,
            extraStreamItem = null,
            clipDataItems = listOf(null, "activity"),
            dataItem = null,
        )

        assertEquals(listOf("activity"), items)
    }

    @Test
    fun `dedupes matching data and clip data items for view intents`() {
        val items: List<String> = SharedFitIntentItemSelector.select(
            action = Intent.ACTION_VIEW,
            extraStreamItem = null,
            clipDataItems = listOf("content://provider/activity.fit"),
            dataItem = "content://provider/activity.fit",
        )

        assertEquals(listOf("content://provider/activity.fit"), items)
    }
}
