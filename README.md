# AbacusKit

AbacusKitは、iOS/iPadアプリケーション向けのリアルタイム推論SDKです。内側カメラからのCVPixelBuffer入力を受け取り、TorchScriptモデルを使用して推論を実行します。Amazon S3からのモデル自動更新機能を備え、オフライン動作もサポートします。

## Features

- 🚀 リアルタイムカメラフレーム推論
- 📦 Swift Package Manager対応
- 🔄 S3からの自動モデル更新
- 💾 ローカルモデルキャッシュによるオフライン動作
- ⚡️ C++による高速Tensor変換
- 🔒 Swift 6の厳格な並行性チェック対応


ents

- Swift 6.0+
- Xcode 16.0+
- iOS 17.0+


ew

す：

Swift)
Swift のみます。

**含まれるコンポーネント:**
-
- Mr）
der）
- Storage: ローカルストレージ（Mo
sion）
- Utils: ユーティリティ（Logger、ImageUtils）

### 2. AbacusKitBridge
。

:**
- TorchModule.h: Objective-C ブリッジヘッダー（public）
++ 実装
- TorchModule.hpp: C++ ヘッダー
- TorchModule.cpp: C++ 実装（Libch統合）

離するのか？

ます：


- **AbacusKitBr

この設計により、ります：
- ✅ SPM のビルドエラーを
- ✅ 明確な責任分離
C++ の境界が明確
- ✅ 保守性の向上

## I

### Swift Package Manager

`Package.swiftてください：

```swift
dependencies: [
    .package(url: "https://github.com/your-org/AbacusKit.git", from: "1.0.0")
]
```

または、Xcodeで以下の手順で追加できます：

1. File > Add Pas...
2. リポジトリURLを入力: `https://github.com/your-or`
3. バージョンを選択してプロジェクトに追加

### LibTorch Setup

AbacusKitはLib

#### n

1. ード
トに追加
3. Xcode Build Settings 下を設定：
reter.a`
   - **He`
4. 必要なフレームワークをリンク：
   - Accelerate.framework
   - CoreML.framework
   - MetalPerformanceShaders.framework

#### Optio

```ruby
# Podfile
pod 'LibTorc0'
```

```bash
pod install
```

詳細は`Docs/ARCHITECTURE.md`を参照してください。

## Usage

### Basic Setup

```swift
import
i

ler {
    let abacus = Abacus.shared

    override func viewDidLoad() {
)
        

            do {
設定
                let config = Abac

       .urls(
 , 
               mainMask
                    )[0]
                )
       
   込み）
)
                print("AbacusKit config)
tch {
               rror)")

        }
    }
}
```

nference


func captureOutput(_ output: AVCapturtput, 
uffer, 
                  from connection: AVCaptureConnection) {
    guard let pixelBuf}
    
{
        do {
実行
        r)
            
            print("P
            print("Confidence: \(result.confiden)
            print("Inference times")
            
     
            await updateesult)
 
)
        } catch AbacusErro) {
            print("Preprocessing failed: \(reason)")
        } catch {
            print("Inference failed: \(error)")
        }
    }
}
```

## Inference Flow

推論は以下のフローで実行されます：

```
┌───────────────────
│  1. │
│     │
└─────────────────────────────────────────┘
                 ↓
┌────┐
│  2
│     - Model loaded check       │
│     - Start tim
└───────┘
     ↓
─────┐
│  3. Preprocesso│
        │
│     - Dimension check      │

                 ↓
┌─────────────────────────────────
│  4. TorchModuleBridge [ObjC++]          │
│     - Swift → ObjC++ boundary           │
└─────────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│
│     - CVPixelBuf│

│     - Tensor → vect     │
─┘
                 ↓
──────┐
│  6. Re   │
│     - Parse output array          
│     - Create PredictionResult   │
└────────────────────────────────┘
`

**Key Points:**
- 入力検証は Swifrocessor）
）
- エラーは C++ → ObjC++wift と伝播

hanism

AbacusKitは起動時に自動的にS3からモデルの更新をチェックします。

###etup

S3バケットに以下のファイルを配置してください：

1. **version.json** - モデルのバージョン情

```json
{
  "version": 5,
  "model_url": "https:/,
00Z"
}
```

2. **model_vX.pt** - TorchScriptモデルファイル

### Update Flow

1を取得
2. ンと比較
ード
4. ダウンロード完了後、新しいモデルを読み込み


ents

AbacusKitは以下の形式のCVPixelBufferを受け付けます：

- **Pixel ForA`
GB
- **Di4以上）

### Input Preparation Example

```swift
// AVCaptureらの取得
func semera() {
   
ings = [
        kCVPixelBufferPixelFormatTyp32BGRA
    ]
    // ... session setup

```

## Error Handling

能性があります：

| Error | Dtion |
|-------|-------------|----------|
| `modelNotLoaded` | モデルが読み込まれていない | `configure()`を先に呼び出してくださ
 |
| `invalidModel` | モデルファイ |
| `inferenceFailed` | 推論実行中にエラー発生 | 入力データとモデルの互換性を確認してください |
| `preprocessi |

## Project Structure

```
A/
├──targets)
urces/
│   ├── AbacusKit/            t
Public API
│   │   │   ├── Abacus.swift
t
│   │   ift
│   │   ├── ML/                    wift)
│   │   │   └── Preprocessor
│   │   ├── Networkinion
wift
│   │   │   └──.swift

│   │   │   ├── ModelCache.swift
wift
│   │   ├── Domain/                  # Data models
│   │   │   ├── PredictionResult.swift
│   │   │   ├── ModelVersion.swift
│   │   │   └── AbacusMetadata.swift
│   │   └── Utils/                   # Utilities
│   │       ├── Logger.swift

│   └── AbacusKitBridge/           et
ders
│       │   └─h
e
│       ├── TorchModule.hpp          # 
tion
└── Tests/
    └── AbacusKitTests/
```

## Performnce

典型的なパフォーマンス指標（iPhon4入力）：

- 初回モデル読み込み: ~5ms
デルサイズに依存）
- メモリ使用量: ~50-100MB（モデルサイズに依存）

## Trouble

### LibTorch linking error

。告してくださいubのIssuesで報GitH場合は、

問題が発生した Supports]

##delinebuting guintriting

[Co# Contribu
#e Here]
our Licens
[Yicense
詳細

## L内部設計と実装TURE.md) - ITECRCHd](Docs/AHITECTURE.m
- [ARC照してください：
ントは以下を参ーキテクチャドキュメ
詳細なアentation

## Documンビルドを実行
でクリーft build` 
- `swi確認れているかge が正しく分離さBridcusKitbausKit と A Abacとを確認
-るこft を使用していckage.swi*:
- 最新の Pa
**解決策*rget」
 same tahewift in tith Se-C++ wtivjec Ob「Cannot use: ビルドエラー症状**rrors

** e boundaryift/C++Sw

### `
``del.pt")e("moodel.sav)
traced_minputexample_, ace(model.tr= torch.jitel d_mod224)
trace 3, 224, nd(1, = torch.rae_inputplexam()

al
model.evYourModel()el = h

modtorcト
import OS用モデルをエクスポー# PyTorchでihon
認

```pytモデルと互換性があるか確ョンがchのバージbTor
- Liていないか確認 モデルファイルが破損し
-ートされているか確認iOS用にエクスポriptモデルがorchSc*:
- T
**解決策*el`エラーを返す
が`invalidModnfigure()`**症状**: `coing

ot loadodel nか確認

### Mているs が正しく設定されearch PathHeader S確認
- d` が設定されているかloae_`-forcgs に  Flar Linker- Otheされているか確認
リンクrch バイナリが正しくLibTo*解決策**:
- .."`

*"torch::.ture arm64:  architecmbols forsyd define `Un**:症状
**