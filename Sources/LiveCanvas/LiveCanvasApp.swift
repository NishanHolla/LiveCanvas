import SwiftUI

@main
struct LiveCanvasApp: App {
    @StateObject private var library = WallpaperLibrary()
    @StateObject private var playback = WallpaperPlaybackController()

    var body: some Scene {
        WindowGroup("LiveCanvas") {
            LibraryView()
                .environmentObject(library)
                .environmentObject(playback)
                .frame(minWidth: 760, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Video…") { library.importVideo() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandMenu("Wallpaper") {
                Button("Play Current Wallpaper") {
                    guard let item = library.selectedItem else { return }
                    playback.play(item: item, policy: library.policy)
                }
                .keyboardShortcut("p", modifiers: [.command])
                Button("Stop Wallpaper") { playback.stop() }
                    .keyboardShortcut(".", modifiers: [.command])
            }
        }

        MenuBarExtra("LiveCanvas", systemImage: playback.isPlaying ? "rectangle.inset.filled.and.person.filled" : "rectangle.inset.filled") {
            Text(playback.statusText)
            Divider()
            Button("Shuffle") { library.playRandom(using: playback) }
                .disabled(library.items.isEmpty)
            Button("Stop") { playback.stop() }
                .disabled(!playback.isPlaying)
            Divider()
            Button("Show LiveCanvas") { NSApp.activate(ignoringOtherApps: true) }
            Button("Quit LiveCanvas") { NSApp.terminate(nil) }
        }
    }
}
