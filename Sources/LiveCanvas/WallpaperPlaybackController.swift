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
    private var pipelines: [RenderPipeline] = []
    private var isPolicyPaused = false
    private var powerMonitor: Timer?

    deinit { NotificationCenter.default.removeObserver(self) }

    func play(item: WallpaperItem, policy: PlaybackPolicy) {
        stop()
        activeItem = item
        self.policy = policy
        _ = item.url.startAccessingSecurityScopedResource()
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
        pipelines.forEach { $0.player.pause() }
        pipelines.removeAll()
        activeItem?.url.stopAccessingSecurityScopedResource()
        activeItem = nil
        isPolicyPaused = false
        isPlaying = false
        statusText = "No wallpaper playing"
    }

    private func rebuildPanels() {
        guard let activeItem else { return }
        let resumeTime = pipelines.first?.player.currentTime()
        pipelines.forEach { $0.player.pause() }
        pipelines.removeAll()
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        for screen in NSScreen.screens {
            let player = AVQueuePlayer()
            // AVPlayerView is single-renderer oriented. A dedicated player per
            // display prevents the secondary screen from stealing video output.
            player.automaticallyWaitsToMinimizeStalling = false
            let template = AVPlayerItem(url: activeItem.url)
            template.preferredForwardBufferDuration = 0
            let looper = AVPlayerLooper(player: player, templateItem: template)
            if let resumeTime, resumeTime.isValid { player.seek(to: resumeTime, toleranceBefore: .zero, toleranceAfter: .zero) }
            // The panel uses global display coordinates, while its content view
            // must use local coordinates. Using screen.frame here pushed the
            // secondary display's video outside its own panel.
            let view = AVPlayerView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.autoresizingMask = [.width, .height]
            view.player = player
            view.controlsStyle = .none
            view.videoGravity = .resizeAspectFill

            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false, screen: screen)
            // Above the system's static desktop surface, below normal app windows
            // and desktop icons. desktopWindow is covered on some external displays.
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isOpaque = true
            panel.backgroundColor = .black
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
            pipelines.append(RenderPipeline(player: player, looper: looper))
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
                Task { @MainActor in self?.refreshWorkspacePolicy() }
            },
            center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshWorkspacePolicy() }
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

    /// macOS may announce a space transition before the fullscreen window has
    /// left the window server. Re-checking on the next run-loop turn prevents
    /// an old fullscreen frame from delaying desktop playback.
    private func refreshWorkspacePolicy() {
        applyPolicy()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            Task { @MainActor in self?.applyPolicy() }
        }
    }

    private func pausePlayers() {
        guard !isPolicyPaused else { return }
        pipelines.forEach { $0.player.pause() }
        isPolicyPaused = true
    }

    private func resumePlayers() {
        guard isPolicyPaused || pipelines.contains(where: { $0.player.timeControlStatus != .playing }) else { return }
        pipelines.forEach { $0.player.playImmediately(atRate: 1) }
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

private struct RenderPipeline {
    let player: AVQueuePlayer
    // Strongly retain the looper; AVPlayerLooper stops looping when released.
    let looper: AVPlayerLooper
}
