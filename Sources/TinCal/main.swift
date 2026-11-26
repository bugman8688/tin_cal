import AppKit

// 纯 AppKit 入口：不使用 SwiftUI `App`/`Settings` 场景，
// 避免 macOS 27 在启动时自动弹出空白的设置窗口。
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    application.run()
}
