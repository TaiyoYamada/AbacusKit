# Part 3: Preprocessing and Inference Pipeline

## 3.1 OpenCV Preprocessing Flow Details

### Step Breakdown

```
Input: CVPixelBuffer (1920x1080, BGRA, 30-60 FPS)
    │
    ▼ Step 1: Format Conversion
┌─────────────────────────────────────────────────────┐
│ cv::cvtColor(input, bgr, cv::COLOR_BGRA2BGR)        │
│ • BGRA → BGR (24bit)                                │
│ • Processing time: < 1ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 2: Resize (Maintain Aspect Ratio)
┌─────────────────────────────────────────────────────┐
│ longEdge = max(width, height)                       │
│ scale = 1280.0 / longEdge                           │
│ cv::resize(input, resized, Size(), scale, scale)    │
│ • 1920x1080 → 1280x720                              │
│ • Processing time: < 2ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 3: Grayscale Conversion
┌─────────────────────────────────────────────────────┐
│ cv::cvtColor(resized, gray, cv::COLOR_BGR2GRAY)     │
│ • RGB → 8bit grayscale                              │
│ • Processing time: < 0.5ms                          │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 4: Contrast Enhancement (CLAHE)
┌─────────────────────────────────────────────────────┐
│ auto clahe = cv::createCLAHE(2.0, Size(8, 8))       │
│ clahe->apply(gray, enhanced)                        │
│ • Local contrast enhancement                        │
│ • Absorbs lighting condition variations             │
│ • Processing time: < 3ms                            │
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
│ • Clearly separates soroban beads                   │
│ • Processing time: < 2ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 6: Morphological Operations
┌─────────────────────────────────────────────────────┐
│ auto kernel = cv::getStructuringElement(            │
│     cv::MORPH_RECT, Size(3, 3)                      │
│ )                                                   │
│ cv::morphologyEx(binary, cleaned, MORPH_CLOSE, k)   │
│ cv::morphologyEx(cleaned, cleaned, MORPH_OPEN, k)   │
│ • Noise removal and hole filling                    │
│ • Processing time: < 1ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 7: Contour Detection
┌─────────────────────────────────────────────────────┐
│ cv::findContours(                                   │
│     cleaned, contours, hierarchy,                   │
│     cv::RETR_EXTERNAL,                              │
│     cv::CHAIN_APPROX_SIMPLE                         │
│ )                                                   │
│ • Extract only outer contours                       │
│ • Processing time: < 2ms                            │
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
│         // Quadrilateral → soroban frame candidate  │
│         auto rect = cv::minAreaRect(approx)         │
│         float aspectRatio = rect.width / rect.height│
│         if (isValidAbacusRatio(aspectRatio)) {      │
│             frameContour = contour                  │
│         }                                           │
│     }                                               │
│ }                                                   │
│ • Processing time: < 2ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 9: Perspective Transformation
┌─────────────────────────────────────────────────────┐
│ // Detect and sort 4 corners                        │
│ auto corners = orderPoints(frameContour)            │
│                                                     │
│ // Destination (normalized soroban)                 │
│ float dstWidth = 800, dstHeight = 200               │
│ std::vector<Point2f> dstCorners = {                 │
│     {0, 0}, {dstWidth, 0},                          │
│     {dstWidth, dstHeight}, {0, dstHeight}           │
│ }                                                   │
│                                                     │
│ auto M = cv::getPerspectiveTransform(corners, dst)  │
│ cv::warpPerspective(original, warped, M,            │
│     Size(dstWidth, dstHeight))                      │
│ • Processing time: < 2ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 10: Column/Cell Segmentation
┌─────────────────────────────────────────────────────┐
│ // Digit division (based on soroban structure)      │
│ int numDigits = 13  // Standard soroban             │
│ int digitWidth = warpedWidth / numDigits            │
│                                                     │
│ for (int d = 0; d < numDigits; d++) {               │
│     Rect digitROI(d * digitWidth, 0,                │
│                   digitWidth, warpedHeight)         │
│                                                     │
│     // Split into upper bead (1 cell) + lower beads (4 cells) │
│     extractUpperBead(warped(digitROI), cells)       │
│     extractLowerBeads(warped(digitROI), cells)      │
│ }                                                   │
│ • Processing time: < 3ms                            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Step 11: Cell Normalization for Inference
┌─────────────────────────────────────────────────────┐
│ for (auto& cell : cells) {                          │
│     // Resize to 224x224                            │
│     cv::resize(cell, resized, Size(224, 224))       │
│                                                     │
│     // BGR → RGB                                    │
│     cv::cvtColor(resized, rgb, COLOR_BGR2RGB)       │
│                                                     │
│     // float32 conversion + ImageNet normalization  │
│     rgb.convertTo(normalized, CV_32FC3, 1.0/255.0)  │
│     // mean: [0.485, 0.456, 0.406]                  │
│     // std : [0.229, 0.224, 0.225]                  │
│     normalize(normalized, mean, std)                │
│                                                     │
│     // HWC → CHW (PyTorch format)                   │
│     convertToCHW(normalized, tensorOutput)          │
│ }                                                   │
│ • Processing time: < 5ms (for 13 digits)            │
└─────────────────────────────────────────────────────┘
    │
    ▼ Output: float[N][3][224][224] (N = cell count)
```

### Processing Time Summary

| Step | Processing Time | Cumulative |
|------|-----------------|------------|
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

**Target**: 30 FPS = 33.3ms/frame → 23.5ms available for preprocessing ✓

---

## 3.2 ExecuTorch Inference Pipeline

### Model Specification

| Item | Value |
|------|-------|
| Input Tensor | `[1, 3, 224, 224]` float32 |
| Output Tensor | `[1, 3]` float32 (logits) |
| Classes | 0: upper, 1: lower, 2: empty |
| Inference Backend | CoreML / MPS / XNNPACK |

### Inference Flow

```
Input: float[N][3][224][224] (N cells)
    │
    ▼ Step 1: Batch Strategy Decision
┌─────────────────────────────────────────────────────┐
│ if (N <= 4) {                                       │
│     // Few cells → individual inference             │
│     return runSequential(cells)                     │
│ } else {                                            │
│     // Many cells → batch inference                 │
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
│ // CoreML backend: ~3ms/cell                        │
│ // MPS backend: ~5ms/cell                           │
│ // XNNPACK backend: ~10ms/cell                      │
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

### Inference Time Summary

| Backend | Single Cell | 13 Cells (1 digit) | 65 Cells (5 digits) |
|---------|-------------|--------------------|--------------------|
| CoreML | 3ms | ~40ms | ~200ms |
| MPS | 5ms | ~65ms | ~325ms |
| XNNPACK | 10ms | ~130ms | ~650ms |

**Target**: 30 FPS with 13 cells → Achievable with CoreML ✓

---

## 3.3 Value Interpretation Logic

### Soroban Structure

```
┌─────────────────────────────────────────┐
│  Upper bead (heaven bead) - 1 unit = 5  │
│  ───────────────────────────────────    │
│  Lower beads (earth beads) - 4 units = 1, 1, 1, 1 │
└─────────────────────────────────────────┘

Digit value = (upper bead is down ? 5 : 0) + (number of lower beads that are down)
Range: 0 - 9
```

### Interpretation Algorithm

```swift
struct AbacusInterpreter {
    func interpret(cells: [CellState], digitCount: Int) -> Int {
        var value = 0
        var multiplier = 1
        
        // Right to left (from ones place)
        for digitIndex in stride(from: digitCount - 1, through: 0, by: -1) {
            let upperCell = cells[digitIndex * 5]  // Upper bead
            let lowerCells = cells[(digitIndex * 5 + 1)..<(digitIndex * 5 + 5)]
            
            var digitValue = 0
            
            // Upper bead: lower = 5 points
            if upperCell == .lower {
                digitValue += 5
            }
            
            // Lower beads: lower = 1 point each
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
