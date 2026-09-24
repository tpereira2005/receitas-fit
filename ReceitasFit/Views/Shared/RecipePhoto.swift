import SwiftUI

/// Fotografia da receita, ou um gradiente com o ícone da categoria quando ainda não há foto.
struct RecipePhoto: View {
    enum Variant: String { case thumbnail, full }

    let recipe: Recipe
    var variant: Variant = .thumbnail
    var symbolSize: CGFloat = 40

    var body: some View {
        if let uiImage = loadImage() {
            FocusedImage(image: uiImage, focus: recipe.photoFocus)
        } else {
            RecipePlaceholder(category: recipe.category, symbolSize: symbolSize)
        }
    }

    private func loadImage() -> UIImage? {
        let data: Data?
        switch variant {
        case .thumbnail: data = recipe.thumbnailData ?? recipe.photoData
        case .full: data = recipe.photoData ?? recipe.thumbnailData
        }
        guard let data else { return nil }
        let key = "\(recipe.id.uuidString)-\(variant.rawValue)-\(recipe.updatedAt.timeIntervalSince1970)"
        return ImageCache.shared.image(for: key, data: data)
    }
}

/// Imagem que preenche o espaço disponível mantendo à vista o ponto de foco escolhido
/// (por exemplo, o prato numa fotografia vertical mostrada num cartão largo).
struct FocusedImage: View {
    let image: UIImage
    var focus: UnitPoint = .center

    var body: some View {
        GeometryReader { geo in
            let frame = Self.frame(for: image.size, in: geo.size, focus: focus)
            Image(uiImage: image)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
        .clipped()
    }

    /// Posição da imagem escalada para cobrir `container`, com o foco o mais ao centro possível
    /// sem deixar bordas vazias.
    nonisolated static func frame(for imageSize: CGSize, in container: CGSize, focus: UnitPoint) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: container) }
        let scale = max(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let x = min(0, max(container.width - size.width, container.width / 2 - focus.x * size.width))
        let y = min(0, max(container.height - size.height, container.height / 2 - focus.y * size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }
}

extension Recipe {
    /// Ponto da fotografia que fica sempre à vista nos recortes (0…1 em cada eixo).
    var photoFocus: UnitPoint { UnitPoint(x: photoFocusX, y: photoFocusY) }
}

struct RecipePlaceholder: View {
    let category: RecipeCategory
    var symbolSize: CGFloat = 40

    @ViewBuilder
    private var glyph: some View {
        if category.assetName != nil {
            category.glyph
                .resizable()
                .scaledToFit()
                .frame(width: symbolSize * 1.2, height: symbolSize * 1.2)
        } else {
            category.glyph
                .font(.system(size: symbolSize, weight: .semibold))
        }
    }

    var body: some View {
        ZStack {
            Rectangle().fill(category.color.gradient)
            glyph
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
    }
}
