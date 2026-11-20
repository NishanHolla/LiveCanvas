import AppKit
import AVKit

@MainActor
final class WallpaperPlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var statusText = "No wallpaper playing"
    private var panels: [NSPanel] = []
    private var observers: [NSObjectProtocol] = []
    private var activeItem: WallpaperItem?
    private var policy: PlaybackPolicy = .always
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var isPolicyPaused = false
    private var powerMonitor: Timer?

    deinit { NotificationCenter.default.removeObserver(self) }

    func play(item: WallpaperItem, policy: PlaybackPolicy) {
        stop()
        activeItem = item
        self.policy = policy
        _ = item.url.startAccessingSecurityScopedResource()
        let sharedPlayer = AVQueuePlayer()
        player = sharedPlayer
        looper = AVPlayerLooper(player: sharedPlayer, templateItem: AVPlayerItem(url: item.url))
        rebuildPanels()
        observeLifecycle()
        isPlaying = true
        statusText = "Playing \(item.title)"
        applyPolicy()
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        powerMonitor?.invalidate()
        powerMonitor = nil
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        player?.pause()
        player = nil
        looper = nil
        activeItem?.url.stopAccessingSecurityScopedResource()
        activeItem = nil
        isPolicyPaused = false
        isPlaying = false
        statusText = "No wallpaper playing"
    }

    private func rebuildPanels() {
        guard let player else { return }
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        for screen in NSScreen.screens {
            let view = AVPlayerView(frame: screen.frame)
            view.player = player
            view.controlsStyle = .none
            view.videoGravity = .resizeAspectFill

            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false, screen: screen)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }
    }

    private func observeLifecycle() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.applyPolicy() }
            },
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pausePlayers() }
            },
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.applyPolicy() }
            },
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.applyPolicy() }
            },
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.rebuildPanels()
                    self?.applyPolicy()
                }
            }
        ]
        // AppKit has no power-mode notification on all supported macOS releases.
        // A low-frequency poll keeps this policy current with negligible overhead.
        powerMonitor = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyPolicy() }
        }
    }

    private func applyPolicy() {
        guard isPlaying else { return }
        if policy == .pauseOnBattery && ProcessInfo.processInfo.isLowPowerModeEnabled {
            pausePlayers()
            statusText = "Paused for Low Power Mode"
        } else if policy == .pauseWhenFullscreen && frontmostAppOccupiesAScreen() {
            pausePlayers()
            statusText = "Paused for a fullscreen app"
        } else {
            resumePlayers()
            statusText = activeItem.map { "Playing \($0.title)" } ?? "Playing"
        }
    }

    private func pausePlayers() {
        guard !isPolicyPaused else { return }
        player?.pause()
        isPolicyPaused = true
    }

    private func resumePlayers() {
        guard isPolicyPaused || player?.timeControlStatus != .playing else { return }
        player?.play()
        isPolicyPaused = false
    }

    private func frontmostAppOccupiesAScreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (window[kCGWindowLayer as String] as? Int ?? 1) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            let frame = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
            return NSScreen.screens.contains { screen in
                abs(frame.width - screen.frame.width) < 3 && abs(frame.height - screen.frame.height) < 3
            }
        }
    }
}
