import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var isImporting = false

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.pdf]
        if let docx = UTType(filenameExtension: "docx") {
            types.append(docx)
        }
        if let doc = UTType(filenameExtension: "doc") {
            types.append(doc)
        }
        return types
    }

    var body: some View {
        HSplitView {
            LibrarySidebar(onImport: { isImporting = true })
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 330)

            ReaderWorkspaceView()
                .frame(minWidth: 560)

            StudyInspectorView()
                .frame(minWidth: 320, idealWidth: 365, maxWidth: 430)
        }
        .background(ReadingTheme.appBackground)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
            library.importPapers(from: urls)
            scoped.forEach { $0.stopAccessingSecurityScopedResource() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestPaperImport)) { _ in
            isImporting = true
        }
    }
}
