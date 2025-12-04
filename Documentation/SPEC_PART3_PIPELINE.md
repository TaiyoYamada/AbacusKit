# Part 3: 前処理・推論パイプライン

## 3.1 OpenCV 前処理フロー詳細

### ステップ分解

```
Input: CVPixelBuffer (1920x1080, BGRA, 30-60 FPS)
    │
    ▼ Step 1: Format Conversion
┌─────────────────────────────────────────────────────┐
│ cv::cvtColor(input, bgr, cv::COLOR_BGRA2BGR)        │
│ • BGRA → BGR (24bit)                                │
│ • 処理時間: < 1ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 2: Resize (Maintain Aspect Ratio)
┌─────────────────────────────────────────────────────┐
│ longEdge = max(width, height)                       │
│ scale = 1280.0 / longEdge                           │
│ cv::resize(input, resized, Size(), scale, scale)    │
│ • 1920x1080 → 1280x720                              │
│ • 処理時間: < 2ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 3: Grayscale Conversion
┌─────────────────────────────────────────────────────┐
│ cv::cvtColor(resized, gray, cv::COLOR_BGR2GRAY)     │
│ • RGB → 8bit grayscale                              │
│ • 処理時間: < 0.5ms                                 │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 4: Contrast Enhancement (CLAHE)
┌─────────────────────────────────────────────────────┐
│ auto clahe = cv::createCLAHE(2.0, Size(8, 8))       │
│ clahe->apply(gray, enhanced)                        │
│ • 局所コントラスト強調                              │
│ • 照明条件のばらつきを吸収                          │
│ • 処理時間: < 3ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 5: Adaptive Thresholding
┌─────────────────────────────────────────────────────┐
│ cv::adaptiveThreshold(                              │
│     enhanced, binary,                               │
│     255,                                            │
│     cv::ADAPTIVE_THRESH_GAUSSIAN_C,                 │
│     cv::THRESH_BINARY,                              │
│     11,  // blockSize                               │
│     2    // C                                       │
│ )                                                   │
│ • そろばん玉を明確に分離                            │
│ • 処理時間: < 2ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 6: Morphological Operations
┌─────────────────────────────────────────────────────┐
│ auto kernel = cv::getStructuringElement(            │
│     cv::MORPH_RECT, Size(3, 3)                      │
│ )                                                   │
│ cv::morphologyEx(binary, cleaned, MORPH_CLOSE, k)   │
│ cv::morphologyEx(cleaned, cleaned, MORPH_OPEN, k)   │
│ • ノイズ除去・穴埋め                                │
│ • 処理時間: < 1ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 7: Contour Detection
┌─────────────────────────────────────────────────────┐
│ cv::findContours(                                   │
│     cleaned, contours, hierarchy,                   │
│     cv::RETR_EXTERNAL,                              │
│     cv::CHAIN_APPROX_SIMPLE                         │
│ )                                                   │
│ • 外側輪郭のみ抽出                                  │
│ • 処理時間: < 2ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 8: Abacus Frame Detection
┌─────────────────────────────────────────────────────┐
│ for (auto& contour : contours) {                    │
│     double area = cv::contourArea(contour)          │
│     if (area < minFrameArea) continue               │
│                                                     │
│     auto approx = cv::approxPolyDP(contour, eps)    │
│     if (approx.size() == 4) {                       │
│         // 四角形 → そろばんフレーム候補            │
│         auto rect = cv::minAreaRect(approx)         │
│         float aspectRatio = rect.width / rect.height│
│         if (isValidAbacusRatio(aspectRatio)) {      │
│             frameContour = contour                  │
│         }                                           │
│     }                                               │
│ }                                                   │
│ • 処理時間: < 2ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 9: Perspective Transformation
┌─────────────────────────────────────────────────────┐
│ // 4隅を検出・並べ替え                              │
│ auto corners = orderPoints(frameContour)            │
│                                                     │
│ // 変換先 (正規化されたそろばん)                    │
│ float dstWidth = 800, dstHeight = 200               │
│ std::vector<Point2f> dstCorners = {                 │
│     {0, 0}, {dstWidth, 0},                          │
│     {dstWidth, dstHeight}, {0, dstHeight}           │
│ }                                                   │
│                                                     │
│ auto M = cv::getPerspectiveTransform(corners, dst)  │
│ cv::warpPerspective(original, warped, M,            │
│     Size(dstWidth, dstHeight))                      │
│ • 処理時間: < 2ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 10: Column/Cell Segmentation
┌─────────────────────────────────────────────────────┐
│ // 桁分割 (そろばんの構造に基づく)                  │
│ int numDigits = 13  // 標準的なそろばん             │
│ int digitWidth = warpedWidth / numDigits            │
│                                                     │
│ for (int d = 0; d < numDigits; d++) {               │
│     Rect digitROI(d * digitWidth, 0,                │
│                   digitWidth, warpedHeight)         │
│                                                     │
│     // 上珠 (1セル) + 下珠 (4セル) に分割           │
│     extractUpperBead(warped(digitROI), cells)       │
│     extractLowerBeads(warped(digitROI), cells)      │
│ }                                                   │
│ • 処理時間: < 3ms                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 11: Cell Normalization for Inference
┌─────────────────────────────────────────────────────┐
│ for (auto& cell : cells) {                          │
│     // リサイズ to 224x224                          │
│     cv::resize(cell, resized, Size(224, 224))       │
│                                                     │
│     // BGR → RGB                                    │
│     cv::cvtColor(resized, rgb, COLOR_BGR2RGB)       │
│                                                     │
│     // float32 変換 + ImageNet正規化                │
│     rgb.convertTo(normalized, CV_32FC3, 1.0/255.0)  │
│     // mean: [0.485, 0.456, 0.406]                  │
│     // std : [0.229, 0.224, 0.225]                  │
│     normalize(normalized, mean, std)                │
│                                                     │
│     // HWC → CHW (PyTorch format)                   │
│     convertToCHW(normalized, tensorOutput)          │
│ }                                                   │
│ • 処理時間: < 5ms (13桁分)                          │
└─────────────────────────────────────────────────────┘
    │
    ▼ Output: float[N][3][224][224] (N = cell count)
```

### 処理時間サマリー

| ステップ | 処理時間 | 累積 |
|---------|---------|-----|
| Format Conversion | < 1ms | 1ms |
| Resize | < 2ms | 3ms |
| Grayscale | < 0.5ms | 3.5ms |
| CLAHE | < 3ms | 6.5ms |
| Adaptive Threshold | < 2ms | 8.5ms |
| Morphology | < 1ms | 9.5ms |
| Contour Detection | < 2ms | 11.5ms |
| Frame Detection | < 2ms | 13.5ms |
| Perspective Transform | < 2ms | 15.5ms |
| Cell Segmentation | < 3ms | 18.5ms |
| Cell Normalization | < 5ms | **23.5ms** |

**目標**: 30 FPS = 33.3ms/frame → 前処理に23.5ms使用可能 ✓

---

## 3.2 ExecuTorch 推論パイプライン

### モデル仕様

| 項目 | 値 |
|------|-----|
| 入力テンソル | `[1, 3, 224, 224]` float32 |
| 出力テンソル | `[1, 3]` float32 (logits) |
| クラス | 0: upper, 1: lower, 2: empty |
| 推論バックエンド | CoreML / MPS / XNNPACK |

### 推論フロー

```
Input: float[N][3][224][224] (N cells)
    │
    ▼ Step 1: Batch Strategy Decision
┌─────────────────────────────────────────────────────┐
│ if (N <= 4) {                                       │
│     // 少数セル → 個別推論                          │
│     return runSequential(cells)                     │
│ } else {                                            │
│     // 多数セル → バッチ推論                        │
│     return runBatched(cells, batchSize=8)           │
│ }                                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 2: Tensor Creation
┌─────────────────────────────────────────────────────┐
│ NSMutableData *tensorData = [[NSMutableData alloc]  │
│     initWithLength:batchSize * 3 * 224 * 224 *      │
│                    sizeof(float)]                   │
│                                                     │
│ memcpy(tensorData.mutableBytes, inputFloats,        │
│        tensorData.length)                           │
│                                                     │
│ ExecuTorchTensor *input = [[ExecuTorchTensor alloc] │
│     initWithData:tensorData                         │
│            shape:@[@(batchSize), @3, @224, @224]    │
│         dataType:ExecuTorchDataTypeFloat]           │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 3: Forward Execution
┌─────────────────────────────────────────────────────┐
│ ExecuTorchValue *inputVal =                         │
│     [ExecuTorchValue valueWithTensor:input]         │
│                                                     │
│ NSArray<ExecuTorchValue *> *outputs =               │
│     [module executeMethod:@"forward"                │
│                withInputs:@[inputVal]               │
│                     error:&error]                   │
│                                                     │
│ // CoreML バックエンド: ~3ms/cell                   │
│ // MPS バックエンド: ~5ms/cell                      │
│ // XNNPACK バックエンド: ~10ms/cell                 │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 4: Output Extraction
┌─────────────────────────────────────────────────────┐
│ ExecuTorchTensor *outputTensor = outputs[0].tensor  │
│                                                     │
│ [outputTensor bytesWithHandler:^(const void *ptr,   │
│                                  NSInteger count) { │
│     const float *logits = (const float *)ptr        │
│     // logits: [batchSize, 3]                       │
│ }]                                                  │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 5: Softmax + Argmax
┌─────────────────────────────────────────────────────┐
│ for (int i = 0; i < batchSize; i++) {               │
│     float* cellLogits = &logits[i * 3]              │
│                                                     │
│     // Softmax (numerically stable)                 │
│     float maxVal = max(cellLogits, 3)               │
│     float sum = 0                                   │
│     for (int c = 0; c < 3; c++) {                   │
│         probs[c] = exp(cellLogits[c] - maxVal)      │
│         sum += probs[c]                             │
│     }                                               │
│     for (int c = 0; c < 3; c++) {                   │
│         probs[c] /= sum                             │
│     }                                               │
│                                                     │
│     // Argmax                                       │
│     results[i].predictedClass = argmax(probs, 3)    │
│     results[i].probabilities = probs                │
│ }                                                   │
└─────────────────────────────────────────────────────┘
    │
    ▼ Output: [CellState, ...]
```

### 推論時間サマリー

| バックエンド | 単一セル | 13セル (1桁) | 65セル (5桁) |
|------------|---------|-------------|-------------|
| CoreML | 3ms | ~40ms | ~200ms |
| MPS | 5ms | ~65ms | ~325ms |
| XNNPACK | 10ms | ~130ms | ~650ms |

**目標**: 30 FPS で 13 セル → CoreML 使用時に達成可能 ✓

---

## 3.3 値解釈ロジック

### そろばんの構造

```
┌─────────────────────────────────────────┐
│  上珠 (天珠) - 1個 = 5                  │
│  ───────────────────────────────────    │
│  下珠 (地珠) - 4個 = 1, 1, 1, 1         │
└─────────────────────────────────────────┘

桁の値 = (上珠が下がっている ? 5 : 0) + (下がっている下珠の数)
範囲: 0 〜 9
```

### 解釈アルゴリズム

```swift
struct AbacusInterpreter {
    func interpret(cells: [CellState], digitCount: Int) -> Int {
        var value = 0
        var multiplier = 1
        
        // 右から左へ (1の位から)
        for digitIndex in stride(from: digitCount - 1, through: 0, by: -1) {
            let upperCell = cells[digitIndex * 5]  // 上珠
            let lowerCells = cells[(digitIndex * 5 + 1)..<(digitIndex * 5 + 5)]
            
            var digitValue = 0
            
            // 上珠: lower = 5点
            if upperCell == .lower {
                digitValue += 5
            }
            
            // 下珠: lower = 1点ずつ
            for cell in lowerCells {
                if cell == .lower {
                    digitValue += 1
                }
            }
            
            value += digitValue * multiplier
            multiplier *= 10
        }
        
        return value
    }
}
```
