#!/usr/bin/env python3
"""
TorchScript モデルを ExecuTorch (.pte) 形式に変換するスクリプト

使用方法:
    python export_to_executorch.py --input abacus.pt --output abacus.pte

必要なパッケージ:
    pip install torch torchvision executorch
"""

import argparse
import torch
from torch.export import export
from executorch.exir import to_edge


def export_to_executorch(input_path: str, output_path: str):
    """
    TorchScript モデルを ExecuTorch 形式に変換する
    
    Args:
        input_path: 入力モデルのパス (.pt)
        output_path: 出力モデルのパス (.pte)
    """
    print(f"Loading model from {input_path}...")
    
    # TorchScript モデルをロード
    model = torch.jit.load(input_path)
    model.eval()
    
    print("Converting to ExecuTorch format...")
    
    # ダミー入力を作成（224x224 RGB）
    dummy_input = torch.randn(1, 3, 224, 224)
    
    # torch.export を使ってエクスポート
    exported_program = export(model, (dummy_input,))
    
    # ExecuTorch の Edge IR に変換
    edge_program = to_edge(exported_program)
    
    # ExecuTorch プログラムに変換
    executorch_program = edge_program.to_executorch()
    
    # .pte ファイルとして保存
    print(f"Saving ExecuTorch model to {output_path}...")
    with open(output_path, "wb") as f:
        f.write(executorch_program.buffer)
    
    print("✅ Conversion completed successfully!")
    print(f"   Input:  {input_path}")
    print(f"   Output: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Convert TorchScript model to ExecuTorch format"
    )
    parser.add_argument(
        "--input",
        type=str,
        required=True,
        help="Path to input TorchScript model (.pt)"
    )
    parser.add_argument(
        "--output",
        type=str,
        required=True,
        help="Path to output ExecuTorch model (.pte)"
    )
    
    args = parser.parse_args()
    
    try:
        export_to_executorch(args.input, args.output)
    except Exception as e:
        print(f"❌ Error during conversion: {e}")
        raise


if __name__ == "__main__":
    main()
