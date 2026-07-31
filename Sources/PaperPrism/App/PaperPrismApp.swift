import SwiftUI

@main
struct PaperPrismApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var agent = AgentService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(agent)
                .frame(minWidth: 1_180, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1_440, height: 900)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("导入论文…") {
                    NotificationCenter.default.post(name: .requestPaperImport, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .appInfo) {
                Link(
                    "源代码与 AGPL 许可",
                    destination: URL(string: "https://github.com/moistrain/PaperPrism")!
                )
            }
        }

        Settings {
            SettingsView()
                .environmentObject(agent)
                .frame(width: 620, height: 520)
        }
    }
}

extension Notification.Name {
    static let requestPaperImport = Notification.Name("PaperPrism.requestPaperImport")
}
