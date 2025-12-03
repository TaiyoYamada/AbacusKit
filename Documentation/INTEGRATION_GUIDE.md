# Integration Guide

Advanced integration patterns for AbacusKit in production iOS applications.

## Table of Contents

- [Camera Integration](#camera-integration)
- [SwiftUI Integration](#swiftui-integration)
- [UIKit Integration](#uikit-integration)
- [Real-Time Processing](#real-time-processing)
- [Error Handling Strategies](#error-handling-strategies)
- [Testing](#testing)

## Camera Integration

### AVFoundation Setup

Complete camera integration with real-time inference:

```swift
import AVFoundation
import AbacusKit

class CameraInferenceManager: NSObject {
    // Camera components
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "camera.processing")
    
    // Inference engine
    private let engine = ExecuTorchInferenceEngine()
    
    // Frame throttling
    private var lastProcessedTime = Date.distantPast
    private let processingInterval: TimeInterval = 0.1  // 10 FPS
    
    // Callback
    var onDetection: ((AbacusCellState) -> Void)?
    
    func setup() async throws {
        // Load model
        guard let modelURL = Bundle.main.url(forResource: "abacus_model", withExtension: "pte") else {
            throw NSError(domain: "CameraInferenceManager", code: -1)
        }
        try await engine.loadModel(at: modelURL)
        
        // Setup camera
        try setupCamera()
    }
    
    private func setupCamera() throws {
        captureSession.sessionPreset = .hd1280x720
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, 
                                                   for: .video, 
                                                   position: .back) else {
            throw NSError(domain: "CameraInferenceManager", code: -2)
        }
        
        let input = try AVCaptureDeviceInput(device: camera)
        captureSession.addInput(input)
        
        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        captureSession.addOutput(videoOutput)
    }
    
    func startCapture() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func stopCapture() {
        captureSession.stopRunning()
    }
}

extension CameraInferenceManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Throttle processing
        let now = Date()
        guard now.timeIntervalSince(lastProcessedTime) >= processingInterval else {
            return
        }
        lastProcessedTime = now
        
        // Extract pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process frame
        Task {
            do {
                let result = try await engine.predict(pixelBuffer: pixelBuffer)
                await MainActor.run {
                    onDetection?(result.predictedState)
                }
            } catch {
                print("Inference error: \(error)")
            }
        }
    }
}
```

### Preview Layer

Display camera feed with overlays:

```swift
import UIKit
import AVFoundation

class CameraPreviewViewController: UIViewController {
    private let cameraManager = CameraInferenceManager()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let resultLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPreviewLayer()
        setupUI()
        
        Task {
            try await cameraManager.setup()
            cameraManager.onDetection = { [weak self] state in
                self?.updateResult(state)
            }
            cameraManager.startCapture()
        }
    }
    
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: cameraManager.captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }
    
    private func setupUI() {
        resultLabel.frame = CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 50)
        resultLabel.textAlignment = .center
        resultLabel.font = .systemFont(ofSize: 24, weight: .bold)
        resultLabel.textColor = .white
        resultLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        resultLabel.layer.cornerRadius = 10
        resultLabel.clipsToBounds = true
        view.addSubview(resultLabel)
    }
    
    private func updateResult(_ state: AbacusCellState) {
        switch state {
        case .upper:
            resultLabel.text = "Upper Bead"
            resultLabel.backgroundColor = UIColor.green.withAlphaComponent(0.8)
        case .lower:
            resultLabel.text = "Lower Bead"
            resultLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.8)
        case .empty:
            resultLabel.text = "Empty"
            resultLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.8)
        }
    }
}
```

## SwiftUI Integration

### Basic SwiftUI View

```swift
import SwiftUI
import AbacusKit

struct AbacusDetectionView: View {
    @StateObject private var viewModel = AbacusViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                if let state = viewModel.currentState {
                    StateDisplay(state: state)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .task {
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

struct StateDisplay: View {
    let state: AbacusCellState
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title)
            
            Text(stateName)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .foregroundColor(stateColor)
    }
    
    private var iconName: String {
        switch state {
        case .upper: return "arrow.up.circle.fill"
        case .lower: return "arrow.down.circle.fill"
        case .empty: return "circle"
        }
    }
    
    private var stateName: String {
        switch state {
        case .upper: return "Upper Bead"
        case .lower: return "Lower Bead"
        case .empty: return "Empty"
        }
    }
    
    private var stateColor: Color {
        switch state {
        case .upper: return .green
        case .lower: return .blue
        case .empty: return .gray
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

### ViewModel

```swift
@MainActor
class AbacusViewModel: ObservableObject {
    @Published var currentState: AbacusCellState?
    @Published var isLoading = false
    @Published var error: String?
    
    let captureSession = AVCaptureSession()
    private let cameraManager = CameraInferenceManager()
    
    func setup() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await cameraManager.setup()
            cameraManager.onDetection = { [weak self] state in
                self?.currentState = state
            }
            cameraManager.startCapture()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func cleanup() {
        cameraManager.stopCapture()
    }
}
```

## UIKit Integration

### Complete UIKit Implementation

```swift
import UIKit
import AbacusKit

class AbacusDetectorViewController: UIViewController {
    // UI Components
    private let cameraView = UIView()
    private let resultView = ResultOverlayView()
    private let controlsView = ControlsView()
    
    // Camera
    private let cameraManager = CameraInferenceManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupConstraints()
        setupCallbacks()
        
        Task {
            await initializeCamera()
        }
    }
    
    private func setupViews() {
        view.addSubview(cameraView)
        view.addSubview(resultView)
        view.addSubview(controlsView)
    }
    
    private func setupConstraints() {
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        resultView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            resultView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resultView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    private func setupCallbacks() {
        cameraManager.onDetection = { [weak self] state in
            self?.resultView.updateState(state)
        }
        
        controlsView.onCaptureToggle = { [weak self] isOn in
            if isOn {
                self?.cameraManager.startCapture()
            } else {
                self?.cameraManager.stopCapture()
            }
        }
    }
    
    private func initializeCamera() async {
        do {
            try await cameraManager.setup()
            cameraManager.startCapture()
        } catch {
            showError(error.localizedDescription)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

class ResultOverlayView: UIView {
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        layer.cornerRadius = 12
        
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func updateState(_ state: AbacusCellState) {
        UIView.animate(withDuration: 0.2) {
            switch state {
            case .upper:
                self.label.text = "Upper Bead"
                self.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
            case .lower:
                self.label.text = "Lower Bead"
                self.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            case .empty:
                self.label.text = "Empty"
                self.backgroundColor = UIColor.systemGray.withAlphaComponent(0.8)
            }
        }
    }
}

class ControlsView: UIView {
    private let toggleButton = UIButton(type: .system)
    var onCaptureToggle: ((Bool) -> Void)?
    private var isCapturing = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemBackground
        
        toggleButton.setTitle("Start", for: .normal)
        toggleButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        toggleButton.addTarget(self, action: #selector(toggleCapture), for: .touchUpInside)
        addSubview(toggleButton)
        
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toggleButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    @objc private func toggleCapture() {
        isCapturing.toggle()
        toggleButton.setTitle(isCapturing ? "Stop" : "Start", for: .normal)
        onCaptureToggle?(isCapturing)
    }
}
```

## Real-Time Processing

### Optimized Real-Time Pipeline

```swift
class OptimizedInferenceManager {
    private let engine = ExecuTorchInferenceEngine()
    private let bufferPool = PixelBufferPool()
    
    // Processing queue with high priority
    private let inferenceQueue = DispatchQueue(
        label: "inference",
        qos: .userInitiated
    )
    
    // Frame dropping
    private var isProcessing = false
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        // Drop frame if still processing
        guard !isProcessing else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        isProcessing = true
        
        Task {
            defer { isProcessing = false }
            
            do {
                let result = try await engine.predict(pixelBuffer: pixelBuffer)
                await handleResult(result)
            } catch {
                print("Inference error: \(error)")
            }
        }
    }
    
    @MainActor
    private func handleResult(_ result: ExecuTorchInferenceResult) {
        // Update UI
    }
}

class PixelBufferPool {
    private var pool: [CVPixelBuffer] = []
    private let lock = NSLock()
    
    func acquire() -> CVPixelBuffer? {
        lock.lock()
        defer { lock.unlock() }
        
        return pool.popLast() ?? createBuffer()
    }
    
    func release(_ buffer: CVPixelBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        if pool.count < 5 {
            pool.append(buffer)
        }
    }
    
    private func createBuffer() -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            224, 224,
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        return buffer
    }
}
```

## Error Handling Strategies

### Graceful Error Handling

```swift
class RobustInferenceManager {
    private let engine = ExecuTorchInferenceEngine()
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 5
    
    func safePredict(_ pixelBuffer: CVPixelBuffer) async -> ExecuTorchInferenceResult? {
        do {
            let result = try await engine.predict(pixelBuffer: pixelBuffer)
            consecutiveErrors = 0  // Reset on success
            return result
            
        } catch ExecuTorchInferenceError.modelNotLoaded {
            await handleModelNotLoaded()
            
        } catch ExecuTorchInferenceError.inferenceFailed(let message) {
            handleInferenceFailed(message)
            
        } catch {
            handleUnknownError(error)
        }
        
        return nil
    }
    
    private func handleModelNotLoaded() async {
        print("Model not loaded, attempting to reload...")
        do {
            try await reloadModel()
        } catch {
            print("Failed to reload model: \(error)")
        }
    }
    
    private func handleInferenceFailed(_ message: String) {
        consecutiveErrors += 1
        print("Inference failed (\(consecutiveErrors)/\(maxConsecutiveErrors)): \(message)")
        
        if consecutiveErrors >= maxConsecutiveErrors {
            print("Too many consecutive errors, restarting...")
            Task {
                await restartInferenceEngine()
            }
        }
    }
    
    private func handleUnknownError(_ error: Error) {
        print("Unknown error: \(error)")
    }
    
    private func reloadModel() async throws {
        guard let modelURL = Bundle.main.url(forResource: "abacus_model", withExtension: "pte") else {
            throw NSError(domain: "InferenceManager", code: -1)
        }
        try await engine.loadModel(at: modelURL)
    }
    
    private func restartInferenceEngine() async {
        consecutiveErrors = 0
        try? await reloadModel()
    }
}
```

## Testing

### Unit Testing

```swift
import XCTest
@testable import AbacusKit

class AbacusKitTests: XCTestCase {
    var engine: ExecuTorchInferenceEngine!
    
    override func setUp() async throws {
        engine = ExecuTorchInferenceEngine()
        
        let modelURL = Bundle(for: type(of: self))
            .url(forResource: "test_model", withExtension: "pte")!
        try await engine.loadModel(at: modelURL)
    }
    
    func testInference() async throws {
        let pixelBuffer = createTestPixelBuffer()
        let result = try await engine.predict(pixelBuffer: pixelBuffer)
        
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result.probabilities.reduce(0, +), 0.99)
        XCTAssertLessThan(result.probabilities.reduce(0, +), 1.01)
    }
    
    private func createTestPixelBuffer() -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            224, 224,
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        return buffer!
    }
}
```

---

**Next**: See [ARCHITECTURE.md](ARCHITECTURE.md) for system design details.
