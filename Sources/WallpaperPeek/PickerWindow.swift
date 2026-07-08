import AppKit

struct WPConfig {
    var columns: Int = 6
    var thumbW: CGFloat = 210
    var thumbH: CGFloat = 130
    var pad: CGFloat = 10
    var labelH: CGFloat = 28
    var cornerRadius: CGFloat = 8
    var titleText: String = "˚ ₊‧꒰ა  ✦ ˚  · ˚  wallpapers  ˚ ·  ˚ ✦  ໒꒱ ‧₊˚"
    var titleFontSize: CGFloat = 16
    var titleYOffset: CGFloat = 0
    var showTitle: Bool = true
    // (for thumbnail labels n stuff)
    var labelFontSize: CGFloat = 11
    var labelYOffset: CGFloat = 0
    // (for the active badge on the active wallpaper)
    var activeBadgeFontSize: CGFloat = 11
    var activeBadgeYOffset: CGFloat = 0
    var activeBadgeTextYOffset: CGFloat = 0
    var activeBadgeWidth: CGFloat = 74
    var activeBadgeHeight: CGFloat = 22
    // (footer)
    var footerFontSize: CGFloat = 11
    // (selected wallpaper glow and stuff)
    var selBorderWidth: CGFloat = 2.5
    var selGlowRadius: CGFloat = 12
    var selGlowOpacity: CGFloat = 0.9
    var panelYOffset: CGFloat = 0   // + moves whole panel down not up!!

    static func load() -> WPConfig {
        var cfg = WPConfig()
        let path = NSString(string: "~/.config/wallpaperpeek/config.json").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return cfg }
        func d(_ k: String) -> CGFloat? { (json[k] as? Double).map { CGFloat($0) } }
        if let v = json["columns"] as? Int { cfg.columns = v }
        if let v = d("thumbW") { cfg.thumbW = v }
        if let v = d("thumbH") { cfg.thumbH = v }
        if let v = d("pad") { cfg.pad = v }
        if let v = d("labelH") { cfg.labelH = v }
        if let v = d("cornerRadius") { cfg.cornerRadius = v }
        if let v = d("titleFontSize") { cfg.titleFontSize = v }
        if let v = d("titleYOffset") { cfg.titleYOffset = v }
        if let v = d("labelFontSize") { cfg.labelFontSize = v }
        if let v = d("labelYOffset") { cfg.labelYOffset = v }
        if let v = d("activeBadgeFontSize") { cfg.activeBadgeFontSize = v }
        if let v = d("activeBadgeYOffset") { cfg.activeBadgeYOffset = v }
        if let v = d("activeBadgeTextYOffset") { cfg.activeBadgeTextYOffset = v }
        if let v = d("activeBadgeWidth") { cfg.activeBadgeWidth = v }
        if let v = d("activeBadgeHeight") { cfg.activeBadgeHeight = v }
        if let v = d("footerFontSize") { cfg.footerFontSize = v }
        if let v = d("selBorderWidth") { cfg.selBorderWidth = v }
        if let v = d("selGlowRadius") { cfg.selGlowRadius = v }
        if let v = d("selGlowOpacity") { cfg.selGlowOpacity = v }
        if let v = d("panelYOffset") { cfg.panelYOffset = v }
        if let s = json["titleText"] as? String { cfg.titleText = s }
        if let b = json["showTitle"] as? Bool { cfg.showTitle = b }
        return cfg
    }
}

final class PickerWindow: NSPanel {

    // A grid slot is either a wallpaper, a subfolder, or the ".." parent entry.
    private enum GridItem {
        case wallpaper(Wallpaper)
        case folder(URL)
        case parent(URL)   // URL to navigate up to
    }

    private var items: [GridItem] = []
    private var cells: [WallpaperCell] = []
    private var selectedIndex = 0
    private var activeWallpaperPath: String?
    private var colors: WalColors = .current
    private var cfg = WPConfig()

    // Folder browsing: `currentDir` is the directory being shown; `showFolders`
    // toggles subfolder cells (and ".." navigation) via the `f` key.
    private var currentDir = WallpaperEngine.wallpaperDir
    private var showFolders = false

    private var atRoot: Bool {
        currentDir.standardizedFileURL.path == WallpaperEngine.wallpaperDir.standardizedFileURL.path
    }

    // Persistent contentView. A fresh NSVisualEffectView (blendingMode
    // .behindWindow) swapped into a live window doesn't get its backdrop
    // recomposited by the window server unless the frame also changes, so a
    // folder navigation that keeps the same window size rendered blank. Reuse
    // one effect view and rebuild only its inner subviews on each render.
    private var container: NSVisualEffectView?
    private var scrollView: NSScrollView!
    private var gridContainer: NSView!
    private var footerLabel: NSTextField!
    private var titleLabel: NSTextField?

    override init(contentRect: NSRect, styleMask: NSWindow.StyleMask, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func showPicker() {
        colors = .current
        cfg = WPConfig.load()
        currentDir = WallpaperEngine.wallpaperDir
        showFolders = false
        reloadItems()
        activeWallpaperPath = WallpaperEngine.currentWallpaper()
        selectedIndex = indexOfActive() ?? 0
        // buildUI (via render) sizes the window to its final frame before
        // creating the container, so the first open is laid out correctly.
        render()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Rebuild `items` for `currentDir`. Folder cells (and ".." when not at the
    // root) are prepended only while `showFolders` is on.
    private func reloadItems() {
        var next: [GridItem] = []
        if showFolders {
            if !atRoot { next.append(.parent(currentDir.deletingLastPathComponent())) }
            for sub in WallpaperEngine.listSubdirectories(in: currentDir) { next.append(.folder(sub)) }
        }
        for wp in WallpaperEngine.listWallpapers(in: currentDir) { next.append(.wallpaper(wp)) }
        items = next
    }

    private func indexOfActive() -> Int? {
        guard let active = activeWallpaperPath else { return nil }
        let activeName = (active as NSString).lastPathComponent
        return items.firstIndex {
            if case .wallpaper(let wp) = $0 {
                return wp.url.path == active || wp.url.lastPathComponent == activeName
            }
            return false
        }
    }

    // Rebuild the whole UI for the current `items` (used on open and on any
    // folder navigation / toggle).
    private func render() {
        buildUI()
        loadThumbnailsAsync()
        DispatchQueue.main.async { [weak self] in self?.scrollToSelected(center: true) }
    }

    private func navigate(to dir: URL) {
        currentDir = dir
        reloadItems()
        selectedIndex = 0
        render()
    }

    private func toggleFolders() {
        showFolders.toggle()
        reloadItems()
        selectedIndex = 0
        render()
    }

    var onHide: (() -> Void)?

    func hidePicker() {
        orderOut(nil)
        cells = []
        onHide?()
    }

    private func buildUI() {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame

        let cellW = cfg.thumbW + cfg.pad
        let cellH = cfg.thumbH + cfg.labelH + 16 + cfg.pad  // +8 gap above label
        let winW = CGFloat(cfg.columns) * cellW + cfg.pad * 2 + 16
        let rows = (items.count + cfg.columns - 1) / cfg.columns
        let gridH = CGFloat(rows) * cellH + cfg.pad
        let chromeH: CGFloat = 58 + 40  // title + footer
        let winH = min(sf.height - 80, gridH + chromeH)

        // Size the window to its final frame BEFORE building the container and
        // subviews. Assigning `contentView` sizes the container to the current
        // window content size; if the window is still tiny (first open) every
        // subview gets laid out against the wrong geometry and the content ends
        // up scaled/offset (only the bottom-left corner visible). Positioning
        // first means the container fills the correct size from the start.
        positionWindow(width: winW, height: winH)

        let container: NSVisualEffectView
        if let existing = self.container {
            container = existing
            container.subviews.forEach { $0.removeFromSuperview() }
            container.frame = NSRect(x: 0, y: 0, width: winW, height: winH)
        } else {
            container = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: winW, height: winH))
            container.material = .hudWindow
            container.blendingMode = .behindWindow
            container.state = .active
            container.wantsLayer = true
            container.layer?.cornerRadius = 16
            container.layer?.masksToBounds = true
            container.layer?.contentsScale = backingScaleFactor
            self.container = container
            contentView = container
        }

        // (Title bar)
        if cfg.showTitle {
            let titleBar = NSView(frame: NSRect(x: 0, y: winH - 50 + cfg.titleYOffset, width: winW, height: 50))
            titleBar.autoresizingMask = [.width, .minYMargin]
            container.addSubview(titleBar)

            let tl = NSTextField(labelWithString: cfg.titleText)
            tl.font = NSFont(name: "JetBrainsMono Nerd Font", size: cfg.titleFontSize)
                ?? NSFont.monospacedSystemFont(ofSize: cfg.titleFontSize, weight: .medium)
            tl.textColor = colors.color7
            tl.alignment = .center
            tl.frame = titleBar.bounds
            tl.autoresizingMask = [.width, .height]
            titleBar.addSubview(tl)
            titleLabel = tl
        }

        // (Footer stuff)
        let footerBar = NSView(frame: NSRect(x: 0, y: 0, width: winW, height: 34))
        footerBar.autoresizingMask = [.width, .maxYMargin]
        container.addSubview(footerBar)

        footerLabel = NSTextField(labelWithString: "")
        footerLabel.font = NSFont(name: "JetBrainsMono Nerd Font", size: cfg.footerFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.footerFontSize, weight: .regular)
        footerLabel.textColor = colors.color8.blended(withFraction: 0.5, of: colors.foreground) ?? colors.foreground
        footerLabel.alignment = .center
        footerLabel.frame = footerBar.bounds
        footerLabel.autoresizingMask = [.width, .height]
        footerBar.addSubview(footerLabel)

        // (Scroll view for the grid)
        scrollView = NSScrollView(frame: NSRect(x: 0, y: 34, width: winW, height: winH - 84))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        container.addSubview(scrollView)

        let docHeight = max(gridH, scrollView.frame.height)
        gridContainer = FlippedView(frame: NSRect(x: 0, y: 0, width: winW - 16, height: docHeight))
        scrollView.documentView = gridContainer

        buildCells()
        updateFooter()
    }

    private func buildCells() {
        cells.forEach { $0.removeFromSuperview() }
        cells = []

        let cellW = cfg.thumbW + cfg.pad
        let cellH = cfg.thumbH + cfg.labelH + 16 + cfg.pad

        for (i, item) in items.enumerated() {
            let row = i / cfg.columns
            let col = i % cfg.columns
            let x = cfg.pad + CGFloat(col) * cellW
            let y = cfg.pad + CGFloat(row) * cellH

            let kind: WallpaperCell.Kind
            var isActive = false
            switch item {
            case .wallpaper(let wp):
                kind = .wallpaper(wp)
                isActive = (wp.url.path == activeWallpaperPath) ||
                    (activeWallpaperPath.map { ($0 as NSString).lastPathComponent == wp.url.lastPathComponent } ?? false)
            case .folder(let url):
                kind = .folder(name: url.lastPathComponent, isParent: false)
            case .parent:
                kind = .folder(name: "..", isParent: true)
            }

            let cell = WallpaperCell(
                kind: kind,
                colors: colors,
                cfg: cfg,
                isActive: isActive,
                frame: NSRect(x: x, y: y, width: cfg.thumbW, height: cfg.thumbH + cfg.labelH + 16)
            )
            cell.onClick = { [weak self] in
                guard let self else { return }
                if i == self.selectedIndex { self.activate() }
                else { self.select(i) }
            }
            cell.setSelected(i == selectedIndex)
            if case .wallpaper(let wp) = item, let warm = WallpaperEngine.memThumbnail(wp.url) {
                cell.setImage(warm)
            }
            gridContainer.addSubview(cell)
            cells.append(cell)
        }
    }

    private func loadThumbnailsAsync() {
        let w = Int(cfg.thumbW), h = Int(cfg.thumbH)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            for (i, item) in self.items.enumerated() {
                guard case .wallpaper(let wp) = item else { continue }
                if let thumb = WallpaperEngine.thumbnail(for: wp.url, width: w, height: h) {
                    DispatchQueue.main.async {
                        guard i < self.cells.count else { return }
                        self.cells[i].setImage(thumb)
                    }
                }
            }
        }
    }

    private func positionWindow(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let sf = screen.visibleFrame
        // (panelYOffset + moves the whole panel DOWN not UP!!)
        setFrame(NSRect(
            x: sf.midX - width / 2,
            y: sf.midY - height / 2 - cfg.panelYOffset,
            width: width, height: height
        ), display: true)
    }

    private func select(_ index: Int) {
        guard index >= 0, index < items.count else { return }
        cells[selectedIndex].setSelected(false)
        selectedIndex = index
        cells[selectedIndex].setSelected(true)
        updateFooter()
        scrollToSelected()
    }

    private func scrollToSelected(center: Bool = false) {
        guard selectedIndex < cells.count else { return }
        let cell = cells[selectedIndex]
        if center {
            let clip = scrollView.contentView
            // Force layout so we read the real clip size. On the async tick right
            // after opening, clip.bounds.height can still be the unlaid-out
            // default, which threw the clamp off and scrolled the grid out of
            // view. scrollView.frame.height is set synchronously in buildUI, so
            // use it as the source of truth (overlay scrollers add no insets).
            scrollView.layoutSubtreeIfNeeded()
            let clipH = scrollView.frame.height
            let docH = gridContainer.frame.height
            var y = cell.frame.midY - clipH / 2
            y = max(0, min(y, max(0, docH - clipH)))
            clip.scroll(to: NSPoint(x: 0, y: y))
            scrollView.reflectScrolledClipView(clip)
        } else {
            gridContainer.scrollToVisible(cell.frame.insetBy(dx: 0, dy: -cfg.pad * 2))
        }
    }

    private func updateFooter() {
        guard selectedIndex < items.count else { return }
        var name: String
        let action: String
        switch items[selectedIndex] {
        case .wallpaper(let wp): name = wp.name; action = "↵ set wallpaper"
        case .folder(let url): name = " " + url.lastPathComponent; action = "↵ open folder"
        case .parent: name = " .."; action = "↵ go up"
        }
        if name.count > 30 { name = String(name.prefix(29)) + "…" }
        let folderHint = showFolders ? "f hide folders" : "f folders"
        footerLabel.stringValue = "✦  \(name)   ·   ↑↓←→ navigate   ·   \(action)   ·   \(folderHint)   ·   q quit  ✦"
    }

    // Enter/click on the selected item: descend into folders, set wallpapers.
    private func activate() {
        guard selectedIndex < items.count else { return }
        switch items[selectedIndex] {
        case .folder(let url), .parent(let url):
            navigate(to: url)
        case .wallpaper(let wp):
            hidePicker()
            DispatchQueue.global(qos: .userInitiated).async {
                WallpaperEngine.setWallpaper(wp.url)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        let cols = cfg.columns
        switch event.keyCode {
        case 53: hidePicker()                       // ESC
        case 12: hidePicker()                       // q
        case 36: activate()                         // Return
        case 3: toggleFolders()                     // f
        case 51:                                    // Delete / Backspace: go up
            if showFolders && !atRoot { navigate(to: currentDir.deletingLastPathComponent()) }
        case 123, 4: select(selectedIndex - 1)      // Left / h
        case 124, 37: select(selectedIndex + 1)     // Right / l
        case 126, 40: select(selectedIndex - cols)  // Up / k
        case 125, 38: select(selectedIndex + cols)  // Down / j
        default: break
        }
    }
}

// Flipped view so grid lays out top-to-bottom
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
