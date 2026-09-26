import SwiftUI
import SwiftData

/// Depois de editar um alimento: mostra as receitas que o usam e deixa escolher quais atualizar.
struct FoodUpdateReviewView: View {
    @Environment(\.modelContext) private var context

    let food: Food
    let recipes: [Recipe]
    /// Descrição do que mudou no alimento (vazia quando se revê mais tarde, a partir da página do alimento).
    let changes: [String]
    let onFinish: () -> Void

    @State private var selected: Set<UUID>

    init(food: Food, recipes: [Recipe], changes: [String], onFinish: @escaping () -> Void) {
        self.food = food
        self.recipes = recipes
        self.changes = changes
        self.onFinish = onFinish
        _selected = State(initialValue: Set(recipes.map(\.id)))
    }

    private var allSelected: Bool { selected.count == recipes.count }

    private var applyTitle: String {
        if selected.isEmpty { return "Escolhe as receitas a atualizar" }
        if allSelected { return recipes.count == 1 ? "Atualizar receita" : "Atualizar as \(recipes.count) receitas" }
        return "Atualizar \(Format.recipes(selected.count))"
    }

    var body: some View {
        List {
            Section {
                if changes.isEmpty {
                    Text("Estas receitas ainda usam valores anteriores de “\(food.name)”.")
                } else {
                    ForEach(changes, id: \.self) { change in
                        Label(change, systemImage: "arrow.right.circle")
                            .font(.subheadline)
                    }
                }
            } header: {
                Text(changes.isEmpty ? "Valores anteriores" : "O que mudou em “\(food.name)”")
            }

            Section {
                ForEach(recipes) { recipe in
                    let isSelected = selected.contains(recipe.id)
                    Button {
                        withAnimation(.snappy) {
                            if isSelected { selected.remove(recipe.id) } else { selected.insert(recipe.id) }
                        }
                    } label: {
                        ReviewRecipeRow(recipe: recipe, food: food, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Receitas afetadas (\(recipes.count))")
                    Spacer()
                    Button(allSelected ? "Desmarcar todas" : "Marcar todas") {
                        withAnimation(.snappy) {
                            selected = allSelected ? [] : Set(recipes.map(\.id))
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                }
            } footer: {
                Text("As receitas marcadas passam a usar os novos valores. As outras mantêm os valores anteriores e podes atualizá-las mais tarde na página do alimento.")
            }
        }
        .navigationTitle("Atualizar receitas?")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .interactiveDismissDisabled()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    let chosen = recipes.filter { selected.contains($0.id) }
                    NutritionCalculator.apply(food, to: chosen, context: context)
                    onFinish()
                } label: {
                    Text(applyTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(selected.isEmpty)

                Button {
                    onFinish()
                } label: {
                    Text("Manter valores anteriores")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

private struct ReviewRecipeRow: View {
    let recipe: Recipe
    let food: Food
    let isSelected: Bool

    private var beforeSummary: NutritionCalculator.Summary {
        var summary = NutritionCalculator.summarize(recipe.ingredients, foods: [:])
        summary.total = summary.total.scaled(by: 1 / Double(max(1, recipe.servings)))
        return summary
    }

    var body: some View {
        let before = beforeSummary
        let after = NutritionCalculator.preview(recipe, with: food)
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
            Color.clear
                .frame(width: 48, height: 48)
                .overlay { RecipePhoto(recipe: recipe, symbolSize: 18) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                comparison("kcal", before.total.calories, after.total.calories, unit: "", decimals: false)
                comparison("Proteína", before.total.protein, after.total.protein, unit: " g", decimals: true)
                if after.unresolved > before.unresolved {
                    Label("Um ingrediente deixa de ter conversão para a unidade usada.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func comparison(_ title: String, _ old: Double, _ new: Double, unit: String, decimals: Bool) -> some View {
        let format: (Double) -> String = { decimals ? $0.cleanString : Int($0.rounded()).formatted() }
        let changed = format(old) != format(new)
        return HStack(spacing: 4) {
            Text(title == "kcal" ? "Por porção:" : "\(title):")
                .foregroundStyle(.secondary)
            Text("\(format(old))\(unit)")
                .foregroundStyle(changed ? Color.secondary : Color.primary)
                .strikethrough(changed, color: .secondary)
            if changed {
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text("\(format(new))\(unit)")
                    .fontWeight(.semibold)
            }
            if title == "kcal" {
                Text("kcal").foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .monospacedDigit()
    }
}
