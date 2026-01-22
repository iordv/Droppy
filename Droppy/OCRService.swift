//
//  OCRService.swift
//  Droppy
//
//  Created by Jordy Spruit on 02/01/2026.
//

import SwiftUI
@preconcurrency import Vision
import PDFKit
import UniformTypeIdentifiers

/// Service to handle OCR text extraction from Images and PDFs
class OCRService {
    static let shared = OCRService()
    
    private init() {}
    
    /// Extracts text from a file at the given URL
    func extractText(from url: URL) async throws -> String {
        // Determine file type
        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
        guard let contentType = resourceValues.contentType else {
            throw OCRError.unknownFileType
        }
        
        if contentType.conforms(to: .pdf) {
            return try await extractTextFromPDF(url: url)
        } else if contentType.conforms(to: .image) {
            return try await extractTextFromImage(url: url)
        } else {
            throw OCRError.unsupportedFileType
        }
    }
    
    private func extractTextFromPDF(url: URL) async throws -> String {
        let pdfDoc = try await Task.detached(priority: .userInitiated) {
            guard let pdfDoc = PDFDocument(url: url) else {
                throw OCRError.couldNotLoadPDF
            }
            return pdfDoc
        }.value
        
        // We will process all pages
        var fullText = ""
        
        for i in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: i) else { continue }
            
            // Convert PDF Page to Image for reliable OCR
            // Drawing to image ensures we get text even if it's not embedded text (scanned PDF)
            let pageRect = page.bounds(for: .mediaBox)
            let image = NSImage(size: pageRect.size, flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                page.draw(with: .mediaBox, to: context)
                return true
            }
            
            if let pageText = try? await performOCR(on: image) {
                if !fullText.isEmpty {
                    fullText += "\n\n--- Page \(i + 1) ---\n\n"
                }
                fullText += pageText
            }
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTextFromImage(url: URL) async throws -> String {
        let image = try await Task.detached(priority: .userInitiated) {
            guard let image = NSImage(contentsOf: url) else {
                throw OCRError.couldNotLoadImage
            }
            return image
        }.value
        return try await performOCR(on: image)
    }
    
    func performOCR(on image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.couldNotProcessImageData
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: "")
                        return
                    }
                    
                    let text = observations.compactMap {
                        $0.topCandidates(1).first?.string
                    }.joined(separator: "\n")
                    
                    continuation.resume(returning: text)
                }
                
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                
                do {
                    try requestHandler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum OCRError: LocalizedError {
    case unknownFileType
    case unsupportedFileType
    case couldNotLoadPDF
    case couldNotLoadImage
    case couldNotProcessImageData
    
    var errorDescription: String? {
        switch self {
        case .unknownFileType: return "Could not determine file type."
        case .unsupportedFileType: return "File type not supported for OCR."
        case .couldNotLoadPDF: return "Could not load PDF document."
        case .couldNotLoadImage: return "Could not load image file."
        case .couldNotProcessImageData: return "Could not process image data."
        }
    }
}
