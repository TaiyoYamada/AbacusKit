#ifndef ABACUS_VISION_HPP
#define ABACUS_VISION_HPP

#include "VisionTypes.hpp"
#include "ImagePreprocessor.hpp"
#include "SorobanDetector.hpp"
#include "TensorConverter.hpp"
#include <memory>
#include <chrono>

namespace abacus {

/// AbacusVision メインクラス
/// 
/// 画像からそろばんを検出し、推論用テンソルを生成する
/// 統合された前処理パイプライン。
/// 
/// Swift 6.2 C++ Interop 対応。
class AbacusVision {
public:
    AbacusVision();
    explicit AbacusVision(const PreprocessingConfig& config);
    ~AbacusVision();
    
    // コピー禁止、ムーブ可能
    AbacusVision(const AbacusVision&) = delete;
    AbacusVision& operator=(const AbacusVision&) = delete;
    AbacusVision(AbacusVision&&) noexcept = default;
    AbacusVision& operator=(AbacusVision&&) noexcept = default;
    
    /// 設定を更新
    void setConfig(const PreprocessingConfig& config);
    const PreprocessingConfig& getConfig() const { return config_; }
    
    /// 検出パラメータを更新
    void setDetectionParams(const SorobanDetector::DetectionParams& params);
    
    /// CVPixelBuffer から完全な抽出を実行
    /// @param pixelBuffer CVPixelBufferRef
    /// @return 抽出結果
    ExtractionResult processPixelBuffer(const void* pixelBuffer);
    
    /// cv::Mat から完全な抽出を実行
    /// @param image 入力画像 (BGR)
    /// @return 抽出結果
    ExtractionResult processImage(const cv::Mat& image);
    
    /// 最後のフレーム検出結果を取得
    const FrameDetectionResult& getLastFrameResult() const { return lastFrame_; }
    
    /// デバッグ用：検出結果を描画した画像を取得
    cv::Mat drawDebugOverlay(const cv::Mat& original, const ExtractionResult& result);
    
private:
    PreprocessingConfig config_;
    std::unique_ptr<ImagePreprocessor> preprocessor_;
    std::unique_ptr<SorobanDetector> detector_;
    std::unique_ptr<TensorConverter> converter_;
    
    FrameDetectionResult lastFrame_;
    
    /// 内部処理
    ExtractionResult processInternal(const cv::Mat& image);
};

// ============================================================
// C インターフェース（Swift C Interop 用）
// ============================================================

extern "C" {

/// AbacusVision インスタンスを作成
void* abacus_vision_create(void);

/// AbacusVision インスタンスを破棄
void abacus_vision_destroy(void* instance);

/// CVPixelBuffer を処理
/// @param instance AbacusVision インスタンス
/// @param pixelBuffer CVPixelBufferRef
/// @param result 結果を格納する構造体
/// @return エラーコード
int32_t abacus_vision_process(
    void* instance,
    const void* pixelBuffer,
    ExtractionResult* result
);

/// テンソルメモリを解放
void abacus_vision_free_result(ExtractionResult* result);

/// 設定を更新
void abacus_vision_set_config(void* instance, const PreprocessingConfig* config);

/// 検出パラメータを更新
void abacus_vision_set_detection_params(
    void* instance,
    const SorobanDetector::DetectionParams* params
);

} // extern "C"

} // namespace abacus

#endif // ABACUS_VISION_HPP
