import Foundation
import AppKit

// Mocking the structs and enums needed for the test
enum ClipboardType: String, Codable {
    case text
    case image
    case file
    case url
    case color
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: ClipboardType
    var content: String?
    var imageData: Data?
    var imageFilePath: String?
    var date: Date = Date()
    var sourceApp: String?
    var isFavorite: Bool = false
    var isFlagged: Bool = false
    var isConcealed: Bool = false
    var customTitle: String?
    var rtfData: Data?

    // Simplified hash/equatable for the benchmark
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool { lhs.id == rhs.id }
}

// Global path for the benchmark
let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DroppyBenchmark")
let persistenceURL = tempDir.appendingPathComponent("clipboard_history.json")
let imagesDirectory = tempDir.appendingPathComponent("images")

func setupBenchmarkData() {
    try? FileManager.default.removeItem(at: tempDir)
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

    var items: [ClipboardItem] = []

    // Generate 50 items with image data (similar to python benchmark ~13MB)
    for i in 0..<20 {
         // Create dummy image data (approx 500KB)
        let dummyData = Data(repeating: 0xFF, count: 500 * 1024)
        items.append(ClipboardItem(type: .image, imageData: dummyData))
    }

    let data = try! JSONEncoder().encode(items)
    try! data.write(to: persistenceURL)
    print("Created benchmark file with \(items.count) items at \(persistenceURL.path) size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
}

func syncLoadFromDisk() {
    guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
    do {
        let startTime = CFAbsoluteTimeGetCurrent()

        let data = try Data(contentsOf: persistenceURL)
        let decoder = JSONDecoder()
        var decoded = try decoder.decode([ClipboardItem].self, from: data)

        // Simulate the migration logic (checking for inline images)
        var needsSave = false
        for i in decoded.indices {
            if decoded[i].type == .image,
               decoded[i].imageData != nil,
               decoded[i].imageFilePath == nil {
                // Simulate saving image to file
                let id = decoded[i].id
                let filename = "\(id.uuidString).jpg"
                let fileURL = imagesDirectory.appendingPathComponent(filename)
                try? decoded[i].imageData!.write(to: fileURL)

                decoded[i].imageFilePath = filename
                decoded[i].imageData = nil
                needsSave = true
            }
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("Sync Load Duration: \(String(format: "%.4f", duration)) seconds")

    } catch {
        print("Failed to load: \(error)")
    }
}

// Run Benchmark
setupBenchmarkData()
print("Starting Sync Load Benchmark...")
syncLoadFromDisk()

// Cleanup
try? FileManager.default.removeItem(at: tempDir)
