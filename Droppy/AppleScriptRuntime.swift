import Foundation

/// Process-wide synchronization for NSAppleScript execution.
/// NSAppleScript is not thread-safe across concurrent calls, even from different queues.
enum AppleScriptRuntime {
    private static let lock = NSLock()

    static func execute<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return autoreleasepool(invoking: block)
    }
}
