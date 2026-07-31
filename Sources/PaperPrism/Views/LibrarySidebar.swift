import AppKit
import SwiftUI

struct LibrarySidebar: View {
    @EnvironmentObject private var library: LibraryStore
    let onImport: () -> Void
    @State private var isCreatingCategory = false
    @State private var newCategory = ""
    @State private var paperPendingDeletion: Paper?

    var body: some View {
        VStack(spacing: 0) {
            header
            filterSection
            Divider().overlay(ReadingTheme.divider)
            paperList
        }
        .background(ReadingTheme.sidebarBackground)
        .alert("新建论文分类", isPresented: $isCreatingCategory) {
            TextField("分类名称", text: $newCategory)
            Button("取消", role: .cancel) {
                newCategory = ""
            }
            Button("创建") {
                let category = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                library.addCategory(category)
                library.selectedCategory = category.isEmpty ? nil : category
                library.selectedFilter = .all
                newCategory = ""
            }
            .disabled(newCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("例如：人机信任、研究方法、Agent 监管")
        }
        .alert(
            "移除论文记录？",
            isPresented: Binding(
                get: { paperPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        paperPendingDeletion = nil
                    }
                }
            ),
            presenting: paperPendingDeletion
        ) { paper in
            Button("取消", role: .cancel) {
                paperPendingDeletion = nil
            }
            Button("移除记录", role: .destructive) {
                library.deletePaperRecord(paper.id)
                paperPendingDeletion = nil
            }
        } message: { paper in
            Text(
                "将从 PaperPrism 中移除“\(paper.title)”及其精读笔记，"
                    + "但不会删除磁盘上的原始文件。"
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAPERPRISM")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(ReadingTheme.accent)
                    Text("科研精读库")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(ReadingTheme.ink)
                }
                Spacer()
                Button(action: onImport) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .background(ReadingTheme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .help("导入 PDF 或 Word（⌘O）")
            }

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ReadingTheme.mutedInk)
                TextField("搜索论文、作者或标签", text: $library.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(ReadingTheme.paper.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(ReadingTheme.divider, lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 2) {
                ForEach(LibraryFilter.allCases) { filter in
                    sidebarRow(
                        title: filter.title,
                        systemImage: filter.systemImage,
                        count: count(for: filter),
                        isSelected: library.selectedFilter == filter && library.selectedCategory == nil
                    ) {
                        library.selectedFilter = filter
                        library.selectedCategory = nil
                    }
                }
            }

            HStack {
                Text("分类")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ReadingTheme.mutedInk)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Menu {
                    ForEach(library.categories, id: \.self) { category in
                        Button(category) {
                            library.selectedCategory = category
                            library.selectedFilter = .all
                        }
                    }
                    Divider()
                    Button {
                        isCreatingCategory = true
                    } label: {
                        Label("新建分类…", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 8)

            VStack(spacing: 2) {
                ForEach(library.categories, id: \.self) { category in
                    sidebarRow(
                        title: category,
                        systemImage: "folder",
                        count: library.papers.filter { $0.category == category }.count,
                        isSelected: library.selectedCategory == category
                    ) {
                        library.selectedCategory = category
                        library.selectedFilter = .all
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private var paperList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(library.selectedCategory ?? library.selectedFilter.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReadingTheme.secondaryInk)
                Spacer()
                Text("\(library.filteredPapers.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ReadingTheme.mutedInk)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if library.filteredPapers.isEmpty {
                Spacer()
                EmptyStateView(
                    systemImage: "doc.badge.plus",
                    title: library.papers.isEmpty ? "还没有论文" : "没有匹配结果",
                    message: library.papers.isEmpty
                        ? "导入本地 PDF 或 Word，开始建立你的科研精读库。"
                        : "尝试切换分类或清除搜索条件。",
                    actionTitle: library.papers.isEmpty ? "导入论文" : nil,
                    action: library.papers.isEmpty ? onImport : nil
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(library.filteredPapers) { paper in
                            PaperRow(
                                paper: paper,
                                noteCount: library.notes(for: paper.id).count,
                                isSelected: library.selectedPaperID == paper.id,
                                onDelete: {
                                    paperPendingDeletion = paper
                                }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                library.selectPaper(paper.id)
                            }
                            .contextMenu {
                                Button(paper.isFavorite ? "取消重点关注" : "设为重点关注") {
                                    library.toggleFavorite(paper.id)
                                }
                                Button("在 Finder 中显示") {
                                    NSWorkspace.shared.activateFileViewerSelecting([paper.fileURL])
                                }
                                Divider()
                                Button("移除论文记录", role: .destructive) {
                                    paperPendingDeletion = paper
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
                }
            }
        }
    }

    private func sidebarRow(
        title: String,
        systemImage: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13))
                    .frame(width: 17)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isSelected ? ReadingTheme.accent : ReadingTheme.mutedInk)
            }
            .font(.system(size: 13))
            .foregroundStyle(isSelected ? ReadingTheme.accent : ReadingTheme.secondaryInk)
            .padding(.horizontal, 9)
            .frame(height: 31)
            .background(isSelected ? ReadingTheme.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func count(for filter: LibraryFilter) -> Int {
        switch filter {
        case .all: return library.papers.count
        case .reading: return library.papers.filter { $0.status == .reading }.count
        case .finished: return library.papers.filter { $0.status == .finished }.count
        case .favorite: return library.papers.filter(\.isFavorite).count
        }
    }
}

private struct PaperRow: View {
    let paper: Paper
    let noteCount: Int
    let isSelected: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: paper.kind.systemImage)
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? ReadingTheme.accent : ReadingTheme.mutedInk)
                .frame(width: 26, height: 32)
                .background(isSelected ? ReadingTheme.accentSoft : ReadingTheme.paper.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(paper.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ReadingTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(paper.kind.displayName)
                    if noteCount > 0 {
                        Label("\(noteCount)", systemImage: "note.text")
                    }
                    if paper.isFavorite {
                        Image(systemName: "bookmark.fill")
                            .foregroundStyle(ReadingTheme.accent)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(ReadingTheme.mutedInk)
            }
            Spacer(minLength: 0)

            if isHovering || isSelected {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(ReadingTheme.danger)
                .help("移除论文记录（不删除原文件）")
            }
        }
        .padding(8)
        .background(isSelected ? ReadingTheme.paper : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(ReadingTheme.divider, lineWidth: 1)
            }
        }
        .onHover { isHovering = $0 }
    }
}
