import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private static let preferredContentSize = NSSize(width: 1920, height: 1080)
  private static let minimumContentSize = NSSize(width: 960, height: 540)
  private static let fixedContentAspectRatio = NSSize(width: 16, height: 9)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Keep the macOS layout on the same 1920 x 1080 design canvas at every
    // window size. AppKit enforces this ratio while the user drags any edge or
    // corner, so Flutter never crosses into a different portrait layout.
    self.contentAspectRatio = Self.fixedContentAspectRatio
    self.contentMinSize = Self.minimumContentSize
    self.collectionBehavior.insert(.fullScreenNone)
    self.setContentSize(Self.initialContentSize(for: self.screen ?? NSScreen.main))
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  private static func initialContentSize(for screen: NSScreen?) -> NSSize {
    guard let visibleSize = screen?.visibleFrame.size else {
      return preferredContentSize
    }

    // Use the requested 1920 x 1080 size when it fits. Smaller displays get
    // the largest equivalent 16:9 window that remains fully visible.
    let availableSize = NSSize(
      width: visibleSize.width * 0.96,
      height: visibleSize.height * 0.96
    )
    let scale = min(
      1,
      availableSize.width / preferredContentSize.width,
      availableSize.height / preferredContentSize.height
    )
    let fittedWidth = floor(preferredContentSize.width * scale)
    let fittedHeight = floor(fittedWidth * 9 / 16)
    return NSSize(width: fittedWidth, height: fittedHeight)
  }
}
