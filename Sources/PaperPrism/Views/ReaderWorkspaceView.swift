import AppKit
import SwiftUI

struct ReaderWorkspaceView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var wordZoom: CGFloat = 1.0

    var body: some View {
        Group {
            if let paper = library.selectedPaper {
                VStack(spacing: 0) {
                    readerHeader(for: paper)
                    Divider().overlay(ReadingTheme.divider)
                    documentView(for: paper)
                    selectionFooter
                }
            } else {
                EmptyStateView(
                    systemImage: "text.book.closed",
                    title: "选择一篇论文开始精读",
                    message: "阅读原文时划选不理解的词语、句子或段落，右侧会自动进入翻译与提炼流程。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ReadingTheme.appBackground)
            }
        }
    }

    private func readerHeader(for paper: Paper) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(paper.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ReadingTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Label(paper.kind.displayName, systemImage: paper.kind.systemImage)
                    Text(paper.category)
                    if !paper.year.isEmpty {
                        Text(paper.year)
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(ReadingTheme.mutedInk)
            }

            Spacer(minLength: 16)

            if paper.kind == .word {
                wordZoomControls
            }

            Menu {
                ForEach(library.categories, id: \.self) { category in
                    Button {
                        library.setCategory(category, for: paper.id)
                    } label: {
                        if paper.category == category {
                            Label(category, systemImage: "checkmark")
                        } else {
                            Text(category)
                        }
                    }
                }
            } label: {
                Label("分类", systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                ForEach(ReadingStatus.allCases) { status in
                    Button {
                        var updated = paper
                        updated.status = status
                        library.updatePaper(updated)
                    } label: {
                        if paper.status == status {
                            Label(status.displayName, systemImage: "checkmark")
                        } else {
                            Text(status.displayName)
                        }
                    }
                }
            } label: {
                Label(paper.status.displayName, systemImage: "circle.dashed")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                library.toggleFavorite(paper.id)
            } label: {
                Image(systemName: paper.isFavorite ? "bookmark.fill" : "bookmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(paper.isFavorite ? ReadingTheme.accent : ReadingTheme.secondaryInk)
            .help(paper.isFavorite ? "取消重点关注" : "重点关注")

            Button {
                NSWorkspace.shared.open(paper.fileURL)
            } label: {
                Image(systemName: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ReadingTheme.secondaryInk)
            .help("在默认应用中打开")
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
        .background(ReadingTheme.paper)
    }

    @ViewBuilder
    private func documentView(for paper: Paper) -> some View {
        if !FileManager.default.fileExists(atPath: paper.filePath) {
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "找不到原文件",
                message: "文件可能已被移动或重命名。请在 Finder 中找到文件后重新导入。"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReadingTheme.appBackground)
        } else {
            switch paper.kind {
            case .pdf:
                PDFReaderView(
                    url: paper.fileURL,
                    selectedText: sourceBinding,
                    selectedLocation: locationBinding
                )
            case .word:
                WordReaderView(
                    url: paper.fileURL,
                    selectedText: sourceBinding,
                    selectedLocation: locationBinding,
                    zoomScale: $wordZoom
                )
            }
        }
    }

    private var wordZoomControls: some View {
        HStack(spacing: 3) {
            Button {
                adjustWordZoom(by: -0.10)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("-", modifiers: .command)
            .disabled(wordZoom <= 0.65)
            .help("缩小 Word 字体（⌘-）")

            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5], id: \.self) { scale in
                    Button {
                        wordZoom = scale
                    } label: {
                        if abs(wordZoom - scale) < 0.005 {
                            Label("\(Int(scale * 100))%", systemImage: "checkmark")
                        } else {
                            Text("\(Int(scale * 100))%")
                        }
                    }
                }
                Divider()
                Button("实际大小") {
                    wordZoom = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)
            } label: {
                Text("\(Int((wordZoom * 100).rounded()))%")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .frame(minWidth: 38)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("选择 Word 字体缩放比例")

            Button {
                adjustWordZoom(by: 0.10)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("+", modifiers: .command)
            .disabled(wordZoom >= 2.5)
            .help("放大 Word 字体（⌘+）")
        }
        .foregroundStyle(ReadingTheme.secondaryInk)
        .padding(.horizontal, 7)
        .frame(height: 28)
        .background(ReadingTheme.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(ReadingTheme.divider, lineWidth: 1)
        }
    }

    private var sourceBinding: Binding<String> {
        Binding(
            get: { library.selectedSourceText },
            set: { text in
                library.selectedSourceText = text
                if !text.isEmpty {
                    library.inspectorTab = .study
                }
            }
        )
    }

    private var locationBinding: Binding<String> {
        Binding(
            get: { library.selectedLocation },
            set: { library.selectedLocation = $0 }
        )
    }

    private var selectionFooter: some View {
        HStack(spacing: 10) {
            Image(systemName: library.selectedSourceText.isEmpty ? "cursorarrow.rays" : "text.quote")
                .foregroundStyle(library.selectedSourceText.isEmpty ? ReadingTheme.mutedInk : ReadingTheme.accent)
            if library.selectedSourceText.isEmpty {
                Text("在原文中划选内容，右侧即可翻译、解释并形成笔记")
            } else {
                Text("已选择 \(wordCount(library.selectedSourceText)) 个词")
                    .foregroundStyle(ReadingTheme.ink)
                if !library.selectedLocation.isEmpty {
                    Text("· \(library.selectedLocation)")
                }
                Spacer()
                Button("开始精读") {
                    library.inspectorTab = .study
                }
                .buttonStyle(.borderless)
                .foregroundStyle(ReadingTheme.accent)
            }
            Spacer()
        }
        .font(.system(size: 11.5))
        .foregroundStyle(ReadingTheme.mutedInk)
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(ReadingTheme.paper)
        .overlay(alignment: .top) {
            Divider().overlay(ReadingTheme.divider)
        }
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    private func adjustWordZoom(by delta: CGFloat) {
        wordZoom = min(2.5, max(0.65, wordZoom + delta))
    }
}
