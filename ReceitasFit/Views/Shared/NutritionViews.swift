import SwiftUI

/// Tabela nutricional na mesma ordem dos rótulos europeus, com uma ou mais colunas.
struct NutritionLabel: View {
    struct Column {
        let title: String
        let facts: NutritionFacts
    }

    private struct Row {
        let title: String
        let unit: String
        let keyPath: KeyPath<NutritionFacts, Double>
        var indented = false
    }

    private static let rows: [Row] = [
        Row(title: "Energia", unit: "kcal", keyPath: \.calories),
        Row(title: "Lípidos", unit: "g", keyPath: \.fat),
        Row(title: "dos quais saturados", unit: "g", keyPath: \.saturatedFat, indented: true),
        Row(title: "Hidratos de carbono", unit: "g", keyPath: \.carbs),
        Row(title: "dos quais açúcares", unit: "g", keyPath: \.sugars, indented: true),
        Row(title: "Fibra", unit: "g", keyPath: \.fiber),
        Row(title: "Proteína", unit: "g", keyPath: \.protein),
        Row(title: "Sal", unit: "g", keyPath: \.salt),
    ]

    let columns: [Column]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(columns, id: \.title) { column in
                    Text(column.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                }
            }
            .padding(.bottom, 6)

            ForEach(Self.rows, id: \.title) { row in
                Divider()
                GridRow {
                    Text(row.title)
                        .font(row.indented ? .subheadline : .subheadline.weight(.medium))
                        .foregroundStyle(row.indented ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                        .padding(.leading, row.indented ? 14 : 0)
                    ForEach(columns, id: \.title) { column in
                        Text(Self.format(column.facts[keyPath: row.keyPath], unit: row.unit))
                            .font(.subheadline)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)
                    }
                }
                .padding(.vertical, 7)
            }
        }
    }

    static func format(_ value: Double, unit: String) -> String {
        let number = value.formatted(.number.precision(.fractionLength(unit == "kcal" ? 0...0 : 0...1)))
        return "\(number) \(unit)"
    }
}

/// Faixa compacta com energia e os três macros.
struct MacroStrip: View {
    let facts: NutritionFacts

    var body: some View {
        HStack(spacing: 0) {
            item(Int(facts.calories.rounded()).formatted(), title: "kcal", color: .orange)
            item(facts.protein.cleanString, title: "Proteína", color: .pink)
            item(facts.carbs.cleanString, title: "Hidratos", color: .orange)
            item(facts.fat.cleanString, title: "Gordura", color: .teal)
        }
    }

    private func item(_ value: String, title: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title == "kcal" ? value : "\(value) g")
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "kcal" ? "\(value) calorias" : "\(title): \(value) gramas")
    }
}

// MARK: - Linhas de formulário

struct DecimalFieldRow: View {
    let title: String
    let unit: String
    @Binding var value: Double
    var indented = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(indented ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
                .padding(.leading, indented ? 14 : 0)
            Spacer()
            NumberField("0", value: $value)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

struct OptionalDecimalFieldRow: View {
    let title: String
    let unit: String
    @Binding var value: Double?
    var placeholder = "—"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            NumberField(placeholder: placeholder, value: $value, maxFractionDigits: 1)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

struct IntegerFieldRow: View {
    let title: String
    let unit: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            NumberField("0", integer: $value)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

/// Tempo de espera em horas e minutos (24 h escreve-se "24", não "1440").
struct WaitTimeRow: View {
    @Binding var minutes: Int

    var body: some View {
        HStack {
            Text("Espera")
            Spacer()
            NumberField("0", integer: Binding(
                get: { minutes / 60 },
                set: { minutes = max(0, $0) * 60 + minutes % 60 }
            ))
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 44)
            Text("h").foregroundStyle(.secondary)
            NumberField("0", integer: Binding(
                get: { minutes % 60 },
                set: { minutes = (minutes / 60) * 60 + min(59, max(0, $0)) }
            ))
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 36)
            Text("min")
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

/// Ícone de um alimento: a imagem personalizada, se existir, ou o ícone da categoria.
struct FoodIcon: View {
    let category: FoodCategory
    var imageData: Data?
    var imageKey: String?
    var size: CGFloat = 32

    init(category: FoodCategory, imageData: Data? = nil, imageKey: String? = nil, size: CGFloat = 32) {
        self.category = category
        self.imageData = imageData
        self.imageKey = imageKey
        self.size = size
    }

    init(food: Food, size: CGFloat = 32) {
        self.init(
            category: food.category,
            imageData: food.imageData,
            imageKey: "food-\(food.id.uuidString)-\(food.updatedAt.timeIntervalSince1970)",
            size: size
        )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
    }

    private var customImage: UIImage? {
        guard let imageData else { return nil }
        if let imageKey { return ImageCache.shared.image(for: imageKey, data: imageData, maxPixelSize: 256) }
        return UIImage(data: imageData)
    }

    var body: some View {
        if let customImage {
            // Imagens com fundo transparente ficam sobre a cor da categoria, como os ícones sem imagem.
            // A sombra suave separa o alimento do fundo quando têm cores parecidas (morangos no rosa).
            Image(uiImage: customImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: size * 0.05, y: size * 0.025)
                .background(category.color.gradient)
                .clipShape(shape)
        } else {
            category.glyph
                .resizable()
                .scaledToFit()
                .fontWeight(.semibold)
                .frame(width: size * 0.5, height: size * 0.5)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(category.color.gradient, in: shape)
        }
    }
}

/// Ícone ao lado de texto: SF Symbol ou ícone desenhado para a app, com o mesmo tamanho visual.
struct GlyphImage: View {
    let image: Image
    let isAsset: Bool

    /// Os ícones desenhados acompanham o tamanho do texto, como os SF Symbols.
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 18
    /// Tamanho fixo para contextos com ícones maiores (p. ex. os círculos de Explorar).
    private let fixedSize: CGFloat?

    init(image: Image, isAsset: Bool, size: CGFloat? = nil) {
        self.image = image
        self.isAsset = isAsset
        self.fixedSize = size
    }

    var body: some View {
        if isAsset {
            image
                .resizable()
                .scaledToFit()
                .frame(width: fixedSize ?? scaledSize, height: fixedSize ?? scaledSize)
        } else {
            image
        }
    }
}

/// Etiqueta com o nome e o ícone de uma categoria de alimentos.
struct FoodCategoryLabel: View {
    let category: FoodCategory
    var short = true

    var body: some View {
        Label {
            Text(short ? category.shortTitle : category.title)
        } icon: {
            GlyphImage(image: category.glyph, isAsset: category.assetName != nil)
        }
    }
}

/// Etiqueta com o nome e o ícone de uma categoria de receitas.
struct RecipeCategoryLabel: View {
    let category: RecipeCategory

    var body: some View {
        Label {
            Text(category.title)
        } icon: {
            GlyphImage(image: category.glyph, isAsset: category.assetName != nil)
        }
    }
}

struct FoodRow: View {
    let food: Food

    var body: some View {
        HStack(spacing: 12) {
            FoodIcon(food: food)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                // Marca e macros numa linha; se não couberem, ficam só os macros.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        if !food.brand.isEmpty {
                            Text(food.brand).fixedSize()
                        }
                        MacroDots(facts: food.per100)
                    }
                    MacroDots(facts: food.per100)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(Int(food.calories.rounded()), format: .number)
                    .font(.headline)
                    .monospacedDigit()
                Text("kcal/\(food.measureBase.short)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Macros em pontos coloridos (as mesmas cores da app): proteína, hidratos e gordura.
struct MacroDots: View {
    let facts: NutritionFacts

    var body: some View {
        HStack(spacing: 8) {
            dot(facts.protein, color: .pink)
            dot(facts.carbs, color: .orange)
            dot(facts.fat, color: .teal)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Proteína \(facts.protein.cleanString) gramas, hidratos \(facts.carbs.cleanString), gordura \(facts.fat.cleanString)")
    }

    private func dot(_ value: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(value.cleanString).monospacedDigit()
        }
    }
}
