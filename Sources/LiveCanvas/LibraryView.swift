import AVFoundation
import AVKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: WallpaperLibrary
    @EnvironmentObject private var playback: WallpaperPlaybackController

    var body: some View {
        NavigationSplitView {
            List(selection: $library.selectedID) {
                Section("My videos") {
                    ForEach(library.items) { item in
                        Label(item.title, systemImage: "play.rectangle.fill")
                            .tag(item.id)
                    }
                }
            }
            .navigationTitle("Library")
        } detail: {
            VStack(spacing: 22) {
                if let item = library.selectedItem {
                    VideoPreview(url: item.url)
                        .frame(maxWidth: 620, maxHeight: 340)
                    Text(item.title).font(.title2.weight(.semibold))
                    Text(item.duration > 0 ? "\(Int(item.duration.rounded())) seconds • local video" : "Local video")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("Set Live Wallpaper") { playback.play(item: item, policy: library.policy) }
                            .buttonStyle(.borderedProminent)
                        Button("Remove", role: .destructive) { library.removeSelected() }
                    }
                } else {
                    ContentUnavailableView("Your live wallpaper library is empty", systemImage: "sparkles.tv", description: Text("Import an MP4 or MOV file to begin."))
                }
                Divider()
                HStack {
                    Picker("Playback", selection: $library.policy) {
                        ForEach(PlaybackPolicy.allCases) { Text($0.label).tag($0) }
                    }
                    Spacer()
                    Text(playback.statusText).foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .toolbar {
                ToolbarItemGroup {
                    Button(action: library.importVideo) { Label("Import", systemImage: "plus") }
                    Button(action: playback.stop) { Label("Stop", systemImage: "stop.fill") }.disabled(!playback.isPlaying)
                }
            }
        }
    }
}

private struct VideoPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = AVPlayer(url: url)
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspectFill
        view.player?.play()
        return view
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}
