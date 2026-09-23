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
    @State private var showingReview = false
    @State private var reviewChanges: [String] = []

    private var usedIn: [Recipe] {
        recipes.filter { $0.ingredients.contains { $0.foodID == food.id } }
    }

    /// Receitas que mantiveram valores anteriores deste alimento.
    private var outdated: [Recipe] {
        NutritionCalculator.recipesAffected(by: food, in: recipes)
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

                if !outdated.isEmpty {
                    outdatedBanner
                }

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
        .sheet(isPresented: $showingReview) {
            NavigationStack {
                FoodUpdateReviewView(food: food, recipes: outdated, changes: reviewChanges) {
                    showingReview = false
                    reviewChanges = []
                }
            }
        }
        .onAppear(perform: handleScreenshotArguments)
        .alert("Apagar alimento?", isPresented: $confirmDelete) {
            Button("Apagar", role: .destructive, action: deleteFood)
            Button("Cancelar", role: .cancel) {}
        } message: {
            if usedIn.isEmpty {
                Text("“\(food.name)” será apagado da biblioteca.")
            } else {
                Text("“\(food.name)” é usado em \(Format.recipes(usedIn.count)). Essas receitas mantêm os valores atuais deste ingrediente.")
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

    private var outdatedBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(outdated.count == 1
                     ? "1 receita usa valores anteriores deste alimento."
                     : "\(outdated.count) receitas usam valores anteriores deste alimento.")
                    .font(.subheadline.weight(.medium))
                Button("Rever e atualizar") { showingReview = true }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glass)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Usado apenas nas capturas automáticas do CI: simula a edição do alimento para mostrar a revisão.
    private func handleScreenshotArguments() {
        guard UserDefaults.standard.bool(forKey: "screenshotFoodReview"), !showingReview, !usedIn.isEmpty else { return }
        var draft = FoodDraft(food: food)
        let original = draft
        draft.facts.calories += 10
        draft.facts.protein += 2
        draft.apply(to: food)
        try? context.save()
        reviewChanges = draft.changes(from: original)
        showingReview = true
    }

    private func deleteFood() {
        let food = food
        let context = context
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.delete(food)
            try? context.save()
        }
    }
}
