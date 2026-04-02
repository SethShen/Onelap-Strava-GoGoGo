package cn.onelap.onelap_strava_sync

object SharedFitIntentValidator {
    private val supportedMimeTypes: Set<String> = setOf(
        "application/vnd.ant.fit",
        "application/fit",
    )

    fun validationError(
        uriCount: Int,
        mimeType: String?,
        displayName: String?,
        uriLastSegment: String?,
    ): String? {
        if (uriCount < 1) {
            return "No FIT file was provided"
        }
        if (uriCount > 1) {
            return "Only one FIT file can be shared at a time"
        }

        if (mimeType != null && supportedMimeTypes.contains(mimeType.lowercase())) {
            return null
        }

        val candidateName: String = listOfNotNull(displayName, uriLastSegment)
            .firstOrNull { it.isNotBlank() }
            ?.substringAfterLast('/')
            ?.trim()
            .orEmpty()

        return if (candidateName.lowercase().endsWith(".fit")) {
            null
        } else {
            "Only FIT files are supported"
        }
    }
}
