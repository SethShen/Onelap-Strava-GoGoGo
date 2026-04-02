package cn.onelap.onelap_strava_sync

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build

object SharedFitIntentUriExtractor {
    fun extract(intent: Intent): List<Uri> {
        return SharedFitIntentItemSelector.select(
            action = intent.action,
            extraStreamItem = intent.getUriExtra(Intent.EXTRA_STREAM),
            clipDataItems = extractClipDataUris(intent.clipData),
            dataItem = intent.data,
        )
    }

    private fun extractClipDataUris(clipData: ClipData?): List<Uri?> {
        if (clipData == null || clipData.itemCount < 1) {
            return emptyList()
        }

        val uris = ArrayList<Uri?>(clipData.itemCount)
        for (index in 0 until clipData.itemCount) {
            uris.add(clipData.getItemAt(index).uri)
        }
        return uris
    }

    private fun Intent.getUriExtra(name: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            getParcelableExtra(name, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            getParcelableExtra(name) as? Uri
        }
    }
}
