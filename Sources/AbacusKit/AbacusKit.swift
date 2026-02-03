// AbacusKit - Main Entry Point
// Swift 6.2 + C++ Interop

/// AbacusKit is a real-time soroban (Japanese abacus) recognition SDK.
///
/// This framework detects soroban from camera frames and recognizes
/// their state as numeric values. It combines high-speed image preprocessing
/// with OpenCV and accurate machine learning inference with ExecuTorch
/// to achieve real-time processing at 30+ FPS.
///
/// ## Features
///
/// - **Variable Lane Support**: Supports any soroban from 1 to 27 digits.
/// - **Automatic Frame Detection**: Detects soroban frame and applies perspective correction.
/// - **High-Accuracy Classification**: Uses neural networks for precise bead state detection.
/// - **Swift 6 Concurrency Ready**: Fully compatible with async/await and actors.
///
/// ## Basic Usage
///
/// ```swift
/// import AbacusKit
///
/// let recognizer = AbacusRecognizer()
///
/// // Recognize a camera frame
/// let result = try await recognizer.recognize(pixelBuffer: cameraFrame)
/// print("Recognized value: \(result.value)")
/// print("Confidence: \(result.confidence)")
/// ```
///
/// ## Architecture
///
/// AbacusKit is structured into three main layers:
///
/// 1. **AbacusVision (C++)**: Handles image preprocessing using OpenCV,
///    including frame detection, perspective warping, and lane extraction.
///
/// 2. **AbacusInferenceEngine (Swift)**: Performs neural network inference
///    using ExecuTorch to classify individual bead states.
///
/// 3. **SorobanInterpreter (Swift)**: Converts classified bead states
///    into numeric digit values according to soroban counting rules.
///
/// ## Topics
///
/// ### Getting Started
///
/// - ``AbacusRecognizer``
/// - ``AbacusConfiguration``
///
/// ### Recognition Results
///
/// - ``SorobanResult``
/// - ``SorobanLane``
/// - ``SorobanDigit``
///
/// ### Bead States
///
/// - ``CellState``
/// - ``CellPrediction``
///
/// ### Error Handling
///
/// - ``AbacusError``
///
/// ### Single Row Recognition
///
/// - ``SingleRowRecognizer``
/// - ``SingleRowConfiguration``
/// - ``SingleRowResult``

@_exported import CoreVideo
@_exported import Foundation
