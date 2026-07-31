import Foundation

enum PaperKind: String, Codable, CaseIterable {
    case pdf
    case word

    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .word: return "Word"
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .word: return "doc.text"
        }
    }
}

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case unread
    case reading
    case finished

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unread: return "待读"
        case .reading: return "精读中"
        case .finished: return "已读完"
        }
    }
}

struct Paper: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var filePath: String
    var kind: PaperKind
    var category: String = "未分类"
    var status: ReadingStatus = .unread
    var isFavorite = false
    var importedAt = Date()
    var lastOpenedAt = Date()
    var readingProgress: Double = 0
    var authors = ""
    var year = ""
    var venue = ""
    var doi = ""
    var citationText = ""
    var tags: [String] = []

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }
}

struct StudyNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var paperID: UUID
    var sourceText: String
    var translation: String
    var explanation: String
    var personalNote: String
    var corePoint: String
    var location: String
    var keywords: [KeywordSuggestion]
    var createdAt = Date()
}

struct KeywordSuggestion: Identifiable, Codable, Hashable {
    var term: String
    var translation: String

    var id: String { term.lowercased() }
}

struct GlossaryTerm: Identifiable, Codable, Hashable {
    var id: String
    var term: String
    var translation: String
    var frequency: Int
    var paperIDs: Set<UUID>
    var lastSeenAt: Date

    init(term: String, translation: String, paperID: UUID) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.id = normalized
        self.term = term.trimmingCharacters(in: .whitespacesAndNewlines)
        self.translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.frequency = 1
        self.paperIDs = [paperID]
        self.lastSeenAt = Date()
    }
}

struct AnalysisResult: Codable, Equatable {
    var translation: String
    var explanation: String
    var corePoint: String
    var keywords: [KeywordSuggestion]

    static let empty = AnalysisResult(
        translation: "",
        explanation: "",
        corePoint: "",
        keywords: []
    )
}

struct CitationExtractionResult: Codable, Equatable {
    var title: String
    var authors: String
    var year: String
    var venue: String
    var doi: String
    var tags: [String]
    var citationText: String
    var confidence: Double
    var rationale: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        authors = try container.decodeIfPresent(String.self, forKey: .authors) ?? ""
        year = try container.decodeIfPresent(String.self, forKey: .year) ?? ""
        venue = try container.decodeIfPresent(String.self, forKey: .venue) ?? ""
        doi = try container.decodeIfPresent(String.self, forKey: .doi) ?? ""
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        citationText = try container.decodeIfPresent(String.self, forKey: .citationText) ?? ""
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5
        rationale = try container.decodeIfPresent(String.self, forKey: .rationale) ?? ""
    }

    init(
        title: String,
        authors: String,
        year: String,
        venue: String,
        doi: String,
        tags: [String],
        citationText: String,
        confidence: Double,
        rationale: String
    ) {
        self.title = title
        self.authors = authors
        self.year = year
        self.venue = venue
        self.doi = doi
        self.tags = tags
        self.citationText = citationText
        self.confidence = confidence
        self.rationale = rationale
    }
}

struct LibrarySnapshot: Codable {
    var papers: [Paper] = []
    var notes: [StudyNote] = []
    var glossary: [GlossaryTerm] = []
    var categories: [String] = ["未分类", "信任与人机协作", "LLM Agent", "研究方法"]
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case reading
    case finished
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部论文"
        case .reading: return "精读中"
        case .finished: return "已读完"
        case .favorite: return "重点关注"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "books.vertical"
        case .reading: return "book.pages"
        case .finished: return "checkmark.circle"
        case .favorite: return "bookmark"
        }
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case study
    case notes
    case glossary
    case citation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return "精读"
        case .notes: return "笔记"
        case .glossary: return "词库"
        case .citation: return "引用"
        }
    }
}
