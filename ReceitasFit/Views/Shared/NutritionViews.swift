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
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
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

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
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
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

/// Ícone quadrado com a cor da categoria do alimento.
struct FoodIcon: View {
    let category: FoodCategory
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(category.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

struct FoodRow: View {
    let food: Food

    var body: some View {
        HStack(spacing: 12) {
            FoodIcon(category: food.category)
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(food.brand.isEmpty ? food.macroSummary : "\(food.brand) · \(food.macroSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
