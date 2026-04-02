import Flutter
import Foundation

enum SharedFitIntakeResult {
  case notHandled
  case handledSuccess
  case handledFailure
}

final class SharedFitIntakeBridge: NSObject, FlutterStreamHandler {
  static let shared = SharedFitIntakeBridge()

  private let methodChannelName = "onelap_strava_sync/share_intake"
  private let eventChannelName = "onelap_strava_sync/shared_fit_events"
  private let initialShareMethod = "getInitialSharedFit"
  private let draftType = "draft"
  private let errorType = "error"
  private let defaultDisplayName = "shared.fit"

  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []
  private var initialPayload: [String: Any]?

  private override init() {
    super.init()
  }

  func configure(binaryMessenger: FlutterBinaryMessenger) {
    guard methodChannel == nil || eventChannel == nil else {
      return
    }

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: binaryMessenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case self.initialShareMethod:
        result(self.initialPayload)
        self.initialPayload = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: binaryMessenger
    )
    eventChannel.setStreamHandler(self)

    self.methodChannel = methodChannel
    self.eventChannel = eventChannel
  }

  @discardableResult
  func publishFiles(urls: [URL], sourcePlatform: String, storeAsInitial: Bool) -> SharedFitIntakeResult {
    let intakeResult = intakePayload(for: urls, sourcePlatform: sourcePlatform)
    guard let payload = intakeResult.payload else {
      return .notHandled
    }

    if storeAsInitial {
      initialPayload = payload
    } else {
      publish(payload: payload)
    }

    return intakeResult.result
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    flushPendingEvents()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func validationError(for urls: [URL]) -> String? {
    if urls.isEmpty {
      return "No FIT file was provided"
    }

    if urls.count > 1 {
      return "Only one FIT file can be shared at a time"
    }

    let fileName = urls[0].lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    if fileName.lowercased().hasSuffix(".fit") {
      return nil
    }

    return "Only FIT files are supported"
  }

  private func intakePayload(for urls: [URL], sourcePlatform: String) -> (
    result: SharedFitIntakeResult,
    payload: [String: Any]?
  ) {
    if urls.isEmpty {
      return (.notHandled, nil)
    }

    if urls.count > 1 {
      return (
        .handledFailure,
        createErrorPayload(
          message: "Only one FIT file can be shared at a time",
          sourcePlatform: sourcePlatform
        )
      )
    }

    let fileURL = urls[0]
    let fileName = fileURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    guard fileName.lowercased().hasSuffix(".fit") else {
      return (.notHandled, nil)
    }

    if let validationError = validationError(for: urls) {
      return (
        .handledFailure,
        createErrorPayload(message: validationError, sourcePlatform: sourcePlatform)
      )
    }

    let payload = createPayload(for: fileURL, sourcePlatform: sourcePlatform)
    if payload["message"] is String {
      return (.handledFailure, payload)
    }

    return (.handledSuccess, payload)
  }

  private func createPayload(for url: URL, sourcePlatform: String) -> [String: Any] {
    do {
      let displayName = resolveDisplayName(for: url)
      let localURL = try copySharedFileToTemporaryStorage(url: url, displayName: displayName)
      return [
        "type": draftType,
        "localFilePath": localURL.path,
        "displayName": displayName,
        "sourcePlatform": sourcePlatform,
        "receivedAt": utcTimestamp(),
      ]
    } catch {
      return createErrorPayload(
        message: clearErrorMessage(error),
        sourcePlatform: sourcePlatform
      )
    }
  }

  private func resolveDisplayName(for url: URL) -> String {
    let fileName = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
    return fileName.isEmpty ? defaultDisplayName : fileName
  }

  private func copySharedFileToTemporaryStorage(url: URL, displayName: String) throws -> URL {
    let fileManager = FileManager.default
    let cacheDirectory = fileManager.temporaryDirectory.appendingPathComponent(
      "shared-fit-intake",
      isDirectory: true
    )
    try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

    let localURL = cacheDirectory.appendingPathComponent(uniqueCacheFileName(displayName))
    if fileManager.fileExists(atPath: localURL.path) {
      try fileManager.removeItem(at: localURL)
    }

    let accessGranted = url.startAccessingSecurityScopedResource()
    defer {
      if accessGranted {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      try fileManager.copyItem(at: url, to: localURL)
      return localURL
    } catch {
      if fileManager.fileExists(atPath: localURL.path) {
        try? fileManager.removeItem(at: localURL)
      }
      throw error
    }
  }

  private func uniqueCacheFileName(_ displayName: String) -> String {
    return "\(Int(Date().timeIntervalSince1970 * 1000))-\(sanitizeFileName(displayName))"
  }

  private func sanitizeFileName(_ displayName: String) -> String {
    let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmedName.isEmpty {
      return defaultDisplayName
    }

    let invalidCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
    let sanitizedScalars = trimmedName.unicodeScalars.map { scalar in
      invalidCharacters.contains(scalar) ? "_" : String(scalar)
    }
    let sanitizedName = sanitizedScalars.joined()
    return sanitizedName.isEmpty ? defaultDisplayName : sanitizedName
  }

  private func publish(payload: [String: Any]) {
    guard let eventSink else {
      pendingEvents.append(payload)
      return
    }

    eventSink(payload)
  }

  private func flushPendingEvents() {
    guard let eventSink else {
      return
    }

    for payload in pendingEvents {
      eventSink(payload)
    }
    pendingEvents.removeAll()
  }

  private func createErrorPayload(message: String, sourcePlatform: String) -> [String: Any] {
    return [
      "type": errorType,
      "message": message,
      "sourcePlatform": sourcePlatform,
      "receivedAt": utcTimestamp(),
    ]
  }

  private func clearErrorMessage(_ error: Error) -> String {
    let detail = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    if detail.isEmpty {
      return "Unable to read shared FIT file"
    }

    return "Unable to read shared FIT file: \(detail)"
  }

  private func utcTimestamp() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: Date())
  }
}
