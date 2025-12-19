# Part 4: API Design and Error Design

## 4.1 Public Swift API

### AbacusRecognizer (Main Facade)

```swift
/// Soroban recognition engine
/// Thread-safe. Can be called simultaneously from multiple threads.
public actor AbacusRecognizer {
    
    // MARK: - Initialization
    
    /// Initialize with configuration
    public init(configuration: AbacusConfiguration) throws
    
    /// Initialize with bundled model (default configuration)
    public convenience init() throws
    
    // MARK: - Recognition
    
    /// Recognize a single frame
    public func recognize(pixelBuffer: CVPixelBuffer) async throws -> AbacusResult
    
    /// Continuous recognition (with stabilization)
    public func recognizeContinuous(
        pixelBuffer: CVPixelBuffer,
        strategy: StabilizationStrategy = .default
    ) async throws -> AbacusResult
    
    // MARK: - Configuration
    
    /// Update configuration
    public func updateConfiguration(_ config: AbacusConfiguration) async
    
    /// Get current configuration
    public var configuration: AbacusConfiguration { get async }
    
    // MARK: - Model Management
    
    /// Reload model
    public func reloadModel() async throws
    
    /// Model version information
    public var modelInfo: ModelInfo { get async }
}
```

### AbacusConfiguration

```swift
/// Recognition engine configuration
public struct AbacusConfiguration: Sendable, Codable {
    
    // MARK: - Model
    public var modelPath: URL?                    // nil = bundled model
    public var inferenceBackend: InferenceBackend
    
    // MARK: - Recognition
    public var digitCount: Int                    // 1-13
    public var minFrameSizeRatio: Float
    public var confidenceThreshold: Float         // 0.0-1.0
    
    // MARK: - Performance
    public var frameSkipInterval: Int             // 1 = every frame
    public var maxInputResolution: Int
    
    // MARK: - Debug
    public var enableDebugOverlay: Bool
    public var enablePerformanceLogging: Bool
    
    // MARK: - Presets
    public static let `default`: AbacusConfiguration
    public static let highAccuracy: AbacusConfiguration  // slower
    public static let fast: AbacusConfiguration          // lower accuracy
}

public enum InferenceBackend: String, Sendable, Codable {
    case coreml   // Neural Engine (recommended)
    case mps      // GPU
    case xnnpack  // CPU
    case auto     // Auto-select
}
```

### AbacusResult

```swift
/// Recognition result
public struct AbacusResult: Sendable, Equatable {
    public let value: Int              // Recognized value
    public let cells: [CellState]      // State of each cell
    public let digits: [DigitInfo]     // Detailed information for each digit
    public let confidence: Float       // Overall confidence (0.0-1.0)
    public let frameRect: CGRect       // Soroban frame position
    public let processingTimeMs: Double
    public let timingBreakdown: TimingBreakdown
    public let timestamp: Date
}

public struct DigitInfo: Sendable, Equatable {
    public let position: Int           // 0-indexed from right
    public let value: Int              // 0-9
    public let upperBead: CellState
    public let lowerBeads: [CellState] // 4 beads
    public let confidence: Float
    public let boundingBox: CGRect
}

public enum CellState: Int, Sendable, Codable {
    case upper = 0  // Upper position (not counting)
    case lower = 1  // Lower position (counting)
    case empty = 2  // Not detected
}

public struct TimingBreakdown: Sendable {
    public let preprocessingMs: Double
    public let detectionMs: Double
    public let inferenceMs: Double
    public let postprocessingMs: Double
    public let totalMs: Double
}
```

---

## 4.2 Error Design

```swift
/// AbacusKit errors
public enum AbacusError: Error, Sendable {
    // Configuration Errors
    case invalidConfiguration(reason: String)
    case modelNotFound(path: String)
    case modelLoadFailed(underlying: Error)
    
    // Vision Errors
    case preprocessingFailed(reason: String, code: Int)
    case abacusNotDetected
    case invalidInput(reason: String)
    
    // Inference Errors
    case inferenceFailed(underlying: Error)
    case modelNotLoaded
    
    // Recognition Errors
    case lowConfidence(confidence: Float, threshold: Float)
    case segmentationFailed(reason: String)
}

extension AbacusError {
    /// Whether the error is retryable
    public var isRetryable: Bool {
        switch self {
        case .abacusNotDetected, .lowConfidence:
            return true  // May improve in the next frame
        case .modelLoadFailed, .modelNotFound, .invalidConfiguration:
            return false // Configuration change required
        default:
            return false
        }
    }
}
```

---

## 4.3 StabilizationStrategy

```swift
/// Stabilization strategy for continuous recognition
public struct StabilizationStrategy: Sendable {
    public var consecutiveMatchCount: Int
    public var historyWindowSize: Int
    public var confidenceWeight: Float
    
    public static let `default` = StabilizationStrategy(
        consecutiveMatchCount: 3, historyWindowSize: 5, confidenceWeight: 0.7
    )
    public static let responsive = StabilizationStrategy(
        consecutiveMatchCount: 2, historyWindowSize: 3, confidenceWeight: 0.5
    )
    public static let stable = StabilizationStrategy(
        consecutiveMatchCount: 5, historyWindowSize: 10, confidenceWeight: 0.9
    )
}
```

---

## 4.4 Model Update API (GitHub Releases)

```swift
/// Model update manager
public actor AbacusModelUpdater {
    public func checkForUpdates(repository: String = "owner/AbacusKit") async throws -> ModelUpdateInfo?
    public func downloadAndInstall(updateInfo: ModelUpdateInfo, progress: @escaping (Double) -> Void) async throws -> URL
    public func clearCache() async throws
    public var installedVersion: String? { get async }
}

public struct ModelUpdateInfo: Sendable {
    public let version: String      // e.g., "v1.2.0"
    public let releaseDate: Date
    public let downloadURL: URL
    public let releaseNotes: String
    public let fileSize: Int64
    public let checksum: String     // SHA256
}
```

---

## 4.5 Usage Examples

### Basic Usage

```swift
import AbacusKit
import AVFoundation

class AbacusViewController: UIViewController {
    private var recognizer: AbacusRecognizer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recognizer = try! AbacusRecognizer()
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task {
            do {
                let result = try await recognizer.recognize(pixelBuffer: pixelBuffer)
                await MainActor.run { updateUI(with: result) }
            } catch AbacusError.abacusNotDetected {
                // Soroban not found
            } catch {
                print("Recognition error: \(error)")
            }
        }
    }
}
```

### Custom Configuration

```swift
var config = AbacusConfiguration.default
config.digitCount = 5
config.inferenceBackend = .mps
config.confidenceThreshold = 0.8

let recognizer = try AbacusRecognizer(configuration: config)
```

### Continuous Recognition (Stabilized)

```swift
let result = try await recognizer.recognizeContinuous(
    pixelBuffer: buffer,
    strategy: .stable
)

if result.confidence > 0.9 {
    confirmValue(result.value)
}
```
