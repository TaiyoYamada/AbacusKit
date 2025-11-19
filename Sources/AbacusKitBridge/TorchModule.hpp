#ifndef TorchModule_hpp
#define TorchModule_hpp

#include <torch/script.h>
#include <memory>
#include <vector>
#include <string>

namespace abacuskit {

/// TorchScript モデルを管理する C++ クラス
class TorchInferenceEngine {
public:
    TorchInferenceEngine() = default;
    ~TorchInferenceEngine() = default;
    
    // コピー禁止
    TorchInferenceEngine(const TorchInferenceEngine&) = delete;
    TorchInferenceEngine& operator=(const TorchInferenceEngine&) = delete;
    
    /// モデルをロードする
    /// @param modelPath モデルファイル（.pt）のパス
    /// @return 成功した場合は true
    bool loadModel(const std::string& modelPath);
    
    /// 推論を実行する
    /// @param inputTensor 入力テンソル（1, 3, 224, 224）
    /// @return 出力テンソル（1, 3）の確率分布
    std::vector<float> predict(const std::vector<float>& inputTensor);
    
    /// モデルがロード済みかどうか
    bool isLoaded() const { return module_ != nullptr; }
    
private:
    std::unique_ptr<torch::jit::script::Module> module_;
};

} // namespace abacuskit

#endif /* TorchModule_hpp */
