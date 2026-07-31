import AppKit
import SwiftUI

struct StudyInspectorView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var agent: AgentService

    @State private var analysis = AnalysisResult.empty
    @State private var personalNote = ""
    @State private var errorMessage: String?
    @State private var glossarySearch = ""
    @State private var citationDraft = CitationDraft()
    @State private var citationDraftPaperID: UUID?
    @State private var citationExtraction: CitationExtractionResult?
    @State private var citationError: String?
    @State private var citationSaveMessage: String?
    @State private var isExtractingCitation = false
    @State private var citationTask: Task<Void, Never>?
    @State private var didSaveCurrentResult = false

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
            Divider().overlay(ReadingTheme.divider)

            if let paper = library.selectedPaper {
                Group {
                    switch library.inspectorTab {
                    case .study:
                        studyView(paper: paper)
                    case .notes:
                        notesView(paper: paper)
                    case .glossary:
                        glossaryView
                    case .citation:
                        citationView(paper: paper)
                    }
                }
            } else {
                EmptyStateView(
                    systemImage: "sidebar.right",
                    title: "精读工作台",
                    message: "选中论文后，这里会显示翻译、笔记、词库与引用信息。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(ReadingTheme.inspector)
        .onChange(of: library.selectedSourceText) { _ in
            analysis = .empty
            personalNote = ""
            errorMessage = nil
            didSaveCurrentResult = false
        }
        .onAppear {
            syncToSelectedPaper()
        }
        .onChange(of: library.selectedPaperID) { _ in
            syncToSelectedPaper()
        }
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("研读工作台")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(ReadingTheme.ink)
                    Text(
                        agent.isRunning
                            ? agent.statusMessage
                            : (agent.isConfigured
                                ? "外部 Agent · 就绪"
                                : "请在设置中配置 Agent 工具")
                    )
                        .font(.system(size: 10.5))
                        .foregroundStyle(
                            agent.isRunning || agent.isConfigured
                                ? ReadingTheme.accent
                                : ReadingTheme.danger
                        )
                }
                Spacer()
                Circle()
                    .fill(
                        agent.isRunning || agent.isConfigured
                            ? ReadingTheme.accent
                            : ReadingTheme.danger.opacity(0.75)
                    )
                    .frame(width: 7, height: 7)
            }

            Picker("工作区", selection: $library.inspectorTab) {
                ForEach(InspectorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 11)
        .background(ReadingTheme.paper)
    }

    private func studyView(paper: Paper) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sourceSection

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(ReadingTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .readingCard(padding: 12)
                }

                if analysis != .empty {
                    analysisSection
                    personalNoteSection(paper: paper)
                } else if !agent.isRunning {
                    guidanceSection
                }
            }
            .padding(14)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("所选原文", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReadingTheme.ink)
                Spacer()
                if !library.selectedLocation.isEmpty {
                    Text(library.selectedLocation)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ReadingTheme.mutedInk)
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $library.selectedSourceText)
                    .font(ReadingTheme.serif)
                    .lineSpacing(4)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 132, maxHeight: 240)
                    .padding(6)
                    .background(ReadingTheme.appBackground.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                if library.selectedSourceText.isEmpty {
                    Text("在左侧原文中划选词语、句子或段落，也可以在这里粘贴。")
                        .font(.system(size: 13))
                        .foregroundStyle(ReadingTheme.mutedInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Text(selectionLengthText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(
                        library.selectedSourceText.count > 12_000
                            ? ReadingTheme.danger
                            : ReadingTheme.mutedInk
                    )
                Spacer()
                Button {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        library.selectedSourceText = text
                    }
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11))
            }

            if agent.isRunning {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(agent.statusMessage)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ReadingTheme.secondaryInk)
                    Spacer()
                    Button("取消") {
                        agent.cancel()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(ReadingTheme.danger)
                }
                .frame(height: 30)
            } else {
                Button {
                    runAnalysis()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("翻译并提炼")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("Agent")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .opacity(0.78)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 13)
                    .frame(height: 38)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    library.selectedSourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? ReadingTheme.mutedInk.opacity(0.55)
                        : ReadingTheme.accent
                )
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .disabled(library.selectedSourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .readingCard()
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            resultBlock(title: "中文翻译", systemImage: "character.book.closed", text: analysis.translation)

            Divider().overlay(ReadingTheme.divider)

            resultBlock(title: "语境与句法", systemImage: "scope", text: analysis.explanation)

            Divider().overlay(ReadingTheme.divider)

            VStack(alignment: .leading, spacing: 7) {
                Label("核心观点", systemImage: "target")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReadingTheme.accent)
                Text(analysis.corePoint)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ReadingTheme.ink)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }

            if !analysis.keywords.isEmpty {
                Divider().overlay(ReadingTheme.divider)
                VStack(alignment: .leading, spacing: 9) {
                    Label("建议加入专业词库", systemImage: "textformat.abc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ReadingTheme.ink)

                    FlowLayout(spacing: 6) {
                        ForEach(analysis.keywords) { keyword in
                            HStack(spacing: 5) {
                                Text(keyword.term)
                                    .fontWeight(.medium)
                                Text(keyword.translation)
                                    .foregroundStyle(ReadingTheme.secondaryInk)
                            }
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(ReadingTheme.accentSoft)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .readingCard()
    }

    private func resultBlock(title: String, systemImage: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReadingTheme.ink)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(ReadingTheme.mutedInk)
                .help("复制")
            }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(ReadingTheme.ink)
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    private func personalNoteSection(paper: Paper) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("我的思考", systemImage: "pencil.line")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReadingTheme.ink)

            TextEditor(text: $personalNote)
                .font(.system(size: 13.5))
                .lineSpacing(4)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(6)
                .background(ReadingTheme.note.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if personalNote.isEmpty {
                        Text("补充你的疑问、联想、研究启发或批判性判断…")
                            .font(.system(size: 12.5))
                            .foregroundStyle(ReadingTheme.mutedInk)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                library.addNote(
                    paperID: paper.id,
                    sourceText: library.selectedSourceText,
                    result: analysis,
                    personalNote: personalNote,
                    location: library.selectedLocation
                )
                didSaveCurrentResult = true
            } label: {
                Label(didSaveCurrentResult ? "已存入精读笔记" : "存为精读笔记", systemImage: didSaveCurrentResult ? "checkmark" : "note.text.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(didSaveCurrentResult ? ReadingTheme.mutedInk : ReadingTheme.accent)
            .disabled(didSaveCurrentResult)
        }
        .readingCard()
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("推荐精读方式", systemImage: "lightbulb.min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ReadingTheme.ink)
            guidanceRow("1", "短语或术语", "查看专业语境中的准确含义")
            guidanceRow("2", "完整长句", "拆解从句、指代与逻辑关系")
            guidanceRow("3", "一个段落", "翻译并提炼可复用的核心观点")
        }
        .readingCard()
    }

    private func guidanceRow(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(ReadingTheme.accent)
                .frame(width: 20, height: 20)
                .background(ReadingTheme.accentSoft)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ReadingTheme.ink)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(ReadingTheme.mutedInk)
            }
        }
    }

    private func notesView(paper: Paper) -> some View {
        let paperNotes = library.notes(for: paper.id)
        return Group {
            if paperNotes.isEmpty {
                EmptyStateView(
                    systemImage: "note.text",
                    title: "还没有精读笔记",
                    message: "划选原文并完成翻译后，可把结果、关键词与个人思考一起存入这里。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(paperNotes.count) 条笔记")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ReadingTheme.mutedInk)
                        Spacer()
                        Button {
                            if let url = try? library.exportNotes(for: paper.id) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        } label: {
                            Label("导出 Markdown", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ReadingTheme.accent)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(paperNotes) { note in
                                NoteCard(note: note) {
                                    library.deleteNote(note.id)
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private var glossaryView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ReadingTheme.mutedInk)
                TextField("搜索专业词库", text: $glossarySearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                Text("\(filteredGlossary.count)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(ReadingTheme.mutedInk)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(ReadingTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .padding(14)

            if filteredGlossary.isEmpty {
                EmptyStateView(
                    systemImage: "character.book.closed",
                    title: "专业词库尚为空",
                    message: "每次保存精读笔记时，Agent 提取的关键词会累计词频和来源论文。"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredGlossary) { item in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.term)
                                        .font(.system(size: 13.5, weight: .semibold))
                                        .foregroundStyle(ReadingTheme.ink)
                                    Text(item.translation)
                                        .font(.system(size: 12))
                                        .foregroundStyle(ReadingTheme.secondaryInk)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(item.frequency)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(ReadingTheme.accent)
                                    Text("\(item.paperIDs.count) 篇")
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(ReadingTheme.mutedInk)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(ReadingTheme.paper.opacity(0.62))
                            Divider().overlay(ReadingTheme.divider)
                        }
                    }
                }
            }
        }
    }

    private func citationView(paper: Paper) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("引用信息卡", systemImage: "quote.opening")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ReadingTheme.ink)
                    Text("把论文的引用元数据与精读笔记分开保存，便于后续写作引用。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ReadingTheme.mutedInk)
                        .lineSpacing(3)
                }

                citationExtractionCard(paper: paper)

                VStack(spacing: 12) {
                    citationField("论文标题", text: $citationDraft.title, prompt: "论文正式标题")
                    citationField("作者", text: $citationDraft.authors, prompt: "如：Rao, P.; Li, R.")
                    HStack(spacing: 10) {
                        citationField("年份", text: $citationDraft.year, prompt: "2026")
                            .frame(width: 92)
                        citationField("期刊 / 会议", text: $citationDraft.venue, prompt: "期刊或会议名称")
                    }
                    citationField("DOI", text: $citationDraft.doi, prompt: "10.xxxx/xxxxx")
                    citationField("标签", text: $citationDraft.tags, prompt: "用逗号分隔")
                }
                .readingCard()

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("引用文本")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button {
                            guard citationDraftPaperID == paper.id else {
                                loadCitation(paper)
                                return
                            }
                            citationDraft.citationText = generatedCitation(for: paper)
                            citationSaveMessage = nil
                        } label: {
                            Label("自动排版", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                        .foregroundStyle(ReadingTheme.accent)
                    }
                    TextEditor(text: $citationDraft.citationText)
                        .font(.system(size: 12.5, design: .serif))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                        .padding(6)
                        .background(ReadingTheme.appBackground.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .readingCard()

                HStack {
                    Button {
                        saveCitation()
                    } label: {
                        Label("保存引用信息", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ReadingTheme.accent)

                    Button {
                        guard citationDraftPaperID == paper.id else {
                            loadCitation(paper)
                            return
                        }
                        let value = citationDraft.citationText.isEmpty
                            ? generatedCitation(for: paper)
                            : citationDraft.citationText
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("复制引用")
                }

                if let citationSaveMessage {
                    Label(citationSaveMessage, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ReadingTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
        .onChange(of: citationDraft) { _ in
            citationSaveMessage = nil
        }
    }

    private func citationExtractionCard(paper: Paper) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("智能获取", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ReadingTheme.accent)
                Spacer()
                Text("首页 / 前三页")
                    .font(.system(size: 10))
                    .foregroundStyle(ReadingTheme.mutedInk)
            }

            Text("读取论文标题页，并通过你配置的外部 Agent 识别作者、年份、出版来源、DOI、关键词和 APA 引用。")
                .font(.system(size: 11.5))
                .foregroundStyle(ReadingTheme.secondaryInk)
                .lineSpacing(3)

            Label(
                "点击后，首页文本会交给你配置的外部 Agent；其数据去向取决于该工具。",
                systemImage: "lock.shield"
            )
            .font(.system(size: 10.5))
            .foregroundStyle(ReadingTheme.mutedInk)

            if isExtractingCitation {
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text(agent.statusMessage)
                        .font(.system(size: 11.5))
                        .foregroundStyle(ReadingTheme.secondaryInk)
                    Spacer()
                    Button("取消") {
                        citationTask?.cancel()
                        agent.cancel()
                        isExtractingCitation = false
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(ReadingTheme.danger)
                }
                .frame(height: 30)
            } else {
                Button {
                    runCitationExtraction(paper)
                } label: {
                    Label("智能获取并填充", systemImage: "text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(ReadingTheme.accent)
                .disabled(agent.isRunning)
            }

            if let citationError {
                Label(citationError, systemImage: "exclamationmark.circle")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ReadingTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let citationExtraction {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ReadingTheme.accent)
                        Text("已填入草稿")
                            .font(.system(size: 11.5, weight: .semibold))
                        Spacer()
                        Text("置信度 \(Int(max(0, min(1, citationExtraction.confidence)) * 100))%")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(confidenceColor(citationExtraction.confidence))
                    }
                    if !citationExtraction.rationale.isEmpty {
                        Text(citationExtraction.rationale)
                            .font(.system(size: 11))
                            .foregroundStyle(ReadingTheme.secondaryInk)
                            .lineSpacing(3)
                    }
                    Text("保存前请核对识别结果，尤其是年份、期刊和 DOI。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(ReadingTheme.mutedInk)
                }
                .padding(9)
                .background(ReadingTheme.accentSoft.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
        }
        .readingCard()
    }

    private func citationField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ReadingTheme.mutedInk)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5))
        }
    }

    private var selectionLengthText: String {
        let count = library.selectedSourceText.count
        if count > 12_000 {
            return "\(count) 字符 · 本次分析将截取前 12,000 字符"
        }
        return "\(count) 字符"
    }

    private var filteredGlossary: [GlossaryTerm] {
        guard !glossarySearch.isEmpty else { return library.glossary }
        return library.glossary.filter {
            $0.term.localizedCaseInsensitiveContains(glossarySearch)
                || $0.translation.localizedCaseInsensitiveContains(glossarySearch)
        }
    }

    private func runAnalysis() {
        guard let paper = library.selectedPaper else { return }
        let source = String(library.selectedSourceText.prefix(12_000))
        errorMessage = nil
        Task {
            do {
                analysis = try await agent.analyze(source: source, paper: paper)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func resetStudy() {
        analysis = .empty
        personalNote = ""
        errorMessage = nil
        didSaveCurrentResult = false
    }

    private func syncToSelectedPaper() {
        resetStudy()
        if let paper = library.selectedPaper {
            loadCitation(paper)
        } else {
            clearCitation()
        }
    }

    private func clearCitation() {
        if isExtractingCitation {
            citationTask?.cancel()
            agent.cancel()
        }
        citationDraft = CitationDraft()
        citationDraftPaperID = nil
        citationExtraction = nil
        citationError = nil
        citationSaveMessage = nil
        isExtractingCitation = false
        citationTask = nil
    }

    private func loadCitation(_ paper: Paper) {
        if isExtractingCitation {
            citationTask?.cancel()
            agent.cancel()
        }
        citationDraft = CitationDraft(
            title: paper.title,
            authors: paper.authors,
            year: paper.year,
            venue: paper.venue,
            doi: paper.doi,
            citationText: paper.citationText,
            tags: paper.tags.joined(separator: ", ")
        )
        citationDraftPaperID = paper.id
        citationExtraction = nil
        citationError = nil
        citationSaveMessage = nil
        isExtractingCitation = false
        citationTask = nil
    }

    private func saveCitation() {
        guard let paper = library.selectedPaper else {
            citationError = "当前没有选中的论文。"
            citationSaveMessage = nil
            return
        }
        guard citationDraftPaperID == paper.id else {
            loadCitation(paper)
            citationError = "引用草稿与当前论文不一致，已重新载入当前论文的信息，请确认后再保存。"
            return
        }

        var updated = paper
        let title = citationDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            updated.title = title
        }
        updated.authors = citationDraft.authors.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.year = citationDraft.year.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.venue = citationDraft.venue.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.doi = citationDraft.doi.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.citationText = citationDraft.citationText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = citationDraft.tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if library.updatePaper(updated, persistImmediately: true) {
            citationDraftPaperID = updated.id
            citationError = nil
            citationSaveMessage = "已保存到当前论文「\(updated.title)」"
        } else {
            citationSaveMessage = nil
            citationError = "引用信息保存失败，请检查资料库文件的写入权限。"
        }
    }

    private func generatedCitation(for paper: Paper) -> String {
        let authors = citationDraft.authors.isEmpty ? "作者待补充" : citationDraft.authors
        let year = citationDraft.year.isEmpty ? "年份待补充" : citationDraft.year
        let title = citationDraft.title.isEmpty ? paper.title : citationDraft.title
        let venue = citationDraft.venue.isEmpty ? "" : " \(citationDraft.venue)."
        let doi = citationDraft.doi.isEmpty ? "" : " https://doi.org/\(citationDraft.doi)"
        return "\(authors) (\(year)). \(title).\(venue)\(doi)"
    }

    private func runCitationExtraction(_ paper: Paper) {
        let paperID = paper.id
        if citationDraftPaperID != paperID {
            loadCitation(paper)
        }
        citationError = nil
        citationSaveMessage = nil
        citationExtraction = nil
        isExtractingCitation = true

        citationTask?.cancel()
        citationTask = Task {
            do {
                let source = await DocumentTextExtractor.firstPagesText(
                    for: paper,
                    characterLimit: 18_000
                )
                try Task.checkCancellation()
                guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AgentError.documentTextUnavailable
                }

                var result = try await agent.extractCitation(source: source, paper: paper)
                try Task.checkCancellation()
                if result.doi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    result.doi = DocumentTextExtractor.detectedDOI(in: source)
                }

                guard library.selectedPaperID == paperID,
                      citationDraftPaperID == paperID
                else {
                    isExtractingCitation = false
                    return
                }
                applyCitationExtraction(result, to: paper)
                citationExtraction = result
            } catch {
                if library.selectedPaperID == paperID, !Task.isCancelled {
                    citationError = agent.statusMessage == "正在取消…"
                        ? "已取消引用信息识别"
                        : error.localizedDescription
                }
            }
            if library.selectedPaperID == paperID,
               citationDraftPaperID == paperID
            {
                isExtractingCitation = false
                citationTask = nil
            }
        }
    }

    private func applyCitationExtraction(_ result: CitationExtractionResult, to paper: Paper) {
        func clean(_ value: String) -> String {
            value.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !clean(result.title).isEmpty {
            citationDraft.title = clean(result.title)
        }
        if !clean(result.authors).isEmpty {
            citationDraft.authors = clean(result.authors)
        }
        if !clean(result.year).isEmpty {
            citationDraft.year = clean(result.year)
        }
        if !clean(result.venue).isEmpty {
            citationDraft.venue = clean(result.venue)
        }
        if !clean(result.doi).isEmpty {
            citationDraft.doi = normalizedDOI(result.doi)
        }
        if !result.tags.isEmpty {
            citationDraft.tags = result.tags
                .map(clean)
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        if !clean(result.citationText).isEmpty {
            citationDraft.citationText = clean(result.citationText)
        } else {
            citationDraft.citationText = generatedCitation(for: paper)
        }
    }

    private func normalizedDOI(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://doi.org/", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "http://doi.org/", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,; "))
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return ReadingTheme.accent }
        if confidence >= 0.55 { return Color.orange.opacity(0.8) }
        return ReadingTheme.danger
    }
}

private struct CitationDraft: Equatable {
    var title = ""
    var authors = ""
    var year = ""
    var venue = ""
    var doi = ""
    var citationText = ""
    var tags = ""
}

private struct NoteCard: View {
    let note: StudyNote
    let onDelete: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(note.location.isEmpty ? "精读片段" : note.location, systemImage: "bookmark")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ReadingTheme.accent)
                Spacer()
                Text(note.createdAt, style: .date)
                    .font(.system(size: 9.5))
                    .foregroundStyle(ReadingTheme.mutedInk)
                Menu {
                    Button(role: .destructive, action: onDelete) {
                        Label("删除笔记", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Text(note.sourceText)
                .font(.system(size: 12.5, design: .serif))
                .foregroundStyle(ReadingTheme.secondaryInk)
                .lineLimit(isExpanded ? nil : 3)
                .lineSpacing(3)

            Divider().overlay(ReadingTheme.divider)

            Text(note.translation)
                .font(.system(size: 13))
                .foregroundStyle(ReadingTheme.ink)
                .lineLimit(isExpanded ? nil : 4)
                .lineSpacing(3)

            if !note.corePoint.isEmpty {
                Text(note.corePoint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ReadingTheme.accent)
                    .padding(.leading, 9)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(ReadingTheme.accent)
                            .frame(width: 2)
                    }
                    .lineLimit(isExpanded ? nil : 2)
            }

            if !note.personalNote.isEmpty {
                Text(note.personalNote)
                    .font(.system(size: 12))
                    .foregroundStyle(ReadingTheme.secondaryInk)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ReadingTheme.note.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .lineLimit(isExpanded ? nil : 3)
            }

            Button(isExpanded ? "收起" : "展开全部") {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10.5))
            .foregroundStyle(ReadingTheme.mutedInk)
        }
        .readingCard(padding: 13)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(
            proposal: ProposedViewSize(width: bounds.width, height: proposal.height),
            subviews: subviews
        )
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
