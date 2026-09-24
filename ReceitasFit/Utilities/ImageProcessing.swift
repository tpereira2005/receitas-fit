import UIKit

/// Corre fora da thread principal (Task.detached), por isso não está isolado no MainActor.
nonisolated enum ImageProcessing {
    struct Output: Sendable {
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

    /// Imagem de um alimento: quadrada o suficiente para ícones, guardada em PNG para manter a transparência.
    static func foodImage(from data: Data) -> Data? {
        UIImage(data: data)?.resized(maxDimension: 512).pngData()
    }

    static func thumbnail(from data: Data) -> Data? {
        UIImage(data: data)?.resized(maxDimension: 800).jpegData(compressionQuality: 0.78)
    }
}

extension UIImage {
    /// Devolve a imagem redimensionada e já com a orientação corrigida.
    nonisolated func resized(maxDimension: CGFloat) -> UIImage {
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
