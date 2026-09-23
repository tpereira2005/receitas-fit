import SwiftUI
import SwiftData

struct FoodEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]

    /// Receitas a rever depois de guardar um alimento já usado.
    private struct PendingReview: Hashable {
        let recipes: [Recipe]
        let changes: [String]
    }

    private let food: Food?
    private let onSave: ((Food) -> Void)?
    private let original: FoodDraft

    @State private var draft: FoodDraft
    @State private var confirmDiscard = false
    @State private var pendingReview: PendingReview?

    init(food: Food?, onSave: ((Food) -> Void)? = nil) {
        self.food = food
        self.onSave = onSave
        let initial = food.map { FoodDraft(food: $0) } ?? FoodDraft()
        self.original = initial
        _draft = State(initialValue: initial)
    }

    private var hasChanges: Bool { draft != original }

    private var warnings: [String] {
        var warnings: [String] = []
        if draft.facts.sugars > draft.facts.carbs {
            warnings.append("Os açúcares não podem ser superiores aos hidratos de carbono.")
        }
        if draft.facts.saturatedFat > draft.facts.fat {
            warnings.append("A gordura saturada não pode ser superior aos lípidos.")
        }
        return warnings
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Alimento") {
                    TextField("Nome (ex.: Peito de frango)", text: $draft.name)
                        .font(.headline)
                    TextField("Marca (opcional)", text: $draft.brand)
                    Picker("Categoria", selection: $draft.category) {
                        ForEach(FoodCategory.allCases) { category in
                            Label(category.shortTitle, systemImage: category.symbol).tag(category)
                        }
                    }
                }

                Section {
                    Picker("Valores", selection: $draft.base) {
                        ForEach(MeasureBase.allCases) { base in
                            Text(base.title).tag(base)
                        }
                    }
                    .pickerStyle(.segmented)
                    OptionalDecimalFieldRow(title: "Peso de 1 unidade", unit: draft.base.rawValue, value: $draft.unitWeight)
                } header: {
                    Text("Medida")
                } footer: {
                    Text("O peso de uma unidade (p. ex. 1 ovo ≈ 60 g) é opcional e permite usar unidades nas receitas.")
                }

                Section {
                    DecimalFieldRow(title: "Energia", unit: "kcal", value: $draft.facts.calories)
                    DecimalFieldRow(title: "Lípidos", unit: "g", value: $draft.facts.fat)
                    DecimalFieldRow(title: "dos quais saturados", unit: "g", value: $draft.facts.saturatedFat, indented: true)
                    DecimalFieldRow(title: "Hidratos de carbono", unit: "g", value: $draft.facts.carbs)
                    DecimalFieldRow(title: "dos quais açúcares", unit: "g", value: $draft.facts.sugars, indented: true)
                    DecimalFieldRow(title: "Fibra", unit: "g", value: $draft.facts.fiber)
                    DecimalFieldRow(title: "Proteína", unit: "g", value: $draft.facts.protein)
                    DecimalFieldRow(title: "Sal", unit: "g", value: $draft.facts.salt)
                } header: {
                    Text("Informação nutricional · \(draft.base.title.lowercased())")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Copia os valores do rótulo, pela mesma ordem.")
                        ForEach(warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        let estimate = draft.facts.estimatedCalories.rounded()
                        if estimate > 0 && abs(estimate - draft.facts.calories) >= 10 {
                            Button("Pelos macros dá cerca de \(Int(estimate)) kcal. Usar este valor") {
                                draft.facts.calories = estimate
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle(food == nil ? "Novo alimento" : "Editar alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark", action: save)
                        .disabled(!draft.isValid)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("Descartar alterações?", isPresented: $confirmDiscard) {
                Button("Descartar", role: .destructive) { dismiss() }
                Button("Continuar a editar", role: .cancel) {}
            }
            .navigationDestination(item: $pendingReview) { review in
                if let food {
                    FoodUpdateReviewView(food: food, recipes: review.recipes, changes: review.changes) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func save() {
        let target: Food
        if let food {
            target = food
        } else {
            target = Food()
            context.insert(target)
        }
        let changes = draft.changes(from: original)
        draft.apply(to: target)
        try? context.save()
        onSave?(target)

        // Nunca altera receitas em silêncio: se o alimento já é usado, pergunta quais atualizar.
        if food != nil, !changes.isEmpty {
            let affected = NutritionCalculator.recipesAffected(by: target, in: recipes)
            if !affected.isEmpty {
                pendingReview = PendingReview(recipes: affected.sorted { $0.title < $1.title }, changes: changes)
                return
            }
        }
        dismiss()
    }
}
