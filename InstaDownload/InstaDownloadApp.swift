import SwiftUI

@main
struct InstaDownloadApp: App {
    @State private var model = DownloadViewModel()

    var body: some Scene {
        Window("InstaDownload", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
