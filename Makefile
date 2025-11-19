# Makefile for AbacusKit

.PHONY: build test clean mocks help export-model

# デフォルトターゲット
help:
	@echo "AbacusKit - Available commands:"
	@echo "  make build         - Build the project"
	@echo "  make test          - Run all tests"
	@echo "  make mocks         - Generate mocks with Cuckoo"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make docs          - Generate documentation"
	@echo "  make export-model  - Convert TorchScript to ExecuTorch (.pt → .pte)"

# プロジェクトをビルド
build:
	swift build

# テストを実行
test:
	swift test

# Cuckooでモックを生成
mocks:
	@echo "Generating mocks with Cuckoo..."
	@mkdir -p Tests/AbacusKitTests/Generated
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
	@echo "Mocks generated successfully!"

# ビルド成果物をクリーン
clean:
	swift package clean
	rm -rf .build
	rm -rf Tests/AbacusKitTests/Generated

# ドキュメントを生成
docs:
	swift package generate-documentation

# リリースビルド
release:
	swift build -c release

# すべてのターゲット（ビルド + テスト）
all: build test

# 開発環境のセットアップ
setup:
	@echo "Setting up development environment..."
	swift package resolve
	@echo "Setup complete!"

# モデルを ExecuTorch 形式に変換
export-model:
	@echo "Converting TorchScript model to ExecuTorch format..."
	@if [ ! -f "Model/abacus.pt" ]; then \
		echo "❌ Error: Model/abacus.pt not found"; \
		exit 1; \
	fi
	python3 Scripts/export_to_executorch.py \
		--input Model/abacus.pt \
		--output Model/abacus.pte
	@echo "✅ Model exported successfully!"
