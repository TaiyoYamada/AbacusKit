# AbacusKit

AbacusKitは、iOS/iPadアプリケーション向けのリアルタイム推論SDKです。内側カメラからのCVPixelBuffer入力を受け取り、TorchScriptモデルを使用して推論を実行します。Amazon S3からのモデル自動更新機能を備え、オフライン動作もサポートします。

## Features

- 🚀 リアルタイムカメラフレーム推論
- 📦 Swift Package Manager対応
- 🔄 S3からの自動モデル更新
- 💾 ローカルモデルキャッシュによるオフライン動作
- ⚡️ C++による高速Tensor変換
- 🔒 Swift 6の厳格な並行性チェック対応

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+
- LibTorch 2.0.0+ (TorchScript runtime)

## Installation

### Swift Package Manager

`Package.swift`に以下を追加してください：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/AbacusKit.git", from: "1.0.0")
]
```

または、Xcodeで以下の手順で追加できます：

1. File > Add Package Dependencies...
2. リポジトリURLを入力: `https://github.com/your-org/AbacusKit.git`
3. バージョンを選択してプロジェクトに追加

### LibTorch Setup

AbacusKitはLibTorch（PyTorchのC++ライブラリ）を必要とします。以下の手順でセットアップしてください：

1. [PyTorch公式サイト](https://pytorch.org/)からiOS用LibTorchをダウンロード
2. ダウンロードしたフレームワークをプロジェクトにリンク
3. Build Settings > Other Linker Flags に `-all_load` を追加

詳細は`Docs/ARCHITECTURE.md`を参照してください。

## Usage

### Basic Setup

```swift
import AbacusKit
import AVFoundation

class CameraViewController: UIViewController {
    let abacus = Abacus.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task {
            do {
                // S3のURLとローカルストレージパスを設定
                let config = AbacusConfig(
                    versionURL: URL(string: "https://s3.amazonaws.com/your-bucket/version.json")!,
                    modelDirectoryURL: FileManager.default.urls(
                        for: .documentDirectory, 
                        in: .userDomainMask
                    )[0]
                )
                
                // SDKを初期化（モデルのダウンロードと読み込み）
                try await abacus.configure(config: config)
                print("AbacusKit configured successfully")
            } catch {
                print("Configuration failed: \(error)")
            }
        }
    }
}
```

### Performing Inference

```swift
func captureOutput(_ output: AVCaptureOutput, 
                  didOutput sampleBuffer: CMSampleBuffer, 
                  from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    Task {
        do {
            // CVPixelBufferから推論を実行
            let result = try await abacus.predict(pixelBuffer: pixelBuffer)
            
            print("Prediction: \(result.value)")
            print("Confidence: \(result.confidence)")
            print("Inference time: \(result.inferenceTimeMs)ms")
            
            // 結果をUIに反映
            await updateUI(with: result)
        } catch AbacusError.modelNotLoaded {
            print("Model not loaded. Call configure() first.")
        } catch AbacusError.preprocessingFailed(let reason) {
            print("Preprocessing failed: \(reason)")
        } catch {
            print("Inference failed: \(error)")
        }
    }
}
```

## Model Update Mechanism

AbacusKitは起動時に自動的にS3からモデルの更新をチェックします。

### S3 Setup

S3バケットに以下のファイルを配置してください：

1. **version.json** - モデルのバージョン情報

```json
{
  "version": 5,
  "model_url": "https://s3.amazonaws.com/your-bucket/models/model_v5.pt",
  "updated_at": "2025-11-15T10:30:00Z"
}
```

2. **model_vX.pt** - TorchScriptモデルファイル

### Update Flow

1. `configure()`呼び出し時に`version.json`を取得
2. ローカルキャッシュのバージョンと比較
3. 新しいバージョンがあれば自動的にダウンロード
4. ダウンロード完了後、新しいモデルを読み込み
5. 次回起動時はキャッシュされたモデルを使用（オフライン動作）

## CVPixelBuffer Input Requirements

AbacusKitは以下の形式のCVPixelBufferを受け付けます：

- **Pixel Format**: `kCVPixelFormatType_32BGRA` または `kCVPixelFormatType_32RGBA`
- **Color Space**: RGB
- **Dimensions**: モデルの入力サイズに応じて自動リサイズ（推奨: 224x224以上）

### Input Preparation Example

```swift
// AVCaptureSessionからの取得
func setupCamera() {
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    // ... session setup
}

// 手動でCVPixelBufferを作成する場合
func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
    let attrs = [
        kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
    ] as CFDictionary
    
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        Int(image.size.width),
        Int(image.size.height),
        kCVPixelFormatType_32BGRA,
        attrs,
        &pixelBuffer
    )
    
    guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
        return nil
    }
    
    // ... image data copy
    return buffer
}
```

## Error Handling

AbacusKitは以下のエラーを返す可能性があります：

| Error | Description | Solution |
|-------|-------------|----------|
| `modelNotLoaded` | モデルが読み込まれていない | `configure()`を先に呼び出してください |
| `downloadFailed` | モデルのダウンロードに失敗 | ネットワーク接続とS3 URLを確認してください |
| `invalidModel` | モデルファイルが破損または互換性なし | 正しいTorchScriptモデルを使用してください |
| `inferenceFailed` | 推論実行中にエラー発生 | 入力データとモデルの互換性を確認してください |
| `preprocessingFailed` | 入力の前処理に失敗 | CVPixelBufferの形式を確認してください |

## Troubleshooting

### Model not loading

**症状**: `configure()`が`invalidModel`エラーを返す

**解決策**:
- TorchScriptモデルがiOS用にエクスポートされているか確認
- モデルファイルが破損していないか確認（ファイルサイズをチェック）
- LibTorchのバージョンがモデルと互換性があるか確認

```python
# PyTorchでiOS用モデルをエクスポート
import torch

model = YourModel()
model.eval()

example_input = torch.rand(1, 3, 224, 224)
traced_model = torch.jit.trace(model, example_input)
traced_model.save("model.pt")
```

### Inference is slow

**症状**: `inferenceTimeMs`が期待より長い

**解決策**:
- モデルサイズを削減（量子化、プルーニング）
- 入力画像のサイズを小さくする
- メインスレッドで推論を実行していないか確認

```swift
// バックグラウンドで推論を実行
Task.detached(priority: .userInitiated) {
    let result = try await abacus.predict(pixelBuffer: pixelBuffer)
    await MainActor.run {
        updateUI(with: result)
    }
}
```

### Download fails on first launch

**症状**: `configure()`が`downloadFailed`エラーを返す

**解決策**:
- Info.plistに`NSAppTransportSecurity`設定を追加（HTTPSを使用している場合は不要）
- S3バケットのCORS設定を確認
- ネットワーク接続を確認

```xml
<!-- Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### Memory warnings during inference

**症状**: アプリがメモリ警告を受け取る

**解決策**:
- 推論後にCVPixelBufferを適切に解放
- 同時に複数の推論を実行しない
- モデルサイズを削減

```swift
// 推論レートを制限
private var lastInferenceTime = Date()
private let minInferenceInterval: TimeInterval = 0.1 // 100ms

func captureOutput(...) {
    guard Date().timeIntervalSince(lastInferenceTime) >= minInferenceInterval else {
        return
    }
    lastInferenceTime = Date()
    
    // ... perform inference
}
```

### CVPixelBuffer format error

**症状**: `preprocessingFailed`エラーが発生

**解決策**:
- サポートされているピクセルフォーマットを使用（BGRA/RGBA）
- CVPixelBufferがロックされていないか確認
- 画像サイズが有効か確認（0x0でない）

## Architecture

AbacusKitは6層のアーキテクチャで構成されています：

- **Core**: 公開API（Abacus、AbacusConfig、AbacusError）
- **ML**: TorchScriptモデル実行とTensor変換（C++/Objective-C++）
- **Networking**: S3からのバージョンチェックとモデルダウンロード
- **Storage**: ローカルファイル管理とモデルキャッシュ
- **Domain**: データモデル（PredictionResult、ModelVersionなど）
- **Utils**: ユーティリティ関数（画像処理、ロギング）

詳細は`Docs/ARCHITECTURE.md`を参照してください。

## Performance

典型的なパフォーマンス指標（iPhone 14 Pro、224x224入力）：

- 初回モデル読み込み: ~500ms
- 推論時間: ~20-50ms（モデルサイズに依存）
- メモリ使用量: ~50-100MB（モデルサイズに依存）

## License

[Your License Here]

## Contributing

[Contributing guidelines]

## Support

問題が発生した場合は、GitHubのIssuesで報告してください。
