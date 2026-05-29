import Foundation
import Vision
import UIKit

struct ReceiptData {
    var merchant: String?
    var amount: Double?
    var date: Date?
    var rawText: String
    var confidence: Float

    var isValid: Bool {
        merchant != nil || amount != nil
    }
}

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Process an image and extract receipt data
    func processReceipt(image: UIImage) async throws -> ReceiptData {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        try requestHandler.perform([request])

        guard let observations = request.results else {
            throw OCRError.noTextFound
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        let fullText = recognizedStrings.joined(separator: "\n")
        let confidence = observations.compactMap { $0.topCandidates(1).first?.confidence }.reduce(0, +) / Float(max(observations.count, 1))

        // Parse the receipt
        let merchant = extractMerchant(from: recognizedStrings)
        let amount = extractAmount(from: fullText)
        let date = extractDate(from: fullText)

        return ReceiptData(
            merchant: merchant,
            amount: amount,
            date: date,
            rawText: fullText,
            confidence: confidence
        )
    }

    // MARK: - Extraction Methods

    private func extractMerchant(from lines: [String]) -> String? {
        // Usually the merchant name is in the first few lines
        // Look for known merchants first
        for line in lines.prefix(5) {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Check against known merchants
            if let merchant = MerchantDatabase.findMerchant(query: cleaned) {
                return merchant.name
            }
        }

        // If no known merchant, return the first substantial line
        for line in lines.prefix(3) {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Skip lines that look like addresses or dates
            if cleaned.count > 3 &&
               !cleaned.contains(where: { $0.isNumber && cleaned.filter({ $0.isNumber }).count > 5 }) &&
               !cleaned.lowercased().contains("receipt") &&
               !cleaned.lowercased().contains("thank you") {
                return cleaned
            }
        }

        return nil
    }

    private func extractAmount(from text: String) -> Double? {
        // Look for total amount patterns
        let patterns = [
            // "TOTAL $12.34" or "Total: $12.34"
            #"(?i)total[:\s]*\$?\s*(\d+[.,]\d{2})"#,
            // "AMOUNT $12.34"
            #"(?i)amount[:\s]*\$?\s*(\d+[.,]\d{2})"#,
            // "DUE $12.34"
            #"(?i)(?:amount\s*)?due[:\s]*\$?\s*(\d+[.,]\d{2})"#,
            // "GRAND TOTAL $12.34"
            #"(?i)grand\s*total[:\s]*\$?\s*(\d+[.,]\d{2})"#,
            // Standalone dollar amounts (last resort, find largest)
            #"\$\s*(\d+[.,]\d{2})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr) {
                    return amount
                }
            }
        }

        // Fallback: find the largest dollar amount (likely the total)
        let dollarPattern = #"\$\s*(\d+[.,]\d{2})"#
        if let regex = try? NSRegularExpression(pattern: dollarPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            var amounts: [Double] = []

            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let amountStr = String(text[range]).replacingOccurrences(of: ",", with: ".")
                    if let amount = Double(amountStr) {
                        amounts.append(amount)
                    }
                }
            }

            // Return the largest amount (usually the total)
            return amounts.max()
        }

        return nil
    }

    private func extractDate(from text: String) -> Date? {
        let datePatterns = [
            // MM/DD/YYYY or MM-DD-YYYY
            (#"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})"#, "MM/dd/yyyy"),
            // YYYY-MM-DD
            (#"(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})"#, "yyyy/MM/dd"),
            // Month DD, YYYY
            (#"(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2}),?\s+(\d{4})"#, "MMM dd yyyy"),
        ]

        for (pattern, _) in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {

                let dateStr = String(text[range])
                return parseDate(dateStr)
            }
        }

        return nil
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM-dd-yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MM/dd/yy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMM dd, yyyy"
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "MMMM dd, yyyy"
                return f
            }(),
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }

        return nil
    }
}

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .noTextFound:
            return "No text found in the image"
        case .processingFailed:
            return "Failed to process the receipt"
        }
    }
}
