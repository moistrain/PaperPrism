import Foundation
import PDFKit

enum DocumentTextExtractor {
    static func firstPagesText(for paper: Paper, characterLimit: Int = 12_000) async -> String {
        switch paper.kind {
        case .pdf:
            guard let document = PDFDocument(url: paper.fileURL) else { return "" }
            var text = ""
            for pageIndex in 0..<min(document.pageCount, 3) {
                guard let page = document.page(at: pageIndex), let pageText = page.string else { continue }
                text += pageText + "\n"
                if text.count >= characterLimit { break }
            }
            return String(text.prefix(characterLimit))
        case .word:
            return await extractWordText(at: paper.fileURL, characterLimit: characterLimit)
        }
    }

    static func detectedDOI(in text: String) -> String {
        let pattern = #"10\.\d{4,9}/[-._;()/:A-Z0-9]+"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = expression.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ),
            let range = Range(match.range, in: text)
        else { return "" }

        return String(text[range])
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:)]}"))
    }

    private static func extractWordText(at url: URL, characterLimit: Int) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
            process.arguments = ["-convert", "txt", "-stdout", url.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { process in
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: "")
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: String(text.prefix(characterLimit)))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
