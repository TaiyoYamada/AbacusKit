// AbacusKit - AbacusError
// Swift 6.2

import Foundation

/// AbacusKit のエラー
public enum AbacusError: Error, Sendable {
    // MARK: - 設定エラー

    /// 無効な設定
    case invalidConfiguration(reason: String)

    /// モデルファイルが見つからない
    case modelNotFound(path: String)

    /// モデルのロードに失敗
    case modelLoadFailed(underlying: Error)

    /// モデルがロードされていない
    case modelNotLoaded

    // MARK: - 入力エラー

    /// 無効な入力
    case invalidInput(reason: String)

    /// サポートされていないピクセルフォーマット
    case unsupportedPixelFormat(format: String)

    // MARK: - 検出エラー

    /// そろばんフレームが検出できない
    case frameNotDetected

    /// レーン分割に失敗
    case laneExtractionFailed(reason: String)

    /// 前処理に失敗
    case preprocessingFailed(reason: String, code: Int)

    // MARK: - 推論エラー

    /// 推論に失敗
    case inferenceFailed(underlying: Error)

    /// テンソル変換に失敗
    case tensorConversionFailed(reason: String)

    // MARK: - 結果エラー

    /// 信頼度が閾値未満
    case lowConfidence(confidence: Float, threshold: Float)

    /// 無効な結果
    case invalidResult(reason: String)

    // MARK: - システムエラー

    /// メモリ不足
    case outOfMemory

    /// 内部エラー
    case internalError(message: String)
}

// MARK: - LocalizedError

extension AbacusError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(reason):
            "無効な設定: \(reason)"

        case let .modelNotFound(path):
            "モデルが見つかりません: \(path)"

        case let .modelLoadFailed(error):
            "モデルのロードに失敗: \(error.localizedDescription)"

        case .modelNotLoaded:
            "モデルがロードされていません"

        case let .invalidInput(reason):
            "無効な入力: \(reason)"

        case let .unsupportedPixelFormat(format):
            "サポートされていないピクセルフォーマット: \(format)"

        case .frameNotDetected:
            "そろばんフレームが検出できませんでした"

        case let .laneExtractionFailed(reason):
            "レーン分割に失敗: \(reason)"

        case let .preprocessingFailed(reason, code):
            "前処理に失敗 (\(code)): \(reason)"

        case let .inferenceFailed(error):
            "推論に失敗: \(error.localizedDescription)"

        case let .tensorConversionFailed(reason):
            "テンソル変換に失敗: \(reason)"

        case let .lowConfidence(confidence, threshold):
            "信頼度が低すぎます (\(String(format: "%.1f%%", confidence * 100)) < \(String(format: "%.1f%%", threshold * 100)))"

        case let .invalidResult(reason):
            "無効な結果: \(reason)"

        case .outOfMemory:
            "メモリ不足"

        case let .internalError(message):
            "内部エラー: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .frameNotDetected:
            "そろばんがカメラに写っているか確認してください"
        case .lowConfidence:
            "照明を改善するか、カメラを近づけてください"
        case .modelNotFound,
             .modelNotLoaded:
            "アプリを再インストールしてください"
        default:
            nil
        }
    }
}

// MARK: - リトライ可能性

extension AbacusError {
    /// このエラーがリトライ可能か
    public var isRetryable: Bool {
        switch self {
        case .frameNotDetected,
             .lowConfidence,
             .laneExtractionFailed:
            true
        case .modelNotLoaded,
             .modelNotFound,
             .invalidConfiguration:
            false
        default:
            false
        }
    }
}
