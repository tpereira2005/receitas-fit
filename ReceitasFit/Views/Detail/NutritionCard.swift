import SwiftUI
import Charts

struct MacroValue: Identifiable {
    let id: String
    let name: String
    let grams: Double
    let kcalPerGram: Double
    let color: Color
    var detail: String?

    var kcal: Double { grams * kcalPerGram }
}

struct NutritionCard: View {
    let perServing: NutritionFacts
    /// Porções escolhidas no seletor da receita (a vista "Receita" mostra o total para estas porções).
    let servings: Int
    /// Porções com que a receita foi guardada.
    var originalServings: Int? = nil
    var note: String?

    @State private var showsWholeRecipe = false

    private var facts: NutritionFacts {
        showsWholeRecipe ? perServing.scaled(by: Double(max(1, servings))) : perServing
    }

    private var macros: [MacroValue] {
        [
            MacroValue(id: "protein", name: "Proteína", grams: facts.protein, kcalPerGram: 4, color: .pink),
            MacroValue(id: "carbs", name: "Hidratos", grams: facts.carbs, kcalPerGram: 4, color: .orange,
                       detail: "açúcares \(facts.sugars.cleanString) g"),
            MacroValue(id: "fat", name: "Gordura", grams: facts.fat, kcalPerGram: 9, color: .teal,
                       detail: "saturada \(facts.saturatedFat.cleanString) g"),
        ]
    }

    private var footnote: String {
        let original = originalServings ?? servings
        if showsWholeRecipe {
            return servings == original
                ? "Receita toda · \(Format.servings(servings))"
                : "Receita ajustada para \(Format.servings(servings)) · original: \(Format.servings(original))"
        }
        return "Por porção · a receita rende \(Format.servings(original))"
    }

    private var macroCalories: Double { macros.reduce(0) { $0 + $1.kcal } }
    private var displayCalories: Double { facts.calories > 0 ? facts.calories : macroCalories }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("Nutrição").font(.title2.bold())
                Spacer()
                Picker("Valores", selection: $showsWholeRecipe.animation(.snappy)) {
                    Text("Porção").tag(false)
                    Text("Receita").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 168)
            }

            if perServing.isEmpty {
                Label("Ainda sem informação nutricional. Edita a receita e adiciona ingredientes da biblioteca.", systemImage: "chart.pie")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 22) {
                    ZStack {
                        if macroCalories > 0 {
                            Chart(macros) { macro in
                                SectorMark(
                                    angle: .value("kcal", macro.kcal),
                                    innerRadius: .ratio(0.74),
                                    angularInset: 2.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(macro.color.gradient)
                            }
                            .chartLegend(.hidden)
                        } else {
                            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 14)
                        }
                        VStack(spacing: 0) {
                            Text(Int(displayCalories.rounded()), format: .number)
                                .font(.title2.bold())
                                .fontDesign(.rounded)
                                .contentTransition(.numericText())
                            Text("kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 118, height: 118)

                    VStack(spacing: 12) {
                        ForEach(macros) { macro in
                            MacroRow(macro: macro, share: macroCalories > 0 ? macro.kcal / macroCalories : 0)
                        }
                    }
                }

                HStack(spacing: 10) {
                    MiniStat(title: "Fibra", value: "\(facts.fiber.cleanString) g", icon: Image(systemName: "leaf.fill"), color: .green)
                    MiniStat(title: "Sal", value: "\(facts.salt.formatted(.number.precision(.fractionLength(0...2)))) g", icon: Image("glyph.saltshaker"), color: .secondary)
                }
            }

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            if let note {
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct MacroRow: View {
    let macro: MacroValue
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(macro.color).frame(width: 8, height: 8)
                Text(macro.name).font(.subheadline)
                Spacer()
                Text("\(macro.grams.cleanString) g")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                Capsule()
                    .fill(macro.color.opacity(0.15))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(macro.color.gradient)
                            .frame(width: geo.size.width * min(1, max(0, share)))
                    }
            }
            .frame(height: 6)
            if let detail = macro.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MiniStat: View {
    let title: String
    let value: String
    let icon: Image
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            icon
                .resizable()
                .scaledToFit()
                .fontWeight(.bold)
                .frame(width: 14, height: 14)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
