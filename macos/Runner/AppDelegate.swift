import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let sharedFitIntakeBridge = SharedFitIntakeBridge.shared
  private var hasConfiguredSharedFitChannels = false
  private var hasFinishedLaunching = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    hasFinishedLaunching = true

    configureSharedFitChannelsIfNeeded()
  }

  override func application(_ sender: NSApplication, open urls: [URL]) {
    sharedFitIntakeBridge.publishFiles(
      urls: urls,
      sourcePlatform: "macos",
      storeAsInitial: !hasFinishedLaunching
    )
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    let intakeResult = sharedFitIntakeBridge.publishFiles(
      urls: filenames.map { URL(fileURLWithPath: $0) },
      sourcePlatform: "macos",
      storeAsInitial: !hasFinishedLaunching
    )
    switch intakeResult {
    case .handledSuccess:
      sender.reply(toOpenOrPrint: .success)
    case .handledFailure, .notHandled:
      sender.reply(toOpenOrPrint: .failure)
    }
  }

  private var mainFlutterViewController: FlutterViewController? {
    return NSApplication.shared.windows
      .compactMap { $0.contentViewController as? FlutterViewController }
      .first
  }

  private func configureSharedFitChannelsIfNeeded() {
    guard !hasConfiguredSharedFitChannels,
      let flutterViewController = mainFlutterViewController
    else {
      return
    }

    sharedFitIntakeBridge.configure(binaryMessenger: flutterViewController.engine.binaryMessenger)
    hasConfiguredSharedFitChannels = true
  }
}
