# AbacusKit xcframework Setup Guide

## Prerequisites

- Xcode 15.0+
- macOS 14+
- Python 3.10+ (for ExecuTorch build)

---

## 1. Obtaining ExecuTorch xcframework

### Method A: Get from SwiftPM Branch (Recommended)

```bash
git clone -b swiftpm-1.0.1 https://github.com/pytorch/executorch.git executorch-swiftpm
cd executorch-swiftpm

# Frameworks directory contains xcframeworks
ls Frameworks/
# → executorch.xcframework, backend_coreml.xcframework, etc.
```

### Method B: Build from Source

```bash
git clone https://github.com/pytorch/executorch.git
cd executorch
git checkout v1.0.1

# Install dependencies
pip install cmake
./install_requirements.sh

# Build xcframework for iOS
./build/build_apple_frameworks.sh --Release

# Check output
ls cmake-out/
# → executorch.xcframework
```

---

## 2. Obtaining OpenCV xcframework

```bash
# Download from official release
curl -LO https://github.com/opencv/opencv/releases/download/4.12.0/opencv-4.12.0-ios-framework.zip
unzip opencv-4.12.0-ios-framework.zip

# opencv2.framework will be extracted
# -> If conversion to xcframework format is needed:
xcodebuild -create-xcframework \
    -framework opencv2.framework \
    -output opencv2.xcframework
```

---

## 3. Compress xcframeworks to zip

```bash
# ExecuTorch
zip -r ExecuTorch.xcframework.zip executorch.xcframework

# OpenCV
zip -r opencv2.xcframework.zip opencv2.xcframework
```

---

## 4. Upload to GitHub Releases

1. Go to https://github.com/TaiyoYamada/AbacusKit/releases
2. Click "Draft a new release"
3. Create tag: `v1.0.0`
4. Title: `AbacusKit v1.0.0`
5. Attach the following files:
   - `ExecuTorch.xcframework.zip`
   - `opencv2.xcframework.zip`
6. Click "Publish release"

---

## 5. Calculate checksum and Update Package.swift

```bash
# Calculate checksums
swift package compute-checksum ExecuTorch.xcframework.zip
# Output example: abc123def456...

swift package compute-checksum opencv2.xcframework.zip
# Output example: 789xyz...
```

Update the following lines in Package.swift:

```swift
let execuTorchChecksum = "abc123def456..."  // ← Replace with actual value
let opencvChecksum = "789xyz..."            // ← Replace with actual value
```

---

## 6. Verify

```bash
cd /path/to/AbacusKit
swift build
swift test
```

---

## Troubleshooting

### Checksum Mismatch

```
error: checksum of downloaded artifact does not match
```

→ Re-download the zip file and recalculate the checksum.

### ExecuTorch Build Error

→ Verify that Python 3.10+ and CMake are properly installed.

### OpenCV Symbol Not Found

→ Verify that opencv2.xcframework is in the correct format.
