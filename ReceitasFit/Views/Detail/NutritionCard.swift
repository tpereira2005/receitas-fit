import SwiftUI
import Charts

struct MacroValue: Identifiable {
    let id: String
    let name: String
    let grams: Double
    let kcalPerGram: Double
    let color: Color

    var kcal: Double { grams * kcalPerGram }
}

struct NutritionCard: View {
    let recipe: Recipe

    private var macros: [MacroValue] {
        [
            MacroValue(id: "protein", name: "Proteína", grams: recipe.protein, kcalPerGram: 4, color: .pink),
            MacroValue(id: "carbs", name: "Hidratos", grams: recipe.carbs, kcalPerGram: 4, color: .orange),
            MacroValue(id: "fat", name: "Gordura", grams: recipe.fat, kcalPerGram: 9, color: .teal),
        ]
    }

    private var macroCalories: Double { macros.reduce(0) { $0 + $1.kcal } }
    private var hasMacros: Bool { macroCalories > 0 }
    private var displayCalories: Double { recipe.calories > 0 ? recipe.calories : macroCalories }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Nutrição").font(.title2.bold())
                Spacer()
                Text("por porção")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if displayCalories == 0 && !hasMacros {
                Label("Ainda sem informação nutricional. Edita a receita para adicionar calorias e macros.", systemImage: "chart.pie")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 22) {
                    ZStack {
                        if hasMacros {
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

                if recipe.fiber > 0 {
                    Label("Fibra: \(recipe.fiber.cleanString) g", systemImage: "leaf.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(macro.color).frame(width: 8, height: 8)
                Text(macro.name).font(.subheadline)
                Spacer()
                Text("\(macro.grams.cleanString) g")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
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
        }
    }
}
