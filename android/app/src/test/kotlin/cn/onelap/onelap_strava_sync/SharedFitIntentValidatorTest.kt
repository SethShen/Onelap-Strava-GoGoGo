package cn.onelap.onelap_strava_sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SharedFitIntentValidatorTest {
    @Test
    fun `rejects multiple shared files`() {
        val errorMessage = SharedFitIntentValidator.validationError(
            uriCount = 2,
            mimeType = "application/vnd.ant.fit",
            displayName = "activity.fit",
            uriLastSegment = "activity.fit",
        )

        assertEquals("Only one FIT file can be shared at a time", errorMessage)
    }

    @Test
    fun `accepts generic mime type when display name is fit`() {
        val errorMessage = SharedFitIntentValidator.validationError(
            uriCount = 1,
            mimeType = "application/octet-stream",
            displayName = "activity.fit",
            uriLastSegment = "content://provider/activity.fit",
        )

        assertNull(errorMessage)
    }

    @Test
    fun `accepts fit mime type when file name has no fit suffix`() {
        val errorMessage = SharedFitIntentValidator.validationError(
            uriCount = 1,
            mimeType = "application/vnd.ant.fit",
            displayName = "shared-from-provider",
            uriLastSegment = "content://provider/opaque-id",
        )

        assertNull(errorMessage)
    }

    @Test
    fun `rejects non-fit generic share`() {
        val errorMessage = SharedFitIntentValidator.validationError(
            uriCount = 1,
            mimeType = "application/octet-stream",
            displayName = "document.pdf",
            uriLastSegment = "content://provider/document.pdf",
        )

        assertEquals("Only FIT files are supported", errorMessage)
    }
}
