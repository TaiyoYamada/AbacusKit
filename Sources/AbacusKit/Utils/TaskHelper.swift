import Foundation

/// Helper utilities for async task management
///
/// This module provides utilities for managing concurrent operations
/// and task cancellation in a structured concurrency environment.
public enum TaskHelper {
    /// Execute an async operation with timeout
    /// - Parameters:
    ///   - timeout: Maximum duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: Result of the operation
    /// - Throws: CancellationError if timeout is exceeded, or error from operation
    public static func withTimeout<T: Sendable>(
        _ timeout: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // タスクを実行
            group.addTask {
                try await operation()
            }

            // タイムアウトタスクを追加
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }

            // 最初に完了したタスクの結果を返す
            guard let result = try await group.next() else {
                throw TimeoutError()
            }

            // 残りのタスクをキャンセル
            group.cancelAll()

            return result
        }
    }

    /// Execute multiple async operations concurrently
    /// - Parameter operations: Array of async operations to execute
    /// - Returns: Array of results in the same order as operations
    /// - Throws: First error encountered, if any
    public static func concurrent<T: Sendable>(
        _ operations: [@Sendable () async throws -> T]
    ) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            // すべての操作をタスクグループに追加
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    let result = try await operation()
                    return (index, result)
                }
            }

            // 結果を収集
            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }

            // インデックス順にソートして返す
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Retry an async operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts
    ///   - initialDelay: Initial delay in seconds before first retry
    ///   - maxDelay: Maximum delay in seconds between retries
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    /// - Throws: Last error if all attempts fail
    public static func retry<T: Sendable>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // 最後の試行の場合はエラーをスロー
                if attempt == maxAttempts {
                    break
                }

                // 指数バックオフで待機
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, maxDelay)
            }
        }

        throw lastError ?? TimeoutError()
    }
}

// MARK: - Timeout Error

/// Error thrown when an operation exceeds its timeout
public struct TimeoutError: Error, LocalizedError {
    public var errorDescription: String? {
        "Operation timed out"
    }
}
