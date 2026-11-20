import AppKit
import AVKit
import Combine

@MainActor
final class WallpaperPlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var statusText = "No wallpaper playing"
    private var panels: [NSPanel] = []
    private var observers: [NSObjectProtocol] = []
    private var activeItem: WallpaperItem?
    private var policy: PlaybackPolicy = .always

    deinit { NotificationCenter.default.removeObserver(self) }

    func play(item: WallpaperItem, policy: PlaybackPolicy) {
        stop()
        activeItem = item
        self.policy = policy
        for screen in NSScreen.screens {
            let player = AVQueuePlayer(url: item.url)
            let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: item.url))
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
            objc_setAssociatedObject(panel, "player", player, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            objc_setAssociatedObject(panel, "looper", looper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            player.play()
            panels.append(panel)
        }
        observePolicy()
        isPlaying = true
        statusText = "Playing \(item.title)"
        applyPolicy()
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        panels.forEach { panel in
            (objc_getAssociatedObject(panel, "player") as? AVPlayer)?.pause()
            panel.orderOut(nil)
        }
        panels.removeAll()
        isPlaying = false
        statusText = "No wallpaper playing"
    }

    private func observePolicy() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.applyPolicy() }
            },
            center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pausePlayers() }
            }
        ]
    }

    private func applyPolicy() {
        guard isPlaying else { return }
        if policy == .pauseOnBattery && ProcessInfo.processInfo.isLowPowerModeEnabled {
            pausePlayers()
            statusText = "Paused for Low Power Mode"
        } else {
            resumePlayers()
            statusText = activeItem.map { "Playing \($0.title)" } ?? "Playing"
        }
    }

    private func pausePlayers() { panels.compactMap { objc_getAssociatedObject($0, "player") as? AVPlayer }.forEach { $0.pause() } }
    private func resumePlayers() { panels.compactMap { objc_getAssociatedObject($0, "player") as? AVPlayer }.forEach { $0.play() } }
}
