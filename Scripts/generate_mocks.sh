#!/bin/bash

# Cuckooモック生成スクリプト

set -e

echo "Generating mocks with Cuckoo..."

# 出力ディレクトリを作成
mkdir -p Tests/AbacusKitTests/Generated

# Cuckooでモックを生成
swift run cuckoo generate \
    --testable AbacusKit \
    --output Tests/AbacusKitTests/Generated/GeneratedMocks.swift \
    Sources/AbacusKit/ML/ModelManager.swift \
    Sources/AbacusKit/ML/ModelUpdater.swift \
    Sources/AbacusKit/ML/PreprocessorProtocol.swift \
    Sources/AbacusKit/Networking/ModelVersionAPI.swift \
    Sources/AbacusKit/Networking/S3Downloader.swift \
    Sources/AbacusKit/Storage/FileStorageProtocol.swift \
    Sources/AbacusKit/Storage/ModelCacheProtocol.swift

echo "Mocks generated successfully"
echo "Output: Tests/AbacusKitTests/Generated/GeneratedMocks.swift"
