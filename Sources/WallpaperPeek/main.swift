import AppKit
import ServiceManagement

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

final class AppDelegate: NSObject, NSApplicationDelegate {

    private lazy var picker = PickerWindow()
    private let hotkey = HotkeyListener()
    private var isShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()

        let cfg = WPConfig.load()
        WallpaperEngine.prewarm(width: Int(cfg.thumbW), height: Int(cfg.thumbH))

        hotkey.onTrigger = { [weak self] in
            guard let self else { return }
            if self.isShowing {
                self.picker.hidePicker()
                self.isShowing = false
            } else {
                self.picker.showPicker()
                self.isShowing = true
            }
        }
        hotkey.start()

        // Reset flag whenever the picker closes itself (ESC/q/pick)
        picker.onHide = { [weak self] in self?.isShowing = false }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: picker,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing else { return }
            self.picker.hidePicker()
            self.isShowing = false
        }
    }

    private func registerLoginItem() {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .notRegistered {
                try? SMAppService.mainApp.register()
            }
        }
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
