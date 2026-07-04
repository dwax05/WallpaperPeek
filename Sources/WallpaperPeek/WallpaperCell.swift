import AppKit

final class WallpaperCell: NSView {

    let wallpaper: Wallpaper
    var onClick: (() -> Void)?

    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let ring = NSView()
    private var activeBadge: NSView?
    private let colors: WalColors
    private let cfg: WPConfig
    private let isActive: Bool

    init(wallpaper: Wallpaper, colors: WalColors, cfg: WPConfig, isActive: Bool, frame: NSRect) {
        self.wallpaper = wallpaper
        self.colors = colors
        self.cfg = cfg
        self.isActive = isActive
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        layer?.backgroundColor = colors.background.withAlphaComponent(0.6).cgColor

        ring.wantsLayer = true
        ring.layer?.cornerRadius = 10
        ring.layer?.borderWidth = 0
        ring.layer?.masksToBounds = false
        ring.frame = bounds
        ring.autoresizingMask = [.width, .height]
        addSubview(ring)

        // (NOTE: this view is NOT flipped, so y=0 is the BOTTOM!!)
        let imgInset: CGFloat = 8
        imageView.frame = NSRect(
            x: imgInset,
            y: cfg.labelH + imgInset,
            width: cfg.thumbW - imgInset * 2,
            height: cfg.thumbH
        )
        imageView.imageScaling = .scaleAxesIndependently
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.masksToBounds = true
        addSubview(imageView)

        let ph = NSImage(size: NSSize(width: cfg.thumbW - 16, height: cfg.thumbH))
        ph.lockFocus()
        colors.background.withAlphaComponent(0.4).setFill()
        NSRect(x: 0, y: 0, width: cfg.thumbW - 16, height: cfg.thumbH).fill()
        ph.unlockFocus()
        imageView.image = ph

        // (label underneath the image (bottom of the cell))
        var name = wallpaper.name
        if name.count > 24 { name = String(name.prefix(24)) + "…" }
        label.stringValue = name
        label.font = NSFont(name: "JetBrainsMono Nerd Font", size: cfg.labelFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.labelFontSize, weight: .regular)
        label.textColor = colors.foreground.withAlphaComponent(0.85)
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 4 + cfg.labelYOffset, width: cfg.thumbW, height: cfg.labelH)
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)

        if isActive { buildActiveBadge() }

        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked))
        addGestureRecognizer(click)
    }

    // Prominent "active" badge in the TOP-LEFT of the thumbnail.
    private func buildActiveBadge() {
        let bw = cfg.activeBadgeWidth, bh = cfg.activeBadgeHeight
        let imageTop = cfg.labelH + 8 + cfg.thumbH
        let badge = NSView(frame: NSRect(
            x: 14,
            y: imageTop - bh - 6 + cfg.activeBadgeYOffset,
            width: bw, height: bh
        ))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = colors.color13.cgColor
        badge.layer?.cornerRadius = 6
        badge.shadow = {
            let s = NSShadow()
            s.shadowColor = colors.background.withAlphaComponent(0.8)
            s.shadowBlurRadius = 4
            s.shadowOffset = NSSize(width: 0, height: -1)
            return s
        }()

        let txt = NSTextField(labelWithString: "● active")
        txt.font = NSFont(name: "JetBrainsMono Nerd Font", size: cfg.activeBadgeFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: cfg.activeBadgeFontSize, weight: .bold)
        txt.textColor = colors.background
        txt.alignment = .center
        // text offset inside the pill (positive = up in non-flipped coords)
        txt.frame = NSRect(x: 0, y: cfg.activeBadgeTextYOffset, width: bw, height: bh)
        txt.isBordered = false
        txt.drawsBackground = false
        badge.addSubview(txt)

        addSubview(badge, positioned: .above, relativeTo: imageView)
        activeBadge = badge
    }

    func setImage(_ image: NSImage) {
        imageView.image = image
    }

    func setSelected(_ selected: Bool) {
        ring.layer?.borderWidth = selected ? cfg.selBorderWidth : (isActive ? 2 : 0)
        ring.layer?.borderColor = selected
            ? colors.color13.cgColor
            : (isActive ? colors.color3.cgColor : colors.color1.withAlphaComponent(0.0).cgColor)

        if selected {
            ring.layer?.shadowColor = colors.color13.cgColor
            ring.layer?.shadowRadius = cfg.selGlowRadius
            ring.layer?.shadowOpacity = Float(cfg.selGlowOpacity)
            ring.layer?.shadowOffset = .zero
        } else if isActive {
            ring.layer?.shadowColor = colors.color3.cgColor
            ring.layer?.shadowRadius = cfg.selGlowRadius * 0.6
            ring.layer?.shadowOpacity = 0.6
            ring.layer?.shadowOffset = .zero
        } else {
            ring.layer?.shadowOpacity = 0
        }

        label.textColor = selected
            ? colors.color13
            : (isActive ? colors.color3 : colors.foreground.withAlphaComponent(0.85))
    }

    @objc private func clicked() { onClick?() }
}
