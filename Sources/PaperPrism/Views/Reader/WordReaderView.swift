import AppKit
import SwiftUI

struct WordReaderView: NSViewRepresentable {
    let url: URL
    @Binding var selectedText: String
    @Binding var selectedLocation: String
    @Binding var zoomScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = false
        scrollView.backgroundColor = NSColor(
            calibratedRed: 0.90,
            green: 0.895,
            blue: 0.875,
            alpha: 1
        )

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.usesFindBar = true
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.backgroundColor = NSColor(
            calibratedRed: 0.995,
            green: 0.992,
            blue: 0.980,
            alpha: 1
        )
        textView.textColor = NSColor(
            calibratedRed: 0.105,
            green: 0.12,
            blue: 0.125,
            alpha: 1
        )
        textView.textContainerInset = NSSize(width: 72, height: 56)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        let initialViewportWidth = max(1, scrollView.contentSize.width)
        let initialTextWidth = max(
            1,
            initialViewportWidth - textView.textContainerInset.width * 2
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: initialTextWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: initialViewportWidth,
            height: max(1, scrollView.contentSize.height)
        )

        scrollView.documentView = textView
        context.coordinator.installObserver(for: textView)
        context.coordinator.installMagnificationRecognizer(on: scrollView)
        load(url: url, into: textView, coordinator: context.coordinator)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        if
            context.coordinator.loadedURL != url,
            let textView = scrollView.documentView as? NSTextView
        {
            load(url: url, into: textView, coordinator: context.coordinator)
        }

        if let textView = scrollView.documentView as? NSTextView {
            let viewportWidth = max(1, scrollView.contentSize.width)
            if abs(textView.frame.width - viewportWidth) > 0.5 {
                textView.setFrameSize(
                    NSSize(
                        width: viewportWidth,
                        height: max(textView.frame.height, scrollView.contentSize.height)
                    )
                )
            }
            if let textContainer = textView.textContainer {
                let textWidth = max(
                    1,
                    viewportWidth - textView.textContainerInset.width * 2
                )
                if abs(textContainer.containerSize.width - textWidth) > 0.5 {
                    textContainer.containerSize = NSSize(
                        width: textWidth,
                        height: CGFloat.greatestFiniteMagnitude
                    )
                }
            }
            context.coordinator.applyZoom(to: textView, scale: zoomScale)
        }
    }

    private func load(url: URL, into textView: NSTextView, coordinator: Coordinator) {
        coordinator.loadedURL = url
        do {
            let attributed = try NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            )
            let normalized = NSMutableAttributedString(attributedString: attributed)
            normalized.addAttributes(
                [.foregroundColor: NSColor.textColor],
                range: NSRange(location: 0, length: attributed.length)
            )
            coordinator.baseAttributedString = normalized
        } catch {
            let message = """
            无法在阅读视图中解析此 Word 文件。

            你仍可使用工具栏中的“在默认应用中打开”，或将文件另存为 .docx 后重新导入。

            错误信息：\(error.localizedDescription)
            """
            coordinator.baseAttributedString = NSAttributedString(
                string: message,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 15),
                    .foregroundColor: NSColor.textColor
                ]
            )
        }
        coordinator.applyZoom(to: textView, scale: zoomScale, force: true)
        textView.scrollToBeginningOfDocument(nil)
    }

    final class Coordinator: NSObject {
        var parent: WordReaderView
        var loadedURL: URL?
        var baseAttributedString: NSAttributedString?
        private var observer: NSObjectProtocol?
        private var currentZoomScale: CGFloat = 0
        private var magnificationStartScale: CGFloat = 1

        init(parent: WordReaderView) {
            self.parent = parent
            super.init()
        }

        func installObserver(for textView: NSTextView) {
            observer = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: textView,
                queue: .main
            ) { [weak self, weak textView] _ in
                guard let self, let textView else { return }
                let range = textView.selectedRange()
                guard range.location != NSNotFound, range.length > 0 else {
                    self.parent.selectedText = ""
                    return
                }
                let text = (textView.string as NSString)
                    .substring(with: range)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let prefix = (textView.string as NSString)
                    .substring(to: min(range.location, textView.string.utf16.count))
                let paragraph = max(1, prefix.components(separatedBy: "\n\n").count)
                self.parent.selectedText = text
                self.parent.selectedLocation = "第 \(paragraph) 段附近"
            }
        }

        func installMagnificationRecognizer(on scrollView: NSScrollView) {
            let recognizer = NSMagnificationGestureRecognizer(
                target: self,
                action: #selector(handleMagnification(_:))
            )
            scrollView.addGestureRecognizer(recognizer)
        }

        @objc
        private func handleMagnification(_ recognizer: NSMagnificationGestureRecognizer) {
            switch recognizer.state {
            case .began:
                magnificationStartScale = parent.zoomScale
            case .changed:
                parent.zoomScale = min(
                    2.5,
                    max(0.65, magnificationStartScale * (1 + recognizer.magnification))
                )
            default:
                break
            }
        }

        func applyZoom(to textView: NSTextView, scale: CGFloat, force: Bool = false) {
            guard let baseAttributedString else { return }
            let targetScale = min(2.5, max(0.65, scale))
            guard force || abs(currentZoomScale - targetScale) > 0.005 else { return }

            let selection = textView.selectedRange()
            var visibleCharacterRange: NSRange?
            if let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer
            {
                let glyphRange = layoutManager.glyphRange(
                    forBoundingRect: textView.visibleRect,
                    in: textContainer
                )
                visibleCharacterRange = layoutManager.characterRange(
                    forGlyphRange: glyphRange,
                    actualGlyphRange: nil
                )
            }

            let scaled = NSMutableAttributedString(attributedString: baseAttributedString)
            let fullRange = NSRange(location: 0, length: scaled.length)
            var fontUpdates: [(NSRange, NSFont)] = []
            var paragraphUpdates: [(NSRange, NSParagraphStyle)] = []

            baseAttributedString.enumerateAttribute(
                .font,
                in: fullRange
            ) { value, range, _ in
                let font = value as? NSFont ?? NSFont.systemFont(ofSize: 15)
                let scaledFont = NSFontManager.shared.convert(
                    font,
                    toSize: max(7, font.pointSize * targetScale)
                )
                fontUpdates.append((range, scaledFont))
            }

            baseAttributedString.enumerateAttribute(
                .paragraphStyle,
                in: fullRange
            ) { value, range, _ in
                guard let style = value as? NSParagraphStyle,
                      let mutable = style.mutableCopy() as? NSMutableParagraphStyle
                else {
                    return
                }
                mutable.lineSpacing *= targetScale
                mutable.paragraphSpacing *= targetScale
                mutable.paragraphSpacingBefore *= targetScale
                if mutable.minimumLineHeight > 0 {
                    mutable.minimumLineHeight *= targetScale
                }
                if mutable.maximumLineHeight > 0 {
                    mutable.maximumLineHeight *= targetScale
                }
                paragraphUpdates.append((range, mutable))
            }

            for (range, font) in fontUpdates {
                scaled.addAttribute(.font, value: font, range: range)
            }
            for (range, style) in paragraphUpdates {
                scaled.addAttribute(.paragraphStyle, value: style, range: range)
            }

            textView.textStorage?.setAttributedString(scaled)
            if selection.location != NSNotFound,
               selection.location + selection.length <= scaled.length
            {
                textView.setSelectedRange(selection)
            }
            currentZoomScale = targetScale

            if let visibleCharacterRange, visibleCharacterRange.location < scaled.length {
                textView.scrollRangeToVisible(
                    NSRange(location: visibleCharacterRange.location, length: 0)
                )
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
