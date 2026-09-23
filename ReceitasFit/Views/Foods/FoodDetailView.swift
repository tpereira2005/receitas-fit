import SwiftUI
import SwiftData

struct FoodDetailView: View {
    let food: Food
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @State private var showingEditor = false
    @State private var confirmDelete = false

    private var usedIn: [Recipe] {
        recipes.filter { $0.ingredients.contains { $0.foodID == food.id } }
    }

    private var columns: [NutritionLabel.Column] {
        var columns = [NutritionLabel.Column(title: "Por \(food.measureBase.short)", facts: food.per100)]
        if let weight = food.unitWeight, weight > 0 {
            columns.append(.init(title: "Por unidade (\(weight.cleanString) \(food.measureBase.rawValue))", facts: food.per100.scaled(by: weight / 100)))
        }
        return columns
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                MacroStrip(facts: food.per100)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Informação nutricional").font(.title3.bold())
                    NutritionLabel(columns: columns)
                        .padding(18)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Usado em").font(.title3.bold())
                    if usedIn.isEmpty {
                        Text("Ainda não é usado em nenhuma receita.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(usedIn) { recipe in
                                NavigationLink(value: RecipeRoute(recipe: recipe, source: "food")) {
                                    RecipeRow(recipe: recipe)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                if recipe.id != usedIn.last?.id {
                                    Divider().padding(.leading, 74)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Editar") { showingEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Apagar alimento", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Label("Mais", systemImage: "ellipsis")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            FoodEditorView(food: food)
        }
        .alert("Apagar alimento?", isPresented: $confirmDelete) {
            Button("Apagar", role: .destructive, action: deleteFood)
            Button("Cancelar", role: .cancel) {}
        } message: {
            if usedIn.isEmpty {
                Text("“\(food.name)” será apagado da biblioteca.")
            } else {
                Text("“\(food.name)” é usado em \(Format.recipes(usedIn.count)). Nessas receitas, este ingrediente deixa de contar para os valores nutricionais.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            FoodIcon(category: food.category, size: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.title2.bold())
                    .fontDesign(.rounded)
                if !food.brand.isEmpty {
                    Text(food.brand).foregroundStyle(.secondary)
                }
                Text(food.category.shortTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(food.category.color)
            }
        }
    }

    private func deleteFood() {
        let food = food
        let context = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.delete(food)
            try? context.save()
            NutritionCalculator.refreshAllRecipes(in: context)
        }
    }
}
