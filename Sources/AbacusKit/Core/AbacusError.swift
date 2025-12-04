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
        case .invalidConfiguration(let reason):
            return "無効な設定: \(reason)"
            
        case .modelNotFound(let path):
            return "モデルが見つかりません: \(path)"
            
        case .modelLoadFailed(let error):
            return "モデルのロードに失敗: \(error.localizedDescription)"
            
        case .modelNotLoaded:
            return "モデルがロードされていません"
            
        case .invalidInput(let reason):
            return "無効な入力: \(reason)"
            
        case .unsupportedPixelFormat(let format):
            return "サポートされていないピクセルフォーマット: \(format)"
            
        case .frameNotDetected:
            return "そろばんフレームが検出できませんでした"
            
        case .laneExtractionFailed(let reason):
            return "レーン分割に失敗: \(reason)"
            
        case .preprocessingFailed(let reason, let code):
            return "前処理に失敗 (\(code)): \(reason)"
            
        case .inferenceFailed(let error):
            return "推論に失敗: \(error.localizedDescription)"
            
        case .tensorConversionFailed(let reason):
            return "テンソル変換に失敗: \(reason)"
            
        case .lowConfidence(let confidence, let threshold):
            return "信頼度が低すぎます (\(String(format: "%.1f%%", confidence * 100)) < \(String(format: "%.1f%%", threshold * 100)))"
            
        case .invalidResult(let reason):
            return "無効な結果: \(reason)"
            
        case .outOfMemory:
            return "メモリ不足"
            
        case .internalError(let message):
            return "内部エラー: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .frameNotDetected:
            return "そろばんがカメラに写っているか確認してください"
        case .lowConfidence:
            return "照明を改善するか、カメラを近づけてください"
        case .modelNotFound, .modelNotLoaded:
            return "アプリを再インストールしてください"
        default:
            return nil
        }
    }
}

// MARK: - リトライ可能性

extension AbacusError {
    /// このエラーがリトライ可能か
    public var isRetryable: Bool {
        switch self {
        case .frameNotDetected, .lowConfidence, .laneExtractionFailed:
            return true
        case .modelNotLoaded, .modelNotFound, .invalidConfiguration:
            return false
        default:
            return false
        }
    }
}
