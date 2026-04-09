import Foundation
import UIKit
import Vision
import PDFKit

enum TopicImportError: LocalizedError {
    case ocrEmpty
    case pdfTooLarge
    case pdfUnreadable
    case linkFetchFailed(String)
    case podcastNotSupported

    var errorDescription: String? {
        switch self {
        case .ocrEmpty: return "Konnte keinen Text im Bild erkennen — versuch ein anderes Bild oder gib das Thema manuell ein."
        case .pdfTooLarge: return "PDF ist zu groß (max. 5 MB)."
        case .pdfUnreadable: return "PDF konnte nicht gelesen werden."
        case .linkFetchFailed(let msg): return "Link konnte nicht geladen werden: \(msg)"
        case .podcastNotSupported: return "Podcast-Import kommt bald."
        }
    }
}

enum TopicSourceImporter {

    // MARK: - Photo OCR

    static func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw TopicImportError.ocrEmpty }

        let text: String = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let combined = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: combined)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TopicImportError.ocrEmpty }
        return trimmed
    }

    // MARK: - PDF

    static func extractText(from pdfData: Data) throws -> String {
        guard pdfData.count <= 5 * 1024 * 1024 else { throw TopicImportError.pdfTooLarge }
        guard let document = PDFDocument(data: pdfData) else { throw TopicImportError.pdfUnreadable }

        var combined = ""
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let pageText = page.string {
                combined += pageText + "\n"
            }
        }

        let trimmed = combined.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw TopicImportError.pdfUnreadable }
        return trimmed
    }

    // MARK: - Web Link (best-effort plain-text scrape)

    static func extractText(from url: URL) async throws -> String {
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (compatible; Lern-Kalender/1.0)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                throw TopicImportError.linkFetchFailed("Encoding-Fehler")
            }
            return stripHTML(html)
        } catch let importError as TopicImportError {
            throw importError
        } catch {
            throw TopicImportError.linkFetchFailed(error.localizedDescription)
        }
    }

    private static func stripHTML(_ html: String) -> String {
        // Drop script and style blocks first.
        let withoutScripts = html.replacingOccurrences(
            of: "<script[\\s\\S]*?</script>",
            with: " ",
            options: .regularExpression
        )
        let withoutStyles = withoutScripts.replacingOccurrences(
            of: "<style[\\s\\S]*?</style>",
            with: " ",
            options: .regularExpression
        )
        // Replace tags with spaces.
        let stripped = withoutStyles.replacingOccurrences(
            of: "<[^>]+>",
            with: " ",
            options: .regularExpression
        )
        // Decode the most common entities.
        let entities = stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        // Collapse runs of whitespace.
        let collapsed = entities.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Podcast (stub)

    static func extractText(fromPodcast url: URL) async throws -> String {
        throw TopicImportError.podcastNotSupported
    }
}
