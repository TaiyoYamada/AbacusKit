# AbacusKit

AbacusKitは、iOS/iPadアプリケーション向けのリアルタイム推論SDKです。内側カメラからのCVPixelBuffer入力を受け取り、TorchScriptモデルを使用して推論を実行します。Amazon S3からのモデル自動更新機能を備え、オフライン動作もサポートします。

## Features

- 🚀 リアルタイムカメラフレーム推論
- 📦 Swift Package Manager対応
- 🔄 S3からの自動モデル更新
- 💾 ローカルモデルキャッシュによるオフライン動作
- ⚡️ C++による高速Tensor変換
- 🔒 Swift 6の厳格な並行性チェック対応
- 🎯 Swift と C++ の明確な分離アーキテクチャ

## Requirements

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+
- LibTorch 2.0.0+ (TorchScript runtime)

## Architecture Overview

AbacusKitは2つのターゲットで構成されています：

### 1. AbacusKit (Swift)
Swift のみで実装されたメインSDKターゲット。アプリケーション開発者が直接使用するAPIを提供します。

**含まれるコンポーネント:**
- Core: 公開API（Abacus、AbacusConfig、AbacusError）
- ML: 入力検証（Preprocessor）
- Networking: S3通信（VersionChecker、ModelDownloader）
- Storage: ローカルストレージ（ModelCache、FileStorage）
- Domain: データモデル（PredictionResult、ModelVersion）
- Utils: ユーティリティ（Logger、ImageUtils）

### 2. AbacusKitBridge (Objective-C++/C++)
LibTorch との統合を担当するブリッジターゲット。C++17 を使用してTorchScriptモデルの実行とTensor変換を行います。

**含まれるコンポーネント:**
- TorchModule.h: Objective-C ブリッジヘッダー（public）
- TorchModule.mm: Objective-C++ 実装
- TorchModule.hpp: C++ ヘッダー
- TorchModule.cpp: C++ 実装（LibTorch統合）

### なぜターゲットを分離するのか？

Swift Package Manager は、Swift と Objective-C++/C++ を同一ターゲット内で混在させることをサポートしていません。そのため、以下のように分離しています：

- **AbacusKit**: Swift のみ → アプリ開発者が使用
- **AbacusKitBridge**: Objective-C++/C++ のみ → LibTorch との統合

この設計により、以下のメリットがあります：
- ✅ SPM のビルドエラーを回避
- ✅ 明確な責任分離
- ✅ Swift と C++ の境界が明確
- ✅ 保守性の向上

## Installation

### Swift Package Manager

\`Package.swift\`に以下を追加してください：

\`\`\`swift
dependencies: [
    .package(url: "https://github.com/your-org/AbacusKit.git", from: "1.0.0")
]
\`\`\`

または、Xcodeで以下の手順で追加できます：

1. File > Add Package Dependencies...
2. リポジトリURLを入力: \`https://github.com/your-org/AbacusKit.git\`
3. バージョンを選択してプロジェクトに追加

### LibTorch Setup

AbacusKitはLibTorch（PyTorchのC++ライブラリ）を必要とします。以下の手順でセットアップしてください：

#### Option 1: Manual Binary Integration

1. [PyTorch公式サイト](https://pytorch.org/mobile/ios/)からiOS用LibTorchをダウンロード
2. ダウンロードした \`libtorch_lite_interpreter.a\` をプロジェクトに追加
3. Xcode Build Settings で以下を設定：
   - **Other Linker Flags**: \`-force_load $(PROJECT_DIR)/path/to/libtorch_lite_interpreter.a\`
   - **Header Search Paths**: \`$(PROJECT_DIR)/path/to/libtorch/include\`
4. 必要なフレームワークをリンク：
   - Accelerate.framework
   - CoreML.framework
   - MetalPerformanceShaders.framework

#### Option 2: CocoaPods Integration

\`\`\`ruby
# Podfile
pod 'LibTorch-Lite', '~> 2.0.0'
\`\`\`

\`\`\`bash
pod install
\`\`\`

詳細は\`Docs/ARCHITECTURE.md\`を参照してください。

## Usage

### Basic Setup

\`\`\`swift
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
\`\`\`

### Performing Inference

\`\`\`swift
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
\`\`\`

## Inference Flow

推論は以下のフローで実行されます：

\`\`\`
┌─────────────────────────────────────────┐
│  1. Camera / Image Source               │
│     CVPixelBuffer (BGRA/RGBA)           │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  2. Abacus.predict() [Swift]            │
│     - Model loaded check                │
│     - Start time measurement            │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  3. Preprocessor.validate() [Swift]     │
│     - Pixel format validation           │
│     - Dimension check                   │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  4. TorchModuleBridge [ObjC++]          │
│     - Swift → ObjC++ boundary           │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  5. TorchModuleCpp [C++]                │
│     - CVPixelBuffer → Tensor            │
│     - model.forward(tensor)             │
│     - Tensor → vector<float>            │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│  6. Result → Swift                      │
│     - Parse output array                │
│     - Create PredictionResult           │
└─────────────────────────────────────────┘
\`\`\`

**Key Points:**
- 入力検証は Swift 層で実行（Preprocessor）
- Tensor 変換と推論は C++ 層で実行（パフォーマンス最適化）
- エラーは C++ → ObjC++ → Swift と伝播

## Model Update Mechanism

AbacusKitは起動時に自動的にS3からモデルの更新をチェックします。

### S3 Setup

S3バケットに以下のファイルを配置してください：

1. **version.json** - モデルのバージョン情報

\`\`\`json
{
  "version": 5,
  "model_url": "https://s3.amazonaws.com/your-bucket/models/model_v5.pt",
  "updated_at": "2025-11-15T10:30:00Z"
}
\`\`\`

2. **model_vX.pt** - TorchScriptモデルファイル

### Update Flow

1. \`configure()\`呼び出し時に\`version.json\`を取得
2. ローカルキャッシュのバージョンと比較
3. 新しいバージョンがあれば自動的にダウンロード
4. ダウンロード完了後、新しいモデルを読み込み
5. 次回起動時はキャッシュされたモデルを使用（オフライン動作）

## CVPixelBuffer Input Requirements

AbacusKitは以下の形式のCVPixelBufferを受け付けます：

- **Pixel Format**: \`kCVPixelFormatType_32BGRA\` または \`kCVPixelFormatType_32RGBA\`
- **Color Space**: RGB
- **Dimensions**: モデルの入力サイズに応じて自動リサイズ（推奨: 224x224以上）

### Input Preparation Example

\`\`\`swift
// AVCaptureSessionからの取得
func setupCamera() {
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    // ... session setup
}
\`\`\`

## Error Handling

AbacusKitは以下のエラーを返す可能性があります：

| Error | Description | Solution |
|-------|-------------|----------|
| \`modelNotLoaded\` | モデルが読み込まれていない | \`configure()\`を先に呼び出してください |
| \`downloadFailed\` | モデルのダウンロードに失敗 | ネットワーク接続とS3 URLを確認してください |
| \`invalidModel\` | モデルファイルが破損または互換性なし | 正しいTorchScriptモデルを使用してください |
| \`inferenceFailed\` | 推論実行中にエラー発生 | 入力データとモデルの互換性を確認してください |
| \`preprocessingFailed\` | 入力の前処理に失敗 | CVPixelBufferの形式を確認してください |

## Project Structure

\`\`\`
AbacusKit/
├── Package.swift                    # SPM manifest (2 targets)
├── Sources/
│   ├── AbacusKit/                   # Swift target
│   │   ├── Core/                    # Public API
│   │   │   ├── Abacus.swift
│   │   │   ├── AbacusConfig.swift
│   │   │   └── AbacusError.swift
│   │   ├── ML/                      # ML layer (Swift)
│   │   │   └── Preprocessor.swift
│   │   ├── Networking/              # S3 communication
│   │   │   ├── VersionChecker.swift
│   │   │   └── ModelDownloader.swift
│   │   ├── Storage/                 # Local storage
│   │   │   ├── ModelCache.swift
│   │   │   └── FileStorage.swift
│   │   ├── Domain/                  # Data models
│   │   │   ├── PredictionResult.swift
│   │   │   ├── ModelVersion.swift
│   │   │   └── AbacusMetadata.swift
│   │   └── Utils/                   # Utilities
│   │       ├── Logger.swift
│   │       └── ImageUtils.swift
│   └── AbacusKitBridge/             # ObjC++/C++ target
│       ├── include/                 # Public headers
│       │   └── TorchModule.h
│       ├── TorchModule.mm           # ObjC++ bridge
│       ├── TorchModule.hpp          # C++ header
│       └── TorchModule.cpp          # C++ implementation
└── Tests/
    └── AbacusKitTests/
\`\`\`

## Performance

典型的なパフォーマンス指標（iPhone 14 Pro、224x224入力）：

- 初回モデル読み込み: ~500ms
- 推論時間: ~20-50ms（モデルサイズに依存）
- メモリ使用量: ~50-100MB（モデルサイズに依存）

## Troubleshooting

### LibTorch linking error

**症状**: \`Undefined symbols for architecture arm64: "torch::..."\`

**解決策**:
- LibTorch バイナリが正しくリンクされているか確認
- Other Linker Flags に \`-force_load\` が設定されているか確認
- Header Search Paths が正しく設定されているか確認

### Model not loading

**症状**: \`configure()\`が\`invalidModel\`エラーを返す

**解決策**:
- TorchScriptモデルがiOS用にエクスポートされているか確認
- モデルファイルが破損していないか確認
- LibTorchのバージョンがモデルと互換性があるか確認

\`\`\`python
# PyTorchでiOS用モデルをエクスポート
import torch

model = YourModel()
model.eval()

example_input = torch.rand(1, 3, 224, 224)
traced_model = torch.jit.trace(model, example_input)
traced_model.save("model.pt")
\`\`\`

### Swift/C++ boundary errors

**症状**: ビルドエラー「Cannot use Objective-C++ with Swift in the same target」

**解決策**:
- 最新の Package.swift を使用していることを確認
- AbacusKit と AbacusKitBridge が正しく分離されているか確認
- \`swift build\` でクリーンビルドを実行

## Documentation

詳細なアーキテクチャドキュメントは以下を参照してください：

- [ARCHITECTURE.md](Docs/ARCHITECTURE.md) - 内部設計と実装詳細

## License

[Your License Here]

## Contributing

[Contributing guidelines]

## Support

問題が発生した場合は、GitHubのIssuesで報告してください。
