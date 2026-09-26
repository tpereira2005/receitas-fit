import SwiftUI
import SwiftData

/// Escolher um alimento da biblioteca e indicar a quantidade.
struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]

    /// Ingrediente a substituir (ligar à biblioteca), mantendo a quantidade quando possível.
    var replacing: Ingredient?
    let onPick: (Ingredient) -> Void

    @State private var searchText = ""
    @State private var path: [Food] = []
    @State private var showingNewFood = false

    private var filtered: [Food] {
        let query = searchText.trimmed.searchNormalized
        guard !query.isEmpty else { return foods }
        return foods.filter { "\($0.name) \($0.brand)".searchNormalized.contains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Button {
                        showingNewFood = true
                    } label: {
                        Label("Criar novo alimento", systemImage: "plus.circle.fill")
                    }
                } footer: {
                    if let replacing {
                        Text("A escolher o alimento para “\(replacing.name)”.")
                    }
                }

                ForEach(FoodCategory.allCases) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { food in
                                NavigationLink(value: food) {
                                    FoodRow(food: food)
                                }
                            }
                        } header: {
                            FoodCategoryLabel(category: category)
                        }
                    }
                }
            }
            .overlay {
                if filtered.isEmpty && !searchText.trimmed.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Procurar alimento")
            .navigationTitle(replacing == nil ? "Adicionar ingrediente" : "Escolher alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .navigationDestination(for: Food.self) { food in
                IngredientQuantityView(
                    food: food,
                    initial: replacing,
                    confirmTitle: replacing == nil ? "Adicionar" : "Guardar"
                ) { ingredient in
                    onPick(ingredient)
                    dismiss()
                }
            }
            .sheet(isPresented: $showingNewFood) {
                FoodEditorView(food: nil) { created in
                    path.append(created)
                }
            }
        }
    }
}

/// Quantidade de um alimento numa receita, com pré-visualização dos valores nutricionais.
struct IngredientQuantityView: View {
    @Environment(\.dismiss) private var dismiss

    let food: Food
    let confirmTitle: String
    var showsCancel = false
    let onConfirm: (Ingredient) -> Void

    private let ingredientID: UUID
    /// Medidas disponíveis: base, porções com nome, unidade, colheres e q.b.
    private let measures: [IngredientMeasure]
    /// Valores já guardados na receita para este alimento; mantêm-se ao mudar só a quantidade.
    private let keptSnapshot: FoodSnapshot?
    @State private var amount: Double?
    @State private var measureID: String

    init(food: Food, initial: Ingredient?, confirmTitle: String, showsCancel: Bool = false, onConfirm: @escaping (Ingredient) -> Void) {
        self.food = food
        self.confirmTitle = confirmTitle
        self.showsCancel = showsCancel
        self.onConfirm = onConfirm
        let kept = initial?.foodID == food.id ? initial?.snapshot : nil
        keptSnapshot = kept
        ingredientID = initial?.id ?? UUID()

        var measures = food.measures
        // Uma porção entretanto apagada do alimento continua disponível para esta receita.
        if let current = initial?.measure, !measures.contains(where: { $0.id == current.id }) {
            measures.insert(current, at: 1)
        }
        self.measures = measures
        let initialMeasure = initial?.measure.flatMap { current in measures.first { $0.id == current.id } } ?? measures[0]
        _measureID = State(initialValue: initialMeasure.id)
        let startsWithCount: Bool = switch initialMeasure {
        case .portion, .unit(.unit): true
        default: false
        }
        _amount = State(initialValue: initial?.amount ?? (startsWithCount ? 1 : 100))
    }

    private var measure: IngredientMeasure {
        measures.first { $0.id == measureID } ?? measures[0]
    }

    private var isToTaste: Bool { measure == .unit(.toTaste) }

    /// Valores usados: os anteriores da receita, se servirem para esta medida; senão, os atuais.
    private var snapshot: FoodSnapshot {
        if let keptSnapshot, keptSnapshot.supports(measure) { return keptSnapshot }
        return FoodSnapshot(food: food)
    }

    private var ingredient: Ingredient {
        Ingredient(food: food, amount: amount, measure: measure, id: ingredientID, snapshot: snapshot)
    }

    private var usesPreviousValues: Bool {
        guard keptSnapshot != nil else { return false }
        return NutritionCalculator.isOutdated(ingredient, comparedTo: food)
    }

    private var canConfirm: Bool { isToTaste || (amount ?? 0) > 0 }

    /// Nome curto da medida ao lado da quantidade: "g", "scoops", "c. sopa".
    private var measureLabel: String {
        switch measure {
        case .unit(let unit): unit.rawValue
        case .portion(let portion): FoodPortion.pluralize(portion.name, amount: amount ?? 1)
        }
    }

    @ViewBuilder
    private func measureRow(_ measure: IngredientMeasure) -> some View {
        if case .portion(let portion) = measure {
            Text("\(measure.title) (\(portion.grams.cleanString) \(food.measureBase.rawValue))")
        } else {
            Text(measure.title)
        }
    }

    /// Ao trocar de medida, mantém aproximadamente a mesma quantidade (100 g → 3,5 scoops, e não 100 scoops).
    private func convertAmount(from old: IngredientMeasure?) {
        guard let old, let amount, amount > 0, !isToTaste else { return }
        let oldIngredient = Ingredient(food: food, amount: amount, measure: old, snapshot: snapshot)
        let unitIngredient = Ingredient(food: food, amount: 1, measure: measure, snapshot: snapshot)
        guard let grams = snapshot.grams(for: oldIngredient), grams > 0,
              let perUnit = snapshot.grams(for: unitIngredient), perUnit > 0
        else { return }
        let converted = grams / perUnit
        switch measure {
        case .unit(.gram), .unit(.milliliter):
            self.amount = converted.rounded()
        default:
            self.amount = max(0.5, (converted * 2).rounded() / 2)
        }
    }

    private var conversionNote: String? {
        let base = food.measureBase.rawValue
        let one = Ingredient(food: food, amount: 1, measure: measure, snapshot: snapshot)
        let grams = snapshot.grams(for: one)?.cleanString ?? "—"
        switch measure {
        case .portion(let portion): return "1 \(portion.name) = \(grams) \(base)"
        case .unit(.unit): return "1 unidade ≈ \(grams) \(base)"
        case .unit(.tablespoon): return "1 colher de sopa ≈ \(grams) \(base)"
        case .unit(.teaspoon): return "1 colher de chá ≈ \(grams) \(base)"
        case .unit(.toTaste): return "Quantidades “q.b.” não contam para os valores nutricionais."
        case .unit: return nil
        }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    FoodIcon(food: food, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).font(.headline)
                        HStack(spacing: 8) {
                            Text("\(Int(food.calories.rounded())) kcal/\(food.measureBase.short)")
                            MacroDots(facts: food.per100)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                if usesPreviousValues {
                    Label("Esta receita usa valores anteriores deste alimento. Para os atualizar, usa “Usar valores atuais” na lista de ingredientes.", systemImage: "clock.arrow.circlepath")
                }
            }

            Section {
                if !isToTaste {
                    HStack {
                        NumberField(placeholder: "Quantidade", value: $amount, focusOnAppear: true)
                            .font(.title2.weight(.semibold))
                        Text(measureLabel)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
                Picker("Medida", selection: $measureID) {
                    ForEach(measures) { measure in
                        measureRow(measure).tag(measure.id)
                    }
                }
            } header: {
                Text("Quantidade na receita (total)")
            } footer: {
                if let conversionNote {
                    Text(conversionNote)
                }
            }
            .onChange(of: measureID) { oldID, _ in
                convertAmount(from: measures.first { $0.id == oldID })
            }

            if !isToTaste {
                Section("Nutrição desta quantidade") {
                    if let facts = NutritionCalculator.facts(for: ingredient, food: food) {
                        MacroStrip(facts: facts)
                            .padding(.vertical, 6)
                    } else {
                        Text("Indica uma quantidade.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .toolbar {
            if showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmTitle, systemImage: "checkmark") { onConfirm(ingredient) }
                    .disabled(!canConfirm)
            }
        }
    }
}
