# WallpaperPeek

<img width="1356" height="987" alt="Screenshot 2026-07-04 at 3 39 35 AM" src="https://github.com/user-attachments/assets/c132a18d-f507-4033-adf4-2af6c147323c" />

Transparent pywal-coloured wallpaper picker for macOS built with Swift. Primarily made for Sequoia 15.7.7, but I've also tested it working on macOS 26 (Tahoe). I hit a hotkey (my case, Alt + Q) and a grid of wallpapers appear. You then either click one or navigate with arrow keys + enter to set the wallpaper. It's just a pure floating overlay with no Dock nor menu bar icon. 

*NOTE: I haven't been able to fix this bug where the overlay doesn't load quite right on first hotkey press yet. If you retoggle it with the hotkey though, it should work fine.

**NOTE: I will not be uploading my wallpapers to this repo since I do not own the artwork. Instead, I'll update a credits list on my [dotfiles](https://github.com/cynaberii/dotfiles) page so you can check out the original artists!

## Install

```bash
chmod +x install.sh
./install.sh
```

**Prerequisite**
> This build will need Swift (comes w Xcode or `xcode-select --install`). The script will build a release binary, wrap it into a `.app`, sign it, install to `/Applications`, and launch it. It'll register as a Login Item.

**First Launch**

On first launch macOS will prompt for:
- **Accessibility** (for the global hotkey)
- **Automation** (System Events) (to set the picture)

## Hotkey to pull it up

**Option + Q**

To change it, edit `Sources/WallpaperPeek/HotkeyListener.swift`:

```swift
private let triggerKeyCode: CGKeyCode = 0x0C  // Q 
private let triggerModifiers: CGEventFlags = [.maskAlternate]  // Option 
```

After that re-run `./install.sh` to rebuild.

## Wallpapers

Reads images from **`~/Downloads/wallpapers`**. You can point it to another directory by editing
`WallpaperEngine.wallpaperDir` in `Sources/WallpaperPeek/WallpaperEngine.swift`. Selecting one'll set it as the desktop background with `osascript`.

## Pywal integration

Colours are read live from `~/.cache/wal/colors.json` each time the picker opens,
so the grid always matches your current palette.

## Customising it

Same deal as WorkspacePeek, if you're not into my aesthetic, just make a `~/.config/wallpaperpeek/config.json` (read on every open, no rebuild):

```json
{ "titleText": "wallpapers", "showTitle": false }
```

- The title --> change `"titleText"`, or set `"showTitle": false` to hide it.
- Also tunable in there: title font size, and the little "active" badge on your current wallpaper (size/offsets).

### Colours

Out of the box the grid comes up pink, that's the built-in fallback palette. There's two ways to change it:

- **The proper way (pywal):** the picker reads `~/.cache/wal/colors.json` live on every open, so if you set pywal up and generate a scheme, the grid just follows your wallpaper. No rebuild needed.
- **The quick way (hardcode it):** if you don't want pywal, edit the fallback hex values in `Sources/WallpaperPeek/WalColors.swift` (the `static var fallback` block) and re-run `./install.sh`. That becomes your permanent colour scheme.

Only change the bit inside the quotes (the `"#280d2a"` part), leave the `NSColor(hex:) ?? .black` stuff alone. Here's what each field actually paints in the picker:

| What you see | Field |
|---|---|
| Panel + wallpaper tile background | `background` |
| Title header ("wallpapers") | `color7` (= `fg` in the fallback) |
| Footer text ("navigate" / "quit") | `color8` blended 50/50 with `fg` |
| Wallpaper filename label (normal) | `fg` (foreground) |
| Wallpaper filename label (selected) | `color13` |
| Wallpaper filename label (your current one) | `color3` |
| Selection ring + glow | `color13` |
| Ring around your current wallpaper | `color3` |
| "active" badge background | `color13` |
| "active" badge text | `background` |

So the big levers are `background` (the whole panel), `fg` (most of the text), and `color13` (the selection highlight + active badge). Note the footer is a *blend* of `color8` and `fg`, so if it looks too faint, lighten `color8`.

If you fat-finger a hex it just falls back to the `.white` / `.black` after the `??`, so nothing breaks, you'll just see the wrong colour and know which line to fix.

## Is this safe?

You can verify for yourself! It's all Swift w no third-party dependencies and no network code. The permissions are just for visible features, Accessibility for the hotkey, and Automation for applying the wallpapers. You can build and ad-hoc sign yourself, since this repo ships no certificate or Apple identity. 

## Uninstall

```bash
pkill -x WallpaperPeek
rm -rf /Applications/WallpaperPeek.app
```

It'll register as a Login Item. One the app is gone, the entry should clear itself. If it doesn't, remove it under **System Settings -> General -> Login Items**.
