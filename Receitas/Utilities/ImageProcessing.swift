import ImageIO
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
///
/// As imagens são descodificadas já no tamanho em que aparecem (ImageIO, sem abrir a imagem inteira)
/// e preparadas para o ecrã antes de serem mostradas. A cache tem um limite de memória;
/// o `NSCache` é seguro entre threads, por isso a descodificação pode correr em segundo plano.
nonisolated final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.totalCostLimit = 80 * 1024 * 1024  // ~80 MB de imagens descodificadas
    }

    /// Só o que já está em cache (não descodifica).
    func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Imagem da cache ou descodificada agora (no máximo `maxPixelSize` no lado maior).
    func image(for key: String, data: Data, maxPixelSize: CGFloat? = nil) -> UIImage? {
        if let cached = cached(key) { return cached }
        guard let image = Self.decode(data, maxPixelSize: maxPixelSize) else { return nil }
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        cache.setObject(image, forKey: key as NSString, cost: Int(pixels * 4))
        return image
    }

    /// O mesmo, fora da thread principal (para as grelhas não engasgarem ao fazer scroll).
    func load(_ key: String, data: Data, maxPixelSize: CGFloat?) async -> UIImage? {
        if let cached = cached(key) { return cached }
        return await Task.detached(priority: .userInitiated) {
            self.image(for: key, data: data, maxPixelSize: maxPixelSize)
        }.value
    }

    private static func decode(_ data: Data, maxPixelSize: CGFloat?) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        if let maxPixelSize { options[kCGImageSourceThumbnailMaxPixelSize] = maxPixelSize }
        else if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            options[kCGImageSourceThumbnailMaxPixelSize] = max(width, height)
        }
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        let image = UIImage(cgImage: cgImage)
        return image.preparingForDisplay() ?? image
    }
}
