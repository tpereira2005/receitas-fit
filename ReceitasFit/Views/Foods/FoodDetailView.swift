import SwiftUI
import SwiftData

struct FoodDetailView: View {
    let food: Food
    let namespace: Namespace.ID

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @State private var showsTitle = false
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

    // MARK: - Medidas

    private struct MeasureRow: Identifiable {
        let id: String
        let title: String
        let grams: Double
    }

    /// Porções com nome, unidade e colheres com peso próprio (as colheres por omissão não aparecem).
    private var measureRows: [MeasureRow] {
        var rows = food.portions.map { MeasureRow(id: $0.id.uuidString, title: "1 \($0.name)", grams: $0.grams) }
        if let weight = food.unitWeight, weight > 0 {
            rows.append(MeasureRow(id: "unit", title: "1 unidade", grams: weight))
        }
        if let weight = food.tablespoonWeight {
            rows.append(MeasureRow(id: "tablespoon", title: "1 colher de sopa", grams: weight))
        }
        if let weight = food.teaspoonWeight {
            rows.append(MeasureRow(id: "teaspoon", title: "1 colher de chá", grams: weight))
        }
        return rows
    }

    private var measuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medidas").font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(measureRows) { row in
                    HStack {
                        Text(row.title)
                        Spacer()
                        Text("\(row.grams.cleanString) \(food.measureBase.rawValue)")
                            .foregroundStyle(.secondary)
                        Text("\(Int((food.calories * row.grams / 100).rounded())) kcal")
                            .monospacedDigit()
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 12)
                    if row.id != measureRows.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    var body: some View {
        // Depois de apagar, a vista ainda é desenhada durante a animação de saída.
        if food.isDeleted || food.modelContext == nil {
            Color(.systemBackground)
        } else {
            content
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
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

                if !measureRows.isEmpty {
                    measuresSection
                        .id("measures")
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
        // O nome já aparece no cabeçalho; na barra só surge depois de o cabeçalho sair do ecrã.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 60
        } action: { _, isPastHeader in
            withAnimation(.easeInOut(duration: 0.2)) { showsTitle = isPastHeader }
        }
        .task {
            // Usado apenas nas capturas automáticas do CI.
            guard ScreenshotMode.flag("screenshotFoodPortions") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            proxy.scrollTo("measures", anchor: .top)
        }
        }
        .navigationTitle(showsTitle ? food.name : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Editar", systemImage: "pencil") { showingEditor = true }
                    Divider()
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
            FoodIcon(food: food, size: 60)
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
        if ScreenshotMode.flag("screenshotFoodPortions"), food.portions.isEmpty {
            food.portions = [FoodPortion(name: "bife", grams: 120), FoodPortion(name: "peito inteiro", grams: 220)]
            food.tablespoonWeight = 12
            try? context.save()
        }
        if ScreenshotMode.flag("screenshotEditFood"), !showingEditor {
            showingEditor = true
        }
        guard ScreenshotMode.flag("screenshotFoodReview"), !showingReview, !usedIn.isEmpty else { return }
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
        Haptics.warning()
        context.delete(food)
        try? context.save()
        dismiss()
    }
}
