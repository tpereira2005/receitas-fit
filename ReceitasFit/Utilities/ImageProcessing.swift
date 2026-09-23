import UIKit
import Vision

enum ImageProcessing {
    struct Output {
        let photo: Data
        let thumbnail: Data
    }

    /// Redimensiona a fotografia escolhida para poupar espaço e gera uma miniatura para os cartões.
    static func prepare(_ data: Data) -> Output? {
        guard let image = UIImage(data: data),
              let photo = image.resized(maxDimension: 1800).jpegData(compressionQuality: 0.82),
              let thumbnail = image.resized(maxDimension: 800).jpegData(compressionQuality: 0.78)
        else { return nil }
        return Output(photo: photo, thumbnail: thumbnail)
    }

    static func thumbnail(from data: Data) -> Data? {
        UIImage(data: data)?.resized(maxDimension: 800).jpegData(compressionQuality: 0.78)
    }
}

extension UIImage {
    /// Devolve a imagem redimensionada e já com a orientação corrigida.
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = longest > 0 ? min(1, maxDimension / longest) : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// Cache de imagens descodificadas, para os cartões não descodificarem JPEG a cada redesenho.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    func image(for key: String, data: Data) -> UIImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}

/// Reconhecimento de texto (OCR) no próprio iPhone, para importar receitas a partir de capturas de ecrã.
enum TextRecognizer {
    static func recognizeText(in data: Data) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = UIImage(data: data)?.resized(maxDimension: 2400), let cgImage = image.cgImage else {
                    continuation.resume(returning: "")
                    return
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                    return
                }
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}
