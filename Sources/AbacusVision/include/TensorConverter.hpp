#ifndef TENSOR_CONVERTER_HPP
#define TENSOR_CONVERTER_HPP

#include "VisionTypes.hpp"
#include "ImagePreprocessor.hpp" // OpenCV stubs if needed
#include <vector>

namespace abacus {

/// テンソル変換クラス
/// 
/// OpenCV Mat を ExecuTorch 用のテンソル形式に変換する。
class TensorConverter {
public:
    TensorConverter();
    explicit TensorConverter(const PreprocessingConfig& config);
    ~TensorConverter();
    
    void setConfig(const PreprocessingConfig& config) { config_ = config; }
    
    /// 単一セルをテンソルに変換
    /// @param cell セル画像 (BGR)
    /// @param tensor 出力テンソル
    /// @return エラーコード
    VisionError convertCell(const cv::Mat& cell, CellTensor& tensor);
    
    /// 複数セルをバッチテンソルに変換
    /// @param cells セル画像のリスト
    /// @param batch 出力バッチテンソル
    /// @return エラーコード
    VisionError convertBatch(const std::vector<cv::Mat>& cells, BatchTensor& batch);
    
    /// テンソルメモリを解放
    static void freeTensor(CellTensor& tensor);
    static void freeBatch(BatchTensor& batch);
    
private:
    PreprocessingConfig config_;
    
    /// 画像を正規化してテンソルに変換
    void normalize(const cv::Mat& input, float* output);
};

} // namespace abacus

#endif // TENSOR_CONVERTER_HPP
