import AppKit
import AVFoundation
import SwiftUI

struct WallpaperItem: Identifiable, Codable, Hashable {
    let id: UUID
    var url: URL
    var title: String
    var duration: Double
    var addedAt: Date
    fileprivate var bookmark: Data?

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.duration = AVURLAsset(url: url).duration.seconds
        self.addedAt = .now
        self.bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
}

enum PlaybackPolicy: String, CaseIterable, Codable, Identifiable {
    case always
    case pauseOnBattery
    case pauseWhenFullscreen

    var id: String { rawValue }
    var label: String {
        switch self {
        case .always: "Always play"
        case .pauseOnBattery: "Pause on battery"
        case .pauseWhenFullscreen: "Pause during fullscreen apps"
        }
    }
}

@MainActor
final class WallpaperLibrary: ObservableObject {
    @Published private(set) var items: [WallpaperItem] = []
    @Published var selectedID: WallpaperItem.ID?
    @AppStorage("playbackPolicy") var policy: PlaybackPolicy = .pauseOnBattery

    var selectedItem: WallpaperItem? { items.first { $0.id == selectedID } }

    init() { restore() }

    func importVideo() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls where !items.contains(where: { $0.url == url }) {
            let item = WallpaperItem(url: url)
            items.append(item)
            selectedID = item.id
        }
        persist()
    }

    func removeSelected() {
        guard let selectedID else { return }
        items.removeAll { $0.id == selectedID }
        self.selectedID = items.first?.id
        persist()
    }

    func playRandom(using playback: WallpaperPlaybackController) {
        guard let item = items.randomElement() else { return }
        selectedID = item.id
        playback.play(item: item, policy: policy)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: "wallpaperLibrary")
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: "wallpaperLibrary"),
              let saved = try? JSONDecoder().decode([WallpaperItem].self, from: data) else { return }
        items = saved.compactMap { item -> WallpaperItem? in
            guard let bookmark = item.bookmark else {
                return FileManager.default.fileExists(atPath: item.url.path) ? item : nil
            }
            var stale = false
            guard let resolvedURL = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale),
                  FileManager.default.fileExists(atPath: resolvedURL.path) else { return nil }
            var restored = item
            restored.url = resolvedURL
            return restored
        }
        selectedID = items.first?.id
    }
}
