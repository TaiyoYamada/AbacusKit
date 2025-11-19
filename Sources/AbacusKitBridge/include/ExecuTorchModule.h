#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

/// AbacusKit の推論結果を表す構造体
typedef struct {
    /// 予測されたクラス（0: upper, 1: lower, 2: empty）
    NSInteger predictedClass;
    
    /// 各クラスの確率（3要素の配列）
    float probabilities[3];
    
    /// 推論時間（ミリ秒）
    double inferenceTimeMs;
} ExecuTorchPredictionResult;

/// ExecuTorch モデルを Swift から呼び出すための Bridge
@interface ExecuTorchModuleBridge : NSObject

/// モデルをロードする
/// @param path モデルファイル（.pte）のパス
/// @param error エラーが発生した場合に設定される
/// @return 成功した場合は YES
- (BOOL)loadModelAtPath:(NSString *)path error:(NSError **)error;

/// PixelBuffer から推論を実行する
/// @param pixelBuffer 入力画像（224x224 RGB を想定）
/// @param result 推論結果を格納する構造体へのポインタ
/// @param error エラーが発生した場合に設定される
/// @return 成功した場合は YES
- (BOOL)predictWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                        result:(ExecuTorchPredictionResult *)result
                         error:(NSError **)error;

/// モデルがロード済みかどうか
@property (nonatomic, readonly) BOOL isModelLoaded;

@end

NS_ASSUME_NONNULL_END
