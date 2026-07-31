import PDFKit
import SwiftUI

struct PDFReaderView: NSViewRepresentable {
    let url: URL
    @Binding var selectedText: String
    @Binding var selectedLocation: String

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = true
        pdfView.pageShadowsEnabled = false
        pdfView.backgroundColor = NSColor(
            calibratedRed: 0.90,
            green: 0.895,
            blue: 0.875,
            alpha: 1
        )

        context.coordinator.installObservers(for: pdfView)
        load(url: url, into: pdfView, coordinator: context.coordinator)
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedURL != url {
            load(url: url, into: pdfView, coordinator: context.coordinator)
        }
    }

    private func load(url: URL, into pdfView: PDFView, coordinator: Coordinator) {
        coordinator.loadedURL = url
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        if let firstPage = pdfView.document?.page(at: 0) {
            pdfView.go(to: firstPage)
        }
    }

    final class Coordinator {
        var parent: PDFReaderView
        var loadedURL: URL?
        private var observers: [NSObjectProtocol] = []

        init(parent: PDFReaderView) {
            self.parent = parent
        }

        func installObservers(for pdfView: PDFView) {
            let selectionObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewSelectionChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard let self, let pdfView else { return }
                let selection = pdfView.currentSelection
                let text = selection?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let location: String
                if
                    let page = selection?.pages.first,
                    let document = pdfView.document
                {
                    location = "第 \(document.index(for: page) + 1) 页"
                } else {
                    location = ""
                }
                self.parent.selectedText = text
                self.parent.selectedLocation = location
            }

            let pageObserver = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self, weak pdfView] _ in
                guard
                    let self,
                    let pdfView,
                    self.parent.selectedText.isEmpty,
                    let page = pdfView.currentPage,
                    let document = pdfView.document
                else { return }
                self.parent.selectedLocation = "第 \(document.index(for: page) + 1) 页"
            }

            observers = [selectionObserver, pageObserver]
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
