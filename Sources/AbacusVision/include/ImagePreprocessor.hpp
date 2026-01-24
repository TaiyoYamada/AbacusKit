#ifndef IMAGE_PREPROCESSOR_HPP
#define IMAGE_PREPROCESSOR_HPP

#include "VisionTypes.hpp"

#if __has_include(<opencv2/core.hpp>)
#define ABACUS_HAS_OPENCV 1
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>
#else
#define ABACUS_HAS_OPENCV 0
#ifndef CV_PI
#define CV_PI 3.14159265358979323846
#endif
// OpenCV stub types for compilation without OpenCV
namespace cv {
    class Mat {
    public:
        Mat() : rows(0), cols(0) {}
        int rows, cols;
        bool empty() const { return rows == 0 || cols == 0; }
        int channels() const { return 0; }
        Mat clone() const { return Mat(); }
    };
    template<typename T> class Ptr {
    public:
        void apply(const Mat&, Mat&) {}
    };
    class CLAHE {};
    class Size {
    public:
        Size() {}
        Size(int, int) {}
    };
    class Point {
    public:
        int x, y;
        Point() : x(0), y(0) {}
        Point(int x_, int y_) : x(x_), y(y_) {}
    };
    class Point2f {
    public:
        float x, y;
        Point2f() : x(0), y(0) {}
        Point2f(float x_, float y_) : x(x_), y(y_) {}
    };
    class Scalar {};
    class Rect {
    public:
        int x, y, width, height;
        Rect() : x(0), y(0), width(0), height(0) {}
        Rect(int x_, int y_, int w_, int h_) : x(x_), y(y_), width(w_), height(h_) {}
    };
    template<typename T> class Vec {
    public:
        T operator[](int) const { return T(); }
    };
    typedef Vec<unsigned char> Vec3b;
    typedef Vec<int> Vec4i;
    inline Ptr<CLAHE> createCLAHE(double, Size) { return Ptr<CLAHE>(); }
}
#endif

namespace abacus {

/// 画像前処理クラス
/// 
/// OpenCV を使用して画像の前処理を行う。
/// - 色補正（ホワイトバランス、CLAHE）
/// - ノイズ低減（Gaussian, Bilateral）
/// - 二値化（適応的閾値）
/// - モルフォロジー演算
class ImagePreprocessor {
public:
    ImagePreprocessor();
    explicit ImagePreprocessor(const PreprocessingConfig& config);
    ~ImagePreprocessor();
    
    /// 設定を更新
    void setConfig(const PreprocessingConfig& config);
    const PreprocessingConfig& getConfig() const { return config_; }
    
    /// CVPixelBuffer から cv::Mat に変換
    /// @param pixelBuffer CVPixelBufferRef
    /// @param output 出力 Mat (BGR)
    /// @return エラーコード
    VisionError convertFromPixelBuffer(const void* pixelBuffer, cv::Mat& output);
    
    /// リサイズ（アスペクト比維持）
    cv::Mat resize(const cv::Mat& input);
    
    /// グレースケール変換
    cv::Mat toGrayscale(const cv::Mat& input);
    
    /// ホワイトバランス補正
    cv::Mat applyWhiteBalance(const cv::Mat& input);
    
    /// CLAHE（局所コントラスト強調）
    cv::Mat applyCLAHE(const cv::Mat& gray);
    
    /// ガウシアンブラー
    cv::Mat applyGaussianBlur(const cv::Mat& input);
    
    /// バイラテラルフィルタ（エッジ保持ノイズ低減）
    cv::Mat applyBilateralFilter(const cv::Mat& input);
    
    /// 適応的二値化
    cv::Mat adaptiveThreshold(const cv::Mat& gray);
    
    /// モルフォロジー演算（ノイズ除去）
    cv::Mat morphologyClean(const cv::Mat& binary);
    
    /// エッジ検出 (Canny)
    cv::Mat detectEdges(const cv::Mat& gray);
    
    /// 完全な前処理パイプライン
    /// @param input 入力画像 (BGR)
    /// @param preprocessed 前処理済み画像
    /// @param binary 二値化画像
    /// @param edges エッジ画像
    /// @return エラーコード
    VisionError preprocess(
        const cv::Mat& input,
        cv::Mat& preprocessed,
        cv::Mat& binary,
        cv::Mat& edges
    );
    
private:
    PreprocessingConfig config_;
    cv::Ptr<cv::CLAHE> clahe_;
    
    void initCLAHE();
};

} // namespace abacus

#endif // IMAGE_PREPROCESSOR_HPP
