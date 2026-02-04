import Cocoa
import Vision

enum OCRService {
    /// 从 CGImage 中识别文字
    /// - Parameters:
    ///   - image: 目标图片
    ///   - completion: 识别完成回调，返回拼接后的字符串，如果失败则返回 nil
    static func recognizeText(from image: CGImage, completion: @escaping (String?) -> Void) {
        // 1. 创建请求处理句柄
        let requestHandler = VNImageRequestHandler(cgImage: image, options: [:])
        
        // 2. 创建文字识别请求
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(nil)
                return
            }
            
            // 提取识别结果
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // 将所有结果按行拼接
            let fullText = recognizedStrings.joined(separator: "\n")
            
            DispatchQueue.main.async {
                completion(fullText.isEmpty ? nil : fullText)
            }
        }
        
        // 3. 配置识别请求
        request.recognitionLevel = .accurate // 高精度模式
        request.recognitionLanguages = ["zh-Hans", "en-US"] // 支持中英文
        request.usesLanguageCorrection = true // 开启语言纠错
        
        // 4. 执行请求
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}
