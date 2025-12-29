import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var securityOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // SECURITY: Add screenshot/screen recording protection
    setupScreenshotProtection()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupScreenshotProtection() {
    // Listen for screenshot notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )

    // Listen for screen capture (recording) - iOS 11+
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureStatusDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }

  @objc private func userDidTakeScreenshot() {
    // Log or alert user that screenshot was taken
    // In a real app, you might want to show an alert warning about security
    print("WARNING: Screenshot detected - sensitive data may have been captured")
  }

  @objc private func screenCaptureStatusDidChange() {
    if UIScreen.main.isCaptured {
      // Screen is being recorded - show security overlay
      showSecurityOverlay()
    } else {
      // Recording stopped - remove overlay
      hideSecurityOverlay()
    }
  }

  private func showSecurityOverlay() {
    guard securityOverlay == nil, let window = self.window else { return }

    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.tag = 999

    let label = UILabel()
    label.text = "Screen recording detected.\nContent hidden for security."
    label.textColor = .white
    label.textAlignment = .center
    label.numberOfLines = 0
    label.translatesAutoresizingMaskIntoConstraints = false

    overlay.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 20),
      label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -20)
    ])

    window.addSubview(overlay)
    securityOverlay = overlay
  }

  private func hideSecurityOverlay() {
    securityOverlay?.removeFromSuperview()
    securityOverlay = nil
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    // SECURITY: Hide content when app goes to background (app switcher)
    showSecurityOverlay()
    super.applicationWillResignActive(application)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Show content again when app becomes active (unless screen is being recorded)
    if !UIScreen.main.isCaptured {
      hideSecurityOverlay()
    }
    super.applicationDidBecomeActive(application)
  }
}
