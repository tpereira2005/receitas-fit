import SwiftUI

/// Imagem para partilhar uma receita: fotografia, título e macros por porção.
/// Desenhada em pontos (360 de largura) e exportada a 3× (1080 px).
struct RecipeShareCard: View {
    enum ShareFormat: String, CaseIterable, Identifiable {
        case square, story

        var id: String { rawValue }
        var title: String { self == .square ? "Quadrada" : "Stories" }
        var size: CGSize { self == .square ? CGSize(width: 360, height: 360) : CGSize(width: 360, height: 640) }
    }

    /// Dados da receita já preparados (a imagem é desenhada fora da hierarquia de vistas).
    struct Content {
        var title: String
        var category: RecipeCategory
        var photo: UIImage?
        var focus: UnitPoint
        var perServing: NutritionFacts
        var servings: Int
        var totalMinutes: Int

        init(recipe: Recipe) {
            title = recipe.title
            category = recipe.category
            photo = (recipe.photoData ?? recipe.thumbnailData).flatMap(UIImage.init(data:))
            focus = recipe.photoFocus
            perServing = recipe.perServing
            servings = recipe.servings
            totalMinutes = recipe.totalMinutes
        }
    }

    let content: Content
    let format: ShareFormat

    var body: some View {
        Group {
            switch format {
            case .square: square
            case .story: story
            }
        }
        .frame(width: format.size.width, height: format.size.height)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Quadrada

    private var square: some View {
        ZStack(alignment: .bottomLeading) {
            photo
            LinearGradient(
                stops: [.init(color: .black.opacity(0), location: 0.3), .init(color: .black.opacity(0.82), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 10) {
                categoryChip
                Text(content.title)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                macroRow
                footer(light: true)
            }
            .padding(20)
        }
    }

    // MARK: - Stories

    private var story: some View {
        VStack(spacing: 0) {
            photo
                .frame(height: 360)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, background], startPoint: .top, endPoint: .bottom)
                        .frame(height: 90)
                }
                .clipped()

            VStack(alignment: .leading, spacing: 16) {
                categoryChip
                Text(content.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                macroGrid
                if !facts.isEmpty {
                    Text(details)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                footer(light: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(background)
    }

    // MARK: - Peças

    private var background: Color { Color(red: 0.09, green: 0.1, blue: 0.11) }
    private var facts: NutritionFacts { content.perServing }

    @ViewBuilder
    private var photo: some View {
        if let image = content.photo {
            FocusedImage(image: image, focus: content.focus)
        } else {
            RecipePlaceholder(category: content.category, symbolSize: 80)
        }
    }

    private var categoryChip: some View {
        Text(content.category.title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(content.category.color.gradient, in: Capsule())
    }

    private var details: String {
        var parts = ["por porção"]
        if content.totalMinutes > 0 { parts.append("\(content.totalMinutes) min") }
        parts.append(Format.servings(content.servings))
        return parts.joined(separator: " · ")
    }

    private struct Macro: Identifiable {
        let id: String
        let value: String
        let label: String
        let color: Color
    }

    private var macros: [Macro] {
        [
            Macro(id: "kcal", value: "\(Int(facts.calories.rounded()))", label: "kcal", color: .orange),
            Macro(id: "p", value: "\(facts.protein.cleanString) g", label: "Proteína", color: .pink),
            Macro(id: "h", value: "\(facts.carbs.cleanString) g", label: "Hidratos", color: .yellow),
            Macro(id: "g", value: "\(facts.fat.cleanString) g", label: "Gordura", color: .teal),
        ]
    }

    @ViewBuilder
    private var macroRow: some View {
        if !facts.isEmpty {
            HStack(spacing: 6) {
                ForEach(macros) { macro in
                    VStack(spacing: 1) {
                        Text(macro.value)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(macro.label)
                            .font(.system(size: 10, weight: .medium))
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .top) {
                        Capsule().fill(macro.color).frame(width: 18, height: 3).offset(y: 3)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var macroGrid: some View {
        if !facts.isEmpty {
            // Grid (e não LazyVGrid): o ImageRenderer não desenha vistas "lazy".
            let items = macros
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    macroTile(items[0])
                    macroTile(items[1])
                }
                GridRow {
                    macroTile(items[2])
                    macroTile(items[3])
                }
            }
        }
    }

    private func macroTile(_ macro: Macro) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(macro.color).frame(width: 7, height: 7)
                Text(macro.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(macro.value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func footer(light: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "fork.knife")
            Text("Receitas")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(light ? 0.75 : 0.5))
    }

    // MARK: - Exportar

    /// Imagem final (1080 px de largura).
    @MainActor
    static func render(_ content: Content, format: ShareFormat) -> UIImage? {
        let renderer = ImageRenderer(content: RecipeShareCard(content: content, format: format))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
