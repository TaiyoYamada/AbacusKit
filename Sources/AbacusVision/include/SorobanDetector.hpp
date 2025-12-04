#ifndef SOROBAN_DETECTOR_HPP
#define SOROBAN_DETECTOR_HPP

#include "VisionTypes.hpp"
#include "ImagePreprocessor.hpp" // OpenCV stubs if needed
#include <vector>

namespace abacus {

/// そろばん検出クラス
/// 
/// 画像からそろばんフレームを検出し、レーンを分離する。
/// 可変レーン数に対応。
class SorobanDetector {
public:
    /// 検出パラメータ
    struct DetectionParams {
        // フレーム検出
        double minFrameAreaRatio = 0.05;    // 画像面積に対する最小比率
        double maxFrameAreaRatio = 0.95;    // 画像面積に対する最大比率
        double minAspectRatio = 1.5;        // 最小アスペクト比（幅/高さ）
        double maxAspectRatio = 10.0;       // 最大アスペクト比
        
        // レーン検出
        int minLaneCount = 1;               // 最小レーン数
        int maxLaneCount = 27;              // 最大レーン数（通常のそろばん）
        double laneHeightRatio = 0.8;       // レーン高さの許容範囲
        
        // Hough変換
        double houghRho = 1.0;
        double houghTheta = CV_PI / 180.0;
        int houghThreshold = 80;
        double houghMinLength = 50.0;
        double houghMaxGap = 10.0;
        
        // 輪郭近似
        double contourApproxEpsilon = 0.02;
        
        // セル分割
        int upperBeadRatio = 1;              // 上珠の相対高さ
        int lowerBeadRatio = 4;              // 下珠領域の相対高さ
        int beadDividerRatio = 1;            // 中央仕切りの相対高さ
    };
    
    SorobanDetector();
    explicit SorobanDetector(const DetectionParams& params);
    ~SorobanDetector();
    
    void setParams(const DetectionParams& params) { params_ = params; }
    const DetectionParams& getParams() const { return params_; }
    
    /// そろばんフレームを検出
    /// @param preprocessed 前処理済み画像 (BGR)
    /// @param binary 二値化画像
    /// @param edges エッジ画像
    /// @return 検出結果
    FrameDetectionResult detectFrame(
        const cv::Mat& preprocessed,
        const cv::Mat& binary,
        const cv::Mat& edges
    );
    
    /// 射影変換でフレームを正規化
    /// @param original オリジナル画像
    /// @param frame 検出されたフレーム
    /// @param outputWidth 出力幅
    /// @param outputHeight 出力高さ
    /// @return 正規化された画像
    cv::Mat warpFrame(
        const cv::Mat& original,
        const FrameDetectionResult& frame,
        int outputWidth = 800,
        int outputHeight = 200
    );
    
    /// レーン数を自動検出
    /// @param warpedFrame 射影変換後の画像
    /// @return 検出されたレーン数
    int detectLaneCount(const cv::Mat& warpedFrame);
    
    /// レーンを分割
    /// @param warpedFrame 射影変換後の画像
    /// @param laneCount レーン数
    /// @return レーン情報のリスト
    std::vector<LaneInfo> extractLanes(const cv::Mat& warpedFrame, int laneCount);
    
    /// 単一レーンからセルを抽出
    /// @param lane レーン画像
    /// @param laneInfo レーン情報（更新される）
    /// @return 抽出されたセル画像（上珠1 + 下珠4 = 5枚）
    std::vector<cv::Mat> extractCells(const cv::Mat& lane, LaneInfo& laneInfo);
    
private:
    DetectionParams params_;
    
    /// 輪郭からそろばんフレーム候補を抽出
    std::vector<std::vector<cv::Point>> findFrameCandidates(
        const cv::Mat& binary,
        double imageArea
    );
    
    /// 四角形の4隅を順序付け（左上、右上、右下、左下）
    Quadrilateral orderCorners(const std::vector<cv::Point>& contour);
    
    /// 投影ヒストグラムでレーン境界を検出
    std::vector<int> detectLaneBoundaries(const cv::Mat& gray);
    
    /// Hough変換で垂直線を検出
    std::vector<int> detectVerticalLines(const cv::Mat& edges);
};

} // namespace abacus

#endif // SOROBAN_DETECTOR_HPP
