import AppKit
import Foundation

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var papers: [Paper] = []
    @Published private(set) var notes: [StudyNote] = []
    @Published private(set) var glossary: [GlossaryTerm] = []
    @Published private(set) var categories: [String] = []

    @Published var selectedPaperID: UUID?
    @Published var selectedFilter: LibraryFilter = .all
    @Published var selectedCategory: String?
    @Published var searchText = ""
    @Published var inspectorTab: InspectorTab = .study
    @Published var selectedSourceText = ""
    @Published var selectedLocation = ""

    private let persistenceURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let environment = ProcessInfo.processInfo.environment
        let directory: URL
        if let override = environment["PAPERPRISM_DATA_DIRECTORY"], !override.isEmpty {
            directory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            directory = base.appendingPathComponent("PaperPrismCommunity", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        persistenceURL = directory.appendingPathComponent("library.json")
        load()

        if
            papers.isEmpty,
            let previewPath = environment["PAPERPRISM_PREVIEW_FILE"],
            FileManager.default.fileExists(atPath: previewPath)
        {
            importPapers(from: [URL(fileURLWithPath: previewPath)])
        }
    }

    var selectedPaper: Paper? {
        guard let selectedPaperID else { return nil }
        return papers.first(where: { $0.id == selectedPaperID })
    }

    var filteredPapers: [Paper] {
        papers
            .filter { paper in
                switch selectedFilter {
                case .all: return true
                case .reading: return paper.status == .reading
                case .finished: return paper.status == .finished
                case .favorite: return paper.isFavorite
                }
            }
            .filter { paper in
                guard let selectedCategory else { return true }
                return paper.category == selectedCategory
            }
            .filter { paper in
                guard !searchText.isEmpty else { return true }
                return paper.title.localizedCaseInsensitiveContains(searchText)
                    || paper.authors.localizedCaseInsensitiveContains(searchText)
                    || paper.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
            .sorted { lhs, rhs in
                lhs.lastOpenedAt > rhs.lastOpenedAt
            }
    }

    func importPapers(from urls: [URL]) {
        var firstImportedID: UUID?

        for url in urls {
            let resolvedURL = url.standardizedFileURL
            let ext = resolvedURL.pathExtension.lowercased()
            guard ["pdf", "docx", "doc"].contains(ext) else { continue }

            if let existing = papers.first(where: { $0.fileURL.standardizedFileURL == resolvedURL }) {
                firstImportedID = firstImportedID ?? existing.id
                continue
            }

            let kind: PaperKind = ext == "pdf" ? .pdf : .word
            var paper = Paper(
                title: resolvedURL.deletingPathExtension().lastPathComponent,
                filePath: resolvedURL.path,
                kind: kind
            )
            paper.status = .reading
            papers.append(paper)
            firstImportedID = firstImportedID ?? paper.id
        }

        if let firstImportedID {
            selectPaper(firstImportedID)
        }
        scheduleSave()
    }

    func selectPaper(_ id: UUID) {
        selectedPaperID = id
        if let index = papers.firstIndex(where: { $0.id == id }) {
            papers[index].lastOpenedAt = Date()
            if papers[index].status == .unread {
                papers[index].status = .reading
            }
        }
        selectedSourceText = ""
        selectedLocation = ""
        scheduleSave()
    }

    func updateSelection(text: String, location: String) {
        selectedSourceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedLocation = location
        if !selectedSourceText.isEmpty {
            inspectorTab = .study
        }
    }

    @discardableResult
    func updatePaper(_ paper: Paper, persistImmediately: Bool = false) -> Bool {
        guard let index = papers.firstIndex(where: { $0.id == paper.id }) else { return false }
        papers[index] = paper
        if persistImmediately {
            saveTask?.cancel()
            return save()
        }
        scheduleSave()
        return true
    }

    @discardableResult
    func deletePaperRecord(_ paperID: UUID) -> Bool {
        guard papers.contains(where: { $0.id == paperID }) else { return false }

        papers.removeAll { $0.id == paperID }
        notes.removeAll { $0.paperID == paperID }
        rebuildGlossaryFromNotes()

        if selectedPaperID == paperID {
            selectedPaperID = filteredPapers.first?.id
            selectedSourceText = ""
            selectedLocation = ""
        }

        saveTask?.cancel()
        return save()
    }

    func toggleFavorite(_ paperID: UUID) {
        guard let index = papers.firstIndex(where: { $0.id == paperID }) else { return }
        papers[index].isFavorite.toggle()
        scheduleSave()
    }

    func setCategory(_ category: String, for paperID: UUID) {
        guard let index = papers.firstIndex(where: { $0.id == paperID }) else { return }
        papers[index].category = category
        if !categories.contains(category) {
            categories.append(category)
            categories.sort()
        }
        scheduleSave()
    }

    func addCategory(_ category: String) {
        let clean = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !categories.contains(clean) else { return }
        categories.append(clean)
        categories.sort()
        scheduleSave()
    }

    func addNote(
        paperID: UUID,
        sourceText: String,
        result: AnalysisResult,
        personalNote: String,
        location: String
    ) {
        let note = StudyNote(
            paperID: paperID,
            sourceText: sourceText,
            translation: result.translation,
            explanation: result.explanation,
            personalNote: personalNote,
            corePoint: result.corePoint,
            location: location,
            keywords: result.keywords
        )
        notes.insert(note, at: 0)

        for keyword in result.keywords {
            let occurrences = occurrenceCount(of: keyword.term, in: sourceText)
            recordKeyword(keyword, paperID: paperID, occurrences: max(1, occurrences))
        }
        scheduleSave()
    }

    func deleteNote(_ noteID: UUID) {
        notes.removeAll { $0.id == noteID }
        scheduleSave()
    }

    func notes(for paperID: UUID) -> [StudyNote] {
        notes
            .filter { $0.paperID == paperID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func recordKeyword(_ keyword: KeywordSuggestion, paperID: UUID, occurrences: Int = 1) {
        let normalized = keyword.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        let increment = max(1, occurrences)

        if let index = glossary.firstIndex(where: { $0.id == normalized }) {
            glossary[index].frequency += increment
            glossary[index].paperIDs.insert(paperID)
            glossary[index].lastSeenAt = Date()
            if glossary[index].translation.isEmpty {
                glossary[index].translation = keyword.translation
            }
        } else {
            var term = GlossaryTerm(
                term: keyword.term,
                translation: keyword.translation,
                paperID: paperID
            )
            term.frequency = increment
            glossary.append(term)
        }
        glossary.sort {
            if $0.frequency == $1.frequency {
                return $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending
            }
            return $0.frequency > $1.frequency
        }
    }

    func exportNotes(for paperID: UUID) throws -> URL {
        guard let paper = papers.first(where: { $0.id == paperID }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFilename(paper.title))-精读笔记.md")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var markdown = "# \(paper.title)\n\n"
        if !paper.citationText.isEmpty {
            markdown += "> \(paper.citationText)\n\n"
        }
        for note in notes(for: paperID) {
            markdown += "## \(note.location.isEmpty ? "精读片段" : note.location)\n\n"
            markdown += "**原文**\n\n\(note.sourceText)\n\n"
            markdown += "**翻译**\n\n\(note.translation)\n\n"
            if !note.explanation.isEmpty {
                markdown += "**语境释义**\n\n\(note.explanation)\n\n"
            }
            if !note.corePoint.isEmpty {
                markdown += "**核心观点**\n\n\(note.corePoint)\n\n"
            }
            if !note.personalNote.isEmpty {
                markdown += "**我的笔记**\n\n\(note.personalNote)\n\n"
            }
            if !note.keywords.isEmpty {
                markdown += "**关键词** \(note.keywords.map(\.term).joined(separator: " · "))\n\n"
            }
            markdown += "_\(dateFormatter.string(from: note.createdAt))_\n\n---\n\n"
        }
        try markdown.write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard
            let data = try? Data(contentsOf: persistenceURL),
            let snapshot = try? decoder.decode(LibrarySnapshot.self, from: data)
        else {
            categories = LibrarySnapshot().categories
            return
        }
        papers = snapshot.papers
        notes = snapshot.notes
        glossary = snapshot.glossary
        categories = snapshot.categories
        selectedPaperID = papers.sorted(by: { $0.lastOpenedAt > $1.lastOpenedAt }).first?.id
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            _ = self?.save()
        }
    }

    @discardableResult
    private func save() -> Bool {
        let snapshot = LibrarySnapshot(
            papers: papers,
            notes: notes,
            glossary: glossary,
            categories: categories
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return false }
        do {
            try data.write(to: persistenceURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return value.components(separatedBy: invalid).joined(separator: "-")
    }

    private func occurrenceCount(of term: String, in source: String) -> Int {
        let cleanTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTerm.isEmpty else { return 0 }
        let source = source.lowercased()
        let term = cleanTerm.lowercased()
        var count = 0
        var searchRange = source.startIndex..<source.endIndex
        while let range = source.range(of: term, options: [], range: searchRange) {
            count += 1
            searchRange = range.upperBound..<source.endIndex
        }
        return count
    }

    private func rebuildGlossaryFromNotes() {
        glossary = []
        for note in notes {
            for keyword in note.keywords {
                let occurrences = occurrenceCount(of: keyword.term, in: note.sourceText)
                recordKeyword(
                    keyword,
                    paperID: note.paperID,
                    occurrences: max(1, occurrences)
                )
            }
        }
    }
}
