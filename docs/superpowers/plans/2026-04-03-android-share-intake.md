# Android Share Intake Coverage Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Android app appear in more system share/open file flows, accept generic file intents at the platform layer, and validate FIT files inside the app while keeping invalid shares out of the confirmation flow.

**Architecture:** Keep the current single-activity intake architecture and extend it incrementally. Android manifest filters and native intent parsing will be broadened first, native FIT validation will be tightened with filename and file-header checks, and Flutter share coordination will be updated so invalid share events surface as root-level prompts instead of pushing the share confirmation route.

**Tech Stack:** Flutter, Dart, Android intent filters, Kotlin, JUnit4, Flutter widget tests

---

## File Map

- Modify: `android/app/src/main/AndroidManifest.xml`
  Responsibility: declare Android system entrypoints so WanSync appears in broader chooser/open flows.
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt`
  Responsibility: accept the broader action set, build payloads, and coordinate cache copy plus native FIT validation.
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentUriExtractor.kt`
  Responsibility: extract URIs from single and multiple stream extras, `ClipData`, and `intent.data`.
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelector.kt`
  Responsibility: normalize and deduplicate candidate items across supported actions.
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidator.kt`
  Responsibility: decide whether a candidate file is a FIT file from MIME type, filename, or header bytes.
- Create: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupport.kt`
  Responsibility: hold the supported Android action set in a unit-testable helper.
- Create: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidator.kt`
  Responsibility: validate already-copied cache files and delete rejected files.
- Modify: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelectorTest.kt`
  Responsibility: lock in URI selection and deduplication behavior for new intent actions.
- Modify: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidatorTest.kt`
  Responsibility: lock in native FIT acceptance and rejection behavior.
- Create: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupportTest.kt`
  Responsibility: lock in the supported action set.
- Create: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidatorTest.kt`
  Responsibility: lock in copied-file validation and rejected-file cleanup behavior.
- Modify: `lib/main.dart`
  Responsibility: provide a root `ScaffoldMessenger` key to the app shell.
- Modify: `lib/services/share_navigation_coordinator.dart`
  Responsibility: route draft events to `ShareConfirmScreen` and route error events to root-level prompts without forced navigation.
- Modify: `test/services/share_navigation_coordinator_test.dart`
  Responsibility: verify cold-start and warm-start invalid share behavior plus existing draft routing.

## Task 1: Expand URI Selection For `SEND_MULTIPLE`

**Files:**
- Modify: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelectorTest.kt`
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelector.kt`
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentUriExtractor.kt`

- [ ] **Step 1: Write the failing test for `ACTION_SEND_MULTIPLE` using `ArrayList` stream items**

```kotlin
@Test
fun `returns stream list items for send multiple intents`() {
    val items: List<String> = SharedFitIntentItemSelector.select(
        action = Intent.ACTION_SEND_MULTIPLE,
        extraStreamItem = null,
        extraStreamItems = listOf("first", "second"),
        clipDataItems = emptyList(),
        dataItem = null,
    )

    assertEquals(listOf("first", "second"), items)
}
```

- [ ] **Step 2: Run the selector test file and verify it fails because the new API/behavior is missing**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest`
Expected: FAIL because `extraStreamItems` and `ACTION_SEND_MULTIPLE` handling do not exist yet.

- [ ] **Step 3: Write the failing test for `ACTION_SEND_MULTIPLE` using `ClipData` items**

```kotlin
@Test
fun `returns clip data items for send multiple intents when stream list is absent`() {
    val items: List<String> = SharedFitIntentItemSelector.select(
        action = Intent.ACTION_SEND_MULTIPLE,
        extraStreamItem = null,
        extraStreamItems = emptyList(),
        clipDataItems = listOf("first", "second"),
        dataItem = null,
    )

    assertEquals(listOf("first", "second"), items)
}
```

- [ ] **Step 4: Re-run the selector test file and verify the new case is also red for the intended reason**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest`
Expected: FAIL in the new `ClipData` case, not from syntax or setup errors.

- [ ] **Step 5: Write the failing test for `VIEW` selecting `intent.data` when `ClipData` is absent**

```kotlin
@Test
fun `returns data item for view intents when clip data is absent`() {
    val items: List<String> = SharedFitIntentItemSelector.select(
        action = Intent.ACTION_VIEW,
        extraStreamItem = null,
        extraStreamItems = emptyList(),
        clipDataItems = emptyList(),
        dataItem = "content://provider/activity.fit",
    )

    assertEquals(listOf("content://provider/activity.fit"), items)
}
```

- [ ] **Step 6: Re-run the selector test file and verify the new `intent.data` case is red only for missing implementation**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest`
Expected: FAIL in the new `intent.data` case.

- [ ] **Step 7: Keep the existing overlapping `data` plus `ClipData` dedupe test in place as a regression case**

Do not remove the current test `dedupes matching data and clip data items for view intents`; it remains the explicit regression check for normalization and deduplication.

- [ ] **Step 8: Write the minimal selector and extractor implementation**

Update `SharedFitIntentItemSelector.select(...)` to accept `extraStreamItems` and support:

```kotlin
return when (action) {
    Intent.ACTION_SEND -> {
        (listOfNotNull(extraStreamItem) + clipDataItems.filterNotNull() + listOfNotNull(dataItem)).distinct()
    }
    Intent.ACTION_SEND_MULTIPLE -> {
        (extraStreamItems.filterNotNull() + clipDataItems.filterNotNull() + listOfNotNull(dataItem)).distinct()
    }
    Intent.ACTION_VIEW -> (listOfNotNull(dataItem) + clipDataItems.filterNotNull()).distinct()
    else -> emptyList()
}
```

This keeps all standard URI sources normalized into one deduplicated candidate list before later single-file validation runs.

Give the new `extraStreamItems` parameter a default value of `emptyList()` so existing call sites and existing tests stay compiling while the task is in progress.

Update `SharedFitIntentUriExtractor` to:

```kotlin
SharedFitIntentItemSelector.select(
    action = intent.action,
    extraStreamItem = intent.getUriExtra(Intent.EXTRA_STREAM),
    extraStreamItems = intent.getUriArrayListExtraCompat(Intent.EXTRA_STREAM),
    clipDataItems = extractClipDataUris(intent.clipData),
    dataItem = intent.data,
)
```

Add a small compatibility helper in `SharedFitIntentUriExtractor`, for example:

```kotlin
private fun Intent.getUriArrayListExtraCompat(name: String): List<Uri?> {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        getParcelableArrayListExtra(name, Uri::class.java)?.toList().orEmpty()
    } else {
        @Suppress("DEPRECATION")
        getParcelableArrayListExtra<Uri>(name)?.toList().orEmpty()
    }
}
```

- [ ] **Step 8: Run the selector test file and verify it passes**

This implementation should satisfy both the new plain-`intent.data` `VIEW` test and the existing overlapping `data` plus `ClipData` dedupe regression test.

- [ ] **Step 9: Run the selector test file and verify it passes**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest`
Expected: PASS.

- [ ] **Step 10: Commit the selector work**

```bash
git add android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelector.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentUriExtractor.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelectorTest.kt
git commit -m "Expand Android share URI selection"
```

## Task 2: Add Header-Based FIT Detection

**Files:**
- Modify: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidatorTest.kt`
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidator.kt`

- [ ] **Step 1: Write the failing validator test for opaque filename plus FIT header acceptance**

Keep the existing test `accepts generic mime type when display name is fit` in `SharedFitIntentValidatorTest.kt` unchanged as an explicit regression test for generic MIME plus `.fit` filename acceptance.

```kotlin
@Test
fun `accepts fit header when file name is opaque`() {
    val errorMessage = SharedFitIntentValidator.validationError(
        uriCount = 1,
        mimeType = "application/octet-stream",
        displayName = "shared-from-provider",
        uriLastSegment = "content://provider/opaque-id",
        headerBytes = byteArrayOf(14, 0, 0, 0, 0, 0, 0, 0, '.'.code.toByte(), 'F'.code.toByte(), 'I'.code.toByte(), 'T'.code.toByte()),
    )

    assertNull(errorMessage)
}
```

- [ ] **Step 2: Write the failing validator test for non-FIT header rejection**

```kotlin
@Test
fun `rejects non-fit header when mime type and names are generic`() {
    val errorMessage = SharedFitIntentValidator.validationError(
        uriCount = 1,
        mimeType = "application/octet-stream",
        displayName = "shared-from-provider",
        uriLastSegment = "content://provider/opaque-id",
        headerBytes = byteArrayOf(1, 2, 3, 4),
    )

    assertEquals("Only FIT files are supported", errorMessage)
}
```

- [ ] **Step 3: Run the validator test file and verify both new tests fail for missing header support**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentValidatorTest`
Expected: FAIL because `headerBytes` support does not exist yet.

- [ ] **Step 4: Write the minimal validator implementation**

Update `SharedFitIntentValidator.validationError(...)` to accept `headerBytes: ByteArray?` and implement:

```kotlin
if (uriCount < 1) return "No FIT file was provided"
if (uriCount > 1) return "Only one FIT file can be shared at a time"
if (mimeType?.lowercase() in supportedMimeTypes) return null
if (candidateName.lowercase().endsWith(".fit")) return null
if (matchesFitHeader(headerBytes)) return null
return "Only FIT files are supported"
```

Give `headerBytes` a default value of `null` so the existing tests and any intermediate callers remain compiling during this task.

with:

```kotlin
private fun matchesFitHeader(headerBytes: ByteArray?): Boolean {
    if (headerBytes == null || headerBytes.size < 12) return false
    val headerSize = headerBytes[0].toInt() and 0xFF
    if (headerSize != 12 && headerSize != 14) return false
    return headerBytes[8] == '.'.code.toByte() &&
        headerBytes[9] == 'F'.code.toByte() &&
        headerBytes[10] == 'I'.code.toByte() &&
        headerBytes[11] == 'T'.code.toByte()
}
```

- [ ] **Step 5: Run the validator test file and verify it passes**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentValidatorTest`
Expected: PASS.

- [ ] **Step 6: Commit the validator change**

```bash
git add android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidator.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidatorTest.kt
git commit -m "Add FIT header validation"
```

## Task 3: Validate Copied Cache Files Without Re-Copying

**Files:**
- Create: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidatorTest.kt`
- Create: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidator.kt`
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt`

- [ ] **Step 1: Write the failing cached-file test for keeping accepted FIT files**

```kotlin
@Test
fun `keeps cached file when header validates as fit`() {
    val tempFile = temporaryFolder.newFile("activity.bin")
    tempFile.writeBytes(byteArrayOf(14, 0, 0, 0, 0, 0, 0, 0, '.'.code.toByte(), 'F'.code.toByte(), 'I'.code.toByte(), 'T'.code.toByte()))

    val errorMessage = SharedFitCachedFileValidator.validationError(
        file = tempFile,
        uriCount = 1,
        mimeType = "application/octet-stream",
        displayName = "opaque-name",
        uriLastSegment = "opaque-id",
    )

    assertNull(errorMessage)
    assertEquals(true, tempFile.exists())
}
```

- [ ] **Step 2: Write the failing cached-file test for deleting rejected files**

```kotlin
@Test
fun `deletes cached file when validation rejects non-fit content`() {
    val tempFile = temporaryFolder.newFile("activity.bin")
    tempFile.writeBytes(byteArrayOf(1, 2, 3, 4))

    val errorMessage = SharedFitCachedFileValidator.validationError(
        file = tempFile,
        uriCount = 1,
        mimeType = "application/octet-stream",
        displayName = "opaque-name",
        uriLastSegment = "opaque-id",
    )

    assertEquals("Only FIT files are supported", errorMessage)
    assertEquals(false, tempFile.exists())
}
```

- [ ] **Step 3: Write the failing cached-file test for unreadable files returning a user-facing read error**

```kotlin
@Test
fun `returns read error when cached file cannot be inspected`() {
    val missingFile = File(temporaryFolder.root, "missing.fit")

    val errorMessage = SharedFitCachedFileValidator.validationError(
        file = missingFile,
        uriCount = 1,
        mimeType = "application/octet-stream",
        displayName = "missing.fit",
        uriLastSegment = "missing.fit",
    )

    assertEquals("Unable to read shared FIT file", errorMessage)
}
```

- [ ] **Step 4: Run the cached-file validator test file and verify it fails because the helper does not exist**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitCachedFileValidatorTest`
Expected: FAIL.

- [ ] **Step 5: Write the minimal cached-file validator helper**

Create `SharedFitCachedFileValidator.kt`:

```kotlin
object SharedFitCachedFileValidator {
    fun validationError(
        file: File,
        uriCount: Int,
        mimeType: String?,
        displayName: String?,
        uriLastSegment: String?,
    ): String? {
        val headerBytes = try {
            file.inputStream().use { it.readNBytes(12) }
        } catch (_: IOException) {
            return "Unable to read shared FIT file"
        }
        val errorMessage = SharedFitIntentValidator.validationError(
            uriCount = uriCount,
            mimeType = mimeType,
            displayName = displayName,
            uriLastSegment = uriLastSegment,
            headerBytes = headerBytes,
        )
        if (errorMessage != null) {
            file.delete()
        }
        return errorMessage
    }
}
```

- [ ] **Step 6: Run the cached-file validator test file and verify it passes**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitCachedFileValidatorTest`
Expected: PASS.

- [ ] **Step 7: Wire `MainActivity` to reuse the copied cache file exactly once**

Implement a minimal flow in `createPayloadForIntent(...)`:

```kotlin
val localFile = copySharedUriToCache(acceptedUri, displayName ?: defaultDisplayName)
val validationError = SharedFitCachedFileValidator.validationError(
    file = localFile,
    uriCount = sharedUris.size,
    mimeType = intent.type,
    displayName = displayName,
    uriLastSegment = acceptedUri.lastPathSegment,
)
if (validationError != null) {
    return createErrorPayload(validationError)
}
return createDraftPayload(localFile, displayName ?: defaultDisplayName)
```

Refactor `createDraftPayload(...)` if needed so it accepts the already-copied `File` and does not copy again.

- [ ] **Step 8: Run all current Android native tests and verify they pass together**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentValidatorTest --tests cn.onelap.onelap_strava_sync.SharedFitCachedFileValidatorTest`
Expected: PASS.

- [ ] **Step 9: Commit the copied-file validation work**

```bash
git add android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidator.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidatorTest.kt
git commit -m "Reuse copied shared files for FIT validation"
```

## Task 4: Broaden Manifest Filters And Native Action Support

**Files:**
- Create: `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupportTest.kt`
- Create: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupport.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt`

- [ ] **Step 1: Write the failing action-support test for the broader action set**

```kotlin
@Test
fun `accepts send send multiple and view actions`() {
    assertEquals(true, SharedFitIntentActionSupport.isSupported(Intent.ACTION_SEND))
    assertEquals(true, SharedFitIntentActionSupport.isSupported(Intent.ACTION_SEND_MULTIPLE))
    assertEquals(true, SharedFitIntentActionSupport.isSupported(Intent.ACTION_VIEW))
}
```

Also add an explicit selector regression test in `SharedFitIntentItemSelectorTest.kt` for distinct multiple candidate URIs staying distinct after normalization, for example:

```kotlin
@Test
fun `keeps distinct multiple candidates for send multiple intents`() {
    val items: List<String> = SharedFitIntentItemSelector.select(
        action = Intent.ACTION_SEND_MULTIPLE,
        extraStreamItem = null,
        extraStreamItems = listOf("content://provider/first.fit", "content://provider/second.fit"),
        clipDataItems = emptyList(),
        dataItem = null,
    )

    assertEquals(
        listOf(
            "content://provider/first.fit",
            "content://provider/second.fit",
        ),
        items,
    )
}
```

This protects the native pre-validation behavior that still feeds a multi-file rejection when more than one normalized candidate remains.

- [ ] **Step 2: Run the action-support test and verify it fails because the helper does not exist**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentActionSupportTest`
Expected: FAIL.

- [ ] **Step 3: Write the minimal action-support helper and use it from `MainActivity`**

Create `SharedFitIntentActionSupport.kt`:

```kotlin
object SharedFitIntentActionSupport {
    fun isSupported(action: String?): Boolean {
        return action == Intent.ACTION_SEND ||
            action == Intent.ACTION_SEND_MULTIPLE ||
            action == Intent.ACTION_VIEW
    }
}
```

Replace the private action gate in `MainActivity` with the helper.

- [ ] **Step 4: Run the action-support test and verify it passes**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentActionSupportTest`
Expected: PASS.

- [ ] **Step 5: Update the manifest filters minimally**

Replace the existing FIT-specific filters in `AndroidManifest.xml` with these final filters:

```xml
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>

<intent-filter>
    <action android:name="android.intent.action.SEND_MULTIPLE" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="*/*" />
</intent-filter>

<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="content" android:mimeType="*/*" />
    <data android:scheme="file" android:mimeType="*/*" />
</intent-filter>
```

Remove the old FIT-only MIME entries and `.fit` / `.FIT` path-pattern entries entirely.

- [ ] **Step 6: Run all Android native tests again to verify no regression**

Run: `./android/gradlew testDebugUnitTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentActionSupportTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentItemSelectorTest --tests cn.onelap.onelap_strava_sync.SharedFitIntentValidatorTest --tests cn.onelap.onelap_strava_sync.SharedFitCachedFileValidatorTest`
Expected: PASS.

- [ ] **Step 7: Commit the manifest and action-gate work**

```bash
git add android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupport.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupportTest.kt
git commit -m "Broaden Android share intent filters"
```

## Task 5: Route Invalid Shares To Root-Level Prompts

**Files:**
- Modify: `test/services/share_navigation_coordinator_test.dart`
- Modify: `lib/services/share_navigation_coordinator.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Keep the existing valid-draft routing test as an explicit regression check**

Do not remove the existing test `routes the initial shared draft through the root navigator`; it is the required regression proof that valid FIT drafts still open `ShareConfirmScreen`.

- [ ] **Step 1: Write the failing widget test for cold-start invalid share staying on home and showing a prompt**

Before adding the new tests, replace the existing test named `routes native intake errors into the error-only flow` with the new cold-start invalid-share expectation so the file no longer asserts the obsolete behavior.

```dart
testWidgets('shows initial intake errors on home without opening confirm flow', (
  WidgetTester tester,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final intakeService = _FakeShareIntakeService(
    initialEvent: const SharedFitEvent.error('Only FIT files are supported'),
  );

  final coordinator = ShareNavigationCoordinator(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    shareIntakeService: intakeService,
    uploadService: _FakeUploadService.withResult(
      const SharedFitUploadResult(status: SharedFitUploadStatus.success),
    ),
  );

  await tester.pumpWidget(
    _CoordinatorHost(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      coordinator: coordinator,
    ),
  );
  await tester.pump();

  expect(find.text('HOME'), findsOneWidget);
  expect(find.text('Only FIT files are supported'), findsOneWidget);
  expect(find.text('上传到 Strava'), findsNothing);
});
```

- [ ] **Step 2: Write the failing widget test for warm-start invalid share staying on the current route**

```dart
testWidgets('shows live intake errors without leaving the current route', (
  WidgetTester tester,
) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final intakeService = _FakeShareIntakeService();

  final coordinator = ShareNavigationCoordinator(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    shareIntakeService: intakeService,
    uploadService: _FakeUploadService.withResult(
      const SharedFitUploadResult(status: SharedFitUploadStatus.success),
    ),
  );

  await tester.pumpWidget(
    _CoordinatorHost(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      coordinator: coordinator,
      initialRoute: '/details',
    ),
  );
  await tester.pumpAndSettle();

  intakeService.add(const SharedFitEvent.error('Only FIT files are supported'));
  await tester.pump();

  expect(find.text('DETAILS'), findsOneWidget);
  expect(find.text('Only FIT files are supported'), findsOneWidget);
  expect(find.text('返回首页'), findsNothing);
});
```

- [ ] **Step 3: Run the widget test file and verify both new tests fail for current navigation behavior**

Run: `flutter test test/services/share_navigation_coordinator_test.dart`
Expected: FAIL because errors currently push `ShareConfirmScreen`.

- [ ] **Step 4: Write the minimal Flutter coordination implementation**

Update `ShareNavigationCoordinator` to accept a `GlobalKey<ScaffoldMessengerState>` and branch on event type:

```dart
void _showEvent(SharedFitEvent event) {
  if (event.type == SharedFitEventType.error) {
    _showErrorSnackBar(
      event.message ?? ShareIntakeService.malformedPayloadMessage,
    );
    return;
  }
  if (_uploadActivity.isUploadActive) return;
  _showDraft(event);
}
```

Add `_showDraft(...)` for the existing push/replace route logic and `_showErrorSnackBar(...)` that clears the current snackbar and uses the root messenger key.

Update `main.dart` and the test host to provide `scaffoldMessengerKey` through `MaterialApp(scaffoldMessengerKey: ...)`.

- [ ] **Step 5: Run the widget test file and verify it passes**

Run: `flutter test test/services/share_navigation_coordinator_test.dart`
Expected: PASS.

- [ ] **Step 6: Run the share intake service tests to verify payload normalization still works**

Run: `flutter test test/services/share_intake_service_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit the Flutter error-routing work**

```bash
git add lib/main.dart lib/services/share_navigation_coordinator.dart test/services/share_navigation_coordinator_test.dart
git commit -m "Show invalid share errors without opening confirm flow"
```

## Task 6: Final Verification

**Files:**
- No new files expected

- [ ] **Step 1: Run Dart format on touched Dart files**

Run: `dart format lib/main.dart lib/services/share_navigation_coordinator.dart test/services/share_navigation_coordinator_test.dart`
Expected: formatting completes successfully.

- [ ] **Step 2: Run the full Flutter test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 3: Run the full Android unit test suite**

Run: `./android/gradlew test`
Expected: PASS.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 5: Review the final diff**

If the incremental commits from this plan were created, run:

`git diff HEAD~5..HEAD -- android/app/src/main/AndroidManifest.xml android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentUriExtractor.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelector.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidator.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupport.kt android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidator.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelectorTest.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidatorTest.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentActionSupportTest.kt android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/SharedFitCachedFileValidatorTest.kt lib/main.dart lib/services/share_navigation_coordinator.dart test/services/share_navigation_coordinator_test.dart`

If the work was not committed incrementally, run the same command with `git diff -- ...` against the working tree instead.

Expected: the diff only shows the planned intake coverage and invalid-share UX changes.

- [ ] **Step 6: Final commit if incremental commits were not kept**

```bash
git status
git add <relevant files>
git commit -m "Improve Android shared FIT intake coverage"
```

Only do this final commit if the work has not already been committed incrementally in a way the user wants to keep.
