# LiveCanvas

An original, local-first macOS live-wallpaper app inspired by the useful interaction patterns of modern wallpaper tools. It does not copy Wallper code, branding, assets, or service integrations.

## Features

- Import local `.mp4` and `.mov` files
- Loop a selected video behind the desktop on every display
- Menu-bar Shuffle and Stop controls
- Persistent local library (only URLs are stored locally)
- Low Power Mode pause option
- Native SwiftUI + AppKit + AVFoundation, with no daemon or helper process

## Requirements

macOS 14+ and Xcode 16 / Swift 6.1.

## Run

```sh
swift run
```

Use **Import** to add a movie, select it, then choose **Set Live Wallpaper**.

## Deliberate boundaries

This project uses documented public APIs for desktop-level video playback. Native animated Lock Screen / screen-saver registration is controlled by Apple’s OS pipeline and may require a specific macOS version and entitlements; it is not simulated by an overlay or private API.

## License

MIT
