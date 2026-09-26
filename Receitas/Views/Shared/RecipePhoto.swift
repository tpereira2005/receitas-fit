import SwiftUI

/// Fotografia da receita, ou um gradiente com o ícone da categoria quando ainda não há foto.
struct RecipePhoto: View {
    enum Variant: String { case thumbnail, full }

    let recipe: Recipe
    var variant: Variant = .thumbnail
    var symbolSize: CGFloat = 40

    /// Miniatura descodificada em segundo plano (as grelhas não esperam por ela).
    @State private var loaded: UIImage?

    /// Com zoom, a miniatura (800 px) fica pouco nítida nos cartões: usa-se a fotografia original.
    private var zoomed: Bool { recipe.photoZoom > 1.05 && recipe.photoData != nil }

    private var data: Data? {
        switch variant {
        case .thumbnail: zoomed ? recipe.photoData : recipe.thumbnailData ?? recipe.photoData
        case .full: recipe.photoData ?? recipe.thumbnailData
        }
    }

    private var key: String {
        "\(recipe.id.uuidString)-\(variant.rawValue)-\(recipe.updatedAt.timeIntervalSince1970)-\(zoomed)"
    }

    /// Cartões: ~600 px chegam para o maior cartão num ecrã 3×; o topo da receita usa a imagem inteira.
    private var maxPixelSize: CGFloat? { variant == .thumbnail ? 600 * min(recipe.photoZoom, FocusedImage.maxZoom) : nil }

    private var image: UIImage? {
        guard let data else { return nil }
        if let cached = ImageCache.shared.cached(key) { return cached }
        // O topo da receita descodifica logo, para a transição de zoom não mostrar o fundo.
        if variant == .full { return ImageCache.shared.image(for: key, data: data, maxPixelSize: maxPixelSize) }
        return loaded
    }

    var body: some View {
        Group {
            if let image {
                FocusedImage(image: image, focus: recipe.photoFocus, zoom: recipe.photoZoom)
            } else if data != nil {
                // A carregar: só a cor da categoria, sem ícone (evita um salto quando a foto aparece).
                Rectangle().fill(recipe.category.color.opacity(0.25))
            } else {
                RecipePlaceholder(category: recipe.category, symbolSize: symbolSize)
            }
        }
        .accessibilityHidden(true)
        .task(id: key) {
            guard variant == .thumbnail, let data, ImageCache.shared.cached(key) == nil else { return }
            let image = await ImageCache.shared.load(key, data: data, maxPixelSize: maxPixelSize)
            withAnimation(.easeOut(duration: 0.15)) { loaded = image }
        }
    }
}

/// Imagem que preenche o espaço disponível mantendo à vista o ponto de foco escolhido
/// (por exemplo, o prato numa fotografia vertical mostrada num cartão largo).
struct FocusedImage: View {
    /// Zoom máximo no enquadramento.
    static let maxZoom = 3.0

    let image: UIImage
    var focus: UnitPoint = .center
    var zoom: Double = 1

    var body: some View {
        GeometryReader { geo in
            let frame = Self.frame(for: image.size, in: geo.size, focus: focus, zoom: zoom)
            Image(uiImage: image)
                .resizable()
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
        }
        .clipped()
    }

    /// Posição da imagem escalada para cobrir `container` (e aproximada com `zoom`), com o foco
    /// o mais ao centro possível sem deixar bordas vazias.
    nonisolated static func frame(for imageSize: CGSize, in container: CGSize, focus: UnitPoint, zoom: Double = 1) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return CGRect(origin: .zero, size: container) }
        let scale = max(container.width / imageSize.width, container.height / imageSize.height) * max(1, zoom)
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
    /// `.top` põe o ícone no primeiro terço (quando há texto por cima, em baixo).
    var alignment: VerticalAlignment = .center

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
                .frame(maxHeight: .infinity, alignment: alignment == .top ? .top : .center)
                .padding(.top, alignment == .top ? symbolSize * 1.1 : 0)
        }
    }
}
