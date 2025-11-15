#!/bin/bash

# AbacusKit ターゲット分離スクリプト
# Swift と Objective-C++/C++ を別ターゲットに分離します

set -e

echo "🚀 Starting AbacusKit target separation..."

# 1. AbacusKitBridge ディレクトリ構造を作成
echo "📁 Creating AbacusKitBridge directory structure..."
mkdir -p Sources/AbacusKitBridge/include

# 2. C++/Objective-C++ ファイルを移動
echo "📦 Moving C++/Objective-C++ files to AbacusKitBridge..."

# ヘッダーファイルを public headers に移動
if [ -f "Sources/AbacusKit/ML/TorchModule.h" ]; then
    mv Sources/AbacusKit/ML/TorchModule.h Sources/AbacusKitBridge/include/
    echo "  ✓ Moved TorchModule.h to include/"
fi

# 実装ファイルを移動
if [ -f "Sources/AbacusKit/ML/TorchModule.mm" ]; then
    mv Sources/AbacusKit/ML/TorchModule.mm Sources/AbacusKitBridge/
    echo "  ✓ Moved TorchModule.mm"
fi

if [ -f "Sources/AbacusKit/ML/TorchModule.hpp" ]; then
    mv Sources/AbacusKit/ML/TorchModule.hpp Sources/AbacusKitBridge/
    echo "  ✓ Moved TorchModule.hpp"
fi

if [ -f "Sources/AbacusKit/ML/TorchModule.cpp" ]; then
    mv Sources/AbacusKit/ML/TorchModule.cpp Sources/AbacusKitBridge/
    echo "  ✓ Moved TorchModule.cpp"
fi

# 3. Preprocessor.swift は AbacusKit に残す（Swift のみ）
echo "📝 Preprocessor.swift remains in AbacusKit/ML/"

# 4. .gitkeep ファイルを削除（不要になった）
echo "🧹 Cleaning up .gitkeep files..."
find Sources/AbacusKit -name ".gitkeep" -delete 2>/dev/null || true

echo ""
echo "✅ Migration complete!"
echo ""
echo "📂 New structure:"
echo "   Sources/"
echo "   ├── AbacusKit/              (Swift only)"
echo "   │   ├── Core/"
echo "   │   ├── ML/Preprocessor.swift"
echo "   │   ├── Networking/"
echo "   │   ├── Storage/"
echo "   │   ├── Domain/"
echo "   │   └── Utils/"
echo "   └── AbacusKitBridge/        (ObjC++/C++ only)"
echo "       ├── include/"
echo "       │   └── TorchModule.h"
echo "       ├── TorchModule.mm"
echo "       ├── TorchModule.hpp"
echo "       └── TorchModule.cpp"
echo ""
echo "🔧 Next steps:"
echo "   1. Run: swift build"
echo "   2. Verify no compilation errors"
echo "   3. Update your app's import statements if needed"
echo ""
