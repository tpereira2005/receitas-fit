import SwiftUI

/// Fotografia da receita, ou um gradiente com o ícone da categoria quando ainda não há foto.
struct RecipePhoto: View {
    enum Variant: String { case thumbnail, full }

    let recipe: Recipe
    var variant: Variant = .thumbnail
    var symbolSize: CGFloat = 40

    var body: some View {
        if let uiImage = loadImage() {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
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
