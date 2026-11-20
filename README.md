# LiveCanvas

An original, local-first macOS live-wallpaper app inspired by the useful interaction patterns of modern wallpaper tools. It does not copy Wallper code, branding, assets, or service integrations.

## Features

- Import local `.mp4` and `.mov` files
- One shared AVFoundation decode pipeline rendered across every display
- Menu-bar Shuffle and Stop controls
- Persistent local library (only URLs are stored locally)
- Automatic pause/resume for Low Power Mode, sleep/wake, fullscreen apps, and display changes
- Security-scoped bookmarks so imported media remains available after relaunches or moves
- Native SwiftUI + AppKit + AVFoundation, with no daemon or helper process

## Requirements

macOS 14+ and Xcode 16 / Swift 6.1.

## Run

```sh
swift run
```

Use **Import** to add a movie, select it, then choose **Set Live Wallpaper**.

### Build an app bundle

```sh
./scripts/build-app.sh
open dist/LiveCanvas.app
```

The script produces an ad-hoc-signed app bundle. To distribute outside your own Mac, sign with a Developer ID Application certificate and notarize the archive with Apple.

## Deliberate boundaries

This project uses documented public APIs for desktop-level video playback. Native animated Lock Screen / screen-saver registration is controlled by Apple’s OS pipeline and may require a specific macOS version and entitlements; it is not simulated by an overlay or private API.

## License

MIT
