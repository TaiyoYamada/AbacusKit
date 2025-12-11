// AbacusKit - Main Entry Point
// Swift 6.2 + C++ Interop

/// AbacusKit - そろばん認識 SDK
///
/// リアルタイムでそろばんの状態を認識し、数値に変換するSDK。
/// OpenCV による高速前処理と ExecuTorch による推論を組み合わせ、
/// 30FPS 以上のリアルタイム処理を実現。
///
/// ## 機能
/// - 可変レーン対応（1〜27桁）
/// - 自動フレーム検出・射影補正
/// - 高精度セル状態分類
/// - Swift 6 Concurrency 完全対応
///
/// ## 基本的な使用例
///
/// ```swift
/// import AbacusKit
///
/// let recognizer = try AbacusRecognizer()
///
/// // カメラフレームから認識
/// let result = try await recognizer.recognize(pixelBuffer: cameraFrame)
/// print("認識値: \(result.value)")
/// print("信頼度: \(result.confidence)")
/// ```

@_exported import CoreVideo
@_exported import Foundation
