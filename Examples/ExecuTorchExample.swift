import Foundation
import CoreVideo
import AbacusKit

/// ExecuTorch を使った推論の使用例
@main
struct ExecuTorchExample {
    static func main() async throws {
        print("🚀 ExecuTorch Inference Example")
        print("================================\n")
        
        // 1. エンジンを初期化
        let engine = ExecuTorchInferenceEngine()
        print("✅ Engine initialized")
        
        // 2. モデルをロード
        let modelPath = URL(fileURLWithPath: "Model/abacus.pte")
        
        do {
            try await engine.loadModel(at: modelPath)
            print("✅ Model loaded from: \(modelPath.path)\n")
        } catch {
            print("❌ Failed to load model: \(error)")
            return
        }
        
        // 3. テスト用の PixelBuffer を作成
        let pixelBuffer = try createTestPixelBuffer()
        print("✅ Created test pixel buffer (224x224)\n")
        
        // 4. 推論を実行
        print("🔄 Running inference...")
        
        do {
            let result = try await engine.predict(pixelBuffer: pixelBuffer)
            
            print("\n📊 Inference Results:")
            print("   Predicted State: \(result.predictedState)")
            print("   Probabilities:")
            print("     - Upper: \(String(format: "%.2f%%", result.probabilities[0] * 100))")
            print("     - Lower: \(String(format: "%.2f%%", result.probabilities[1] * 100))")
            print("     - Empty: \(String(format: "%.2f%%", result.probabilities[2] * 100))")
            print("   Inference Time: \(String(format: "%.2f", result.inferenceTimeMs))ms")
            
        } catch {
            print("❌ Inference failed: \(error)")
        }
        
        print("\n✅ Example completed!")
    }
    
    /// テスト用の PixelBuffer を作成
    static func createTestPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            224,
            224,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw NSError(
                domain: "ExampleError",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create pixel buffer"]
            )
        }
        
        // ダミーデータで埋める（実際のアプリでは画像データを使用）
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            
            // グレーで埋める
            memset(baseAddress, 128, bytesPerRow * height)
        }
        
        return buffer
    }
}
