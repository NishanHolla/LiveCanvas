import AppKit
import AVFoundation
import SwiftUI

struct WallpaperItem: Identifiable, Codable, Hashable {
    let id: UUID
    let url: URL
    var title: String
    var duration: Double
    var addedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.duration = AVURLAsset(url: url).duration.seconds
        self.addedAt = .now
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
        let urls = items.map(\.url.absoluteString)
        UserDefaults.standard.set(urls, forKey: "wallpaperURLs")
    }

    private func restore() {
        let urls = UserDefaults.standard.stringArray(forKey: "wallpaperURLs") ?? []
        items = urls.compactMap { URL(string: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }.map(WallpaperItem.init)
        selectedID = items.first?.id
    }
}
