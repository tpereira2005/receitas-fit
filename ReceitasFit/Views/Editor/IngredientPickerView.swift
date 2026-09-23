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
    private let units: [IngredientUnit]
    /// Valores já guardados na receita para este alimento; mantêm-se ao mudar só a quantidade.
    private let keptSnapshot: FoodSnapshot?
    @State private var amount: Double?
    @State private var unit: IngredientUnit
    @FocusState private var amountFocused: Bool

    init(food: Food, initial: Ingredient?, confirmTitle: String, showsCancel: Bool = false, onConfirm: @escaping (Ingredient) -> Void) {
        self.food = food
        self.confirmTitle = confirmTitle
        self.showsCancel = showsCancel
        self.onConfirm = onConfirm
        let units = IngredientUnit.available(for: food)
        self.units = units
        let initialUnit = initial.flatMap { IngredientUnit(rawValue: $0.unit) }.flatMap { units.contains($0) ? $0 : nil } ?? units[0]
        ingredientID = initial?.id ?? UUID()
        keptSnapshot = initial?.foodID == food.id ? initial?.snapshot : nil
        _unit = State(initialValue: initialUnit)
        _amount = State(initialValue: initial?.amount ?? (initialUnit == .unit ? 1 : 100))
    }

    private var ingredient: Ingredient {
        Ingredient(
            id: ingredientID,
            name: keptSnapshot?.name ?? food.name,
            amount: unit == .toTaste ? nil : amount,
            unit: unit.rawValue,
            foodID: food.id,
            snapshot: keptSnapshot ?? FoodSnapshot(food: food)
        )
    }

    private var usesPreviousValues: Bool {
        keptSnapshot != nil && keptSnapshot != FoodSnapshot(food: food)
    }

    private var canConfirm: Bool { unit == .toTaste || (amount ?? 0) > 0 }

    private var conversionNote: String? {
        switch unit {
        case .unit: food.unitWeight.map { "1 unidade ≈ \($0.cleanString) \(food.measureBase.rawValue)" }
        case .tablespoon: "1 colher de sopa ≈ 15 \(food.measureBase.rawValue)"
        case .teaspoon: "1 colher de chá ≈ 5 \(food.measureBase.rawValue)"
        case .toTaste: "Quantidades “q.b.” não contam para os valores nutricionais."
        case .gram, .milliliter: nil
        }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    FoodIcon(food: food, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).font(.headline)
                        Text("\(Int(food.calories.rounded())) kcal · \(food.macroSummary) por \(food.measureBase.short)")
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
                if unit != .toTaste {
                    HStack {
                        TextField("Quantidade", value: $amount, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                            .focused($amountFocused)
                        Text(unit.rawValue)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Unidade", selection: $unit) {
                    ForEach(units) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
            } header: {
                Text("Quantidade na receita (total)")
            } footer: {
                if let conversionNote {
                    Text(conversionNote)
                }
            }

            if unit != .toTaste {
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
        .onAppear { amountFocused = unit != .toTaste }
    }
}
