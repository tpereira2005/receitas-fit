import SwiftUI
import SwiftData
import PhotosUI

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var foods: [Food]

    private let recipe: Recipe?
    private let original: RecipeDraft

    @State private var draft: RecipeDraft
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var confirmDiscard = false
    @State private var showingPicker = false
    @State private var editingIngredient: Ingredient?
    @State private var newTag = ""

    init(recipe: Recipe? = nil) {
        self.recipe = recipe
        let initial = recipe.map { RecipeDraft(recipe: $0) } ?? RecipeDraft()
        self.original = initial
        _draft = State(initialValue: initial)
    }

    private var hasChanges: Bool { draft != original }
    private var foodIndex: [UUID: Food] { NutritionCalculator.index(foods) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    photoSection
                    infoSection
                    timeSection
                    ingredientsSection
                        .id("ingredients")
                    nutritionSection
                    stepsSection
                    tagsSection
                    Section("Origem e notas") {
                        TextField("Link da publicação (Instagram, TikTok…)", text: $draft.sourceURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Notas, dicas, substituições…", text: $draft.notes, axis: .vertical)
                            .lineLimit(3...8)
                    }
                }
                .onAppear {
                    // Usado apenas nas capturas automáticas do CI.
                    if UserDefaults.standard.bool(forKey: "screenshotEditorIngredients") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            proxy.scrollTo("ingredients", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle(recipe == nil ? "Nova receita" : "Editar receita")
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
            } message: {
                Text("As alterações a esta receita vão perder-se.")
            }
            .sheet(isPresented: $showingPicker) {
                IngredientPickerView { ingredient in
                    withAnimation { draft.ingredients.append(ingredient) }
                }
            }
            .sheet(item: $editingIngredient) { ingredient in
                ingredientEditor(for: ingredient)
            }
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
        }
    }

    // MARK: - Secções

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Color.clear
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        if let data = draft.photoData ?? draft.thumbnailData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Rectangle().fill(draft.category.color.gradient)
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill").font(.largeTitle)
                                    Text("Adicionar fotografia").font(.headline)
                                }
                                .foregroundStyle(.white)
                            }
                        }
                    }
                    .overlay {
                        if isLoadingPhoto {
                            ProgressView()
                                .controlSize(.large)
                                .padding(20)
                                .glassEffect(.regular, in: .circle)
                        }
                    }
                    .clipped()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets())

            if draft.photoData != nil {
                Button("Remover fotografia", systemImage: "trash", role: .destructive) {
                    withAnimation {
                        draft.photoData = nil
                        draft.thumbnailData = nil
                        photoItem = nil
                    }
                }
            }
        }
    }

    private var infoSection: some View {
        Section("Receita") {
            TextField("Nome da receita", text: $draft.title)
                .font(.headline)
            TextField("Descrição curta (opcional)", text: $draft.summary, axis: .vertical)
                .lineLimit(1...4)
            Picker("Categoria", selection: $draft.category) {
                ForEach(RecipeCategory.allCases) { category in
                    RecipeCategoryLabel(category: category).tag(category)
                }
            }
        }
    }

    private var timeSection: some View {
        Section("Tempo e porções") {
            Stepper(value: $draft.servings, in: 1...50) {
                LabeledContent("Porções", value: "\(draft.servings)")
            }
            IntegerFieldRow(title: "Preparação", unit: "min", value: $draft.prepMinutes)
            IntegerFieldRow(title: "Confeção", unit: "min", value: $draft.cookMinutes)
        }
    }

    private var ingredientsSection: some View {
        Section {
            ForEach(draft.ingredients) { ingredient in
                Button {
                    editingIngredient = ingredient
                } label: {
                    EditorIngredientRow(ingredient: ingredient, food: ingredient.foodID.flatMap { foodIndex[$0] })
                }
                .tint(.primary)
            }
            .onDelete { draft.ingredients.remove(atOffsets: $0) }
            .onMove { draft.ingredients.move(fromOffsets: $0, toOffset: $1) }

            Button {
                showingPicker = true
            } label: {
                Label("Adicionar ingrediente", systemImage: "plus.circle.fill")
            }

            let outdated = outdatedIngredientCount
            if outdated > 0 {
                Button {
                    withAnimation { updateOutdatedIngredients() }
                } label: {
                    Label(
                        outdated == 1
                            ? "Usar valores atuais da biblioteca (1 ingrediente)"
                            : "Usar valores atuais da biblioteca (\(outdated) ingredientes)",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .tint(.orange)
            }
        } header: {
            Text("Ingredientes")
        } footer: {
            Text("Escolhe os ingredientes da biblioteca de alimentos e indica a quantidade total usada na receita. Toca num ingrediente para o alterar; arrasta para reordenar e desliza para apagar.")
        }
    }

    private var nutritionSection: some View {
        let summary = NutritionCalculator.summarize(draft.ingredients, foods: foodIndex)
        let perServing = summary.total.scaled(by: 1 / Double(max(1, draft.servings)))
        let usesLegacy = summary.linked == 0 && !draft.legacyNutrition.isEmpty
        return Section {
            if usesLegacy {
                MacroStrip(facts: draft.legacyNutrition)
                    .padding(.vertical, 6)
            } else if draft.ingredients.isEmpty {
                Text("Adiciona ingredientes para ver as calorias e os macros.")
                    .foregroundStyle(.secondary)
            } else {
                MacroStrip(facts: perServing)
                    .padding(.vertical, 6)
                NutritionLabel(columns: [
                    .init(title: "Por porção", facts: perServing),
                    .init(title: "Receita toda", facts: summary.total),
                ])
                .padding(.vertical, 4)
            }
        } header: {
            Text("Nutrição · calculada automaticamente")
        } footer: {
            if usesLegacy {
                Text("Estes valores foram introduzidos à mão numa versão anterior. Liga os ingredientes à biblioteca para passarem a ser calculados automaticamente.")
            } else if summary.unresolved > 0 {
                Label(
                    summary.unresolved == 1
                        ? "1 ingrediente não conta para os valores (sem alimento associado ou sem conversão para a unidade escolhida)."
                        : "\(summary.unresolved) ingredientes não contam para os valores (sem alimento associado ou sem conversão para a unidade escolhida).",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            } else if !draft.ingredients.isEmpty {
                Text("Valores por porção, com \(Format.servings(draft.servings)).")
            }
        }
    }

    private var stepsSection: some View {
        Section("Preparação") {
            ForEach($draft.steps) { $step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(stepNumber(for: step.id))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22)
                    TextField("Descreve este passo", text: $step.text, axis: .vertical)
                }
            }
            .onDelete { draft.steps.remove(atOffsets: $0) }
            .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }

            Button {
                withAnimation { draft.steps.append(RecipeStep()) }
            } label: {
                Label("Adicionar passo", systemImage: "plus.circle.fill")
            }
        }
    }

    private var tagsSection: some View {
        Section("Etiquetas") {
            if !draft.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(draft.tags, id: \.self) { tag in
                        Button {
                            withAnimation { draft.tags.removeAll { $0 == tag } }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tag)
                                Image(systemName: "xmark").font(.caption2.weight(.bold))
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15), in: .capsule)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }

            let suggestions = RecipeDraft.suggestedTags.filter { !draft.tags.contains($0) }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button("+ \(suggestion)") {
                                withAnimation { draft.tags.append(suggestion) }
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                        }
                    }
                }
            }

            HStack {
                TextField("Nova etiqueta", text: $newTag)
                    .onSubmit(addTag)
                Button("Adicionar", action: addTag)
                    .buttonStyle(.borderless)
                    .disabled(newTag.trimmed.isEmpty)
            }
        }
    }

    // MARK: - Ingredientes

    @ViewBuilder
    private func ingredientEditor(for ingredient: Ingredient) -> some View {
        if let food = ingredient.foodID.flatMap({ foodIndex[$0] }) {
            NavigationStack {
                IngredientQuantityView(food: food, initial: ingredient, confirmTitle: "Guardar", showsCancel: true) { updated in
                    replace(ingredient, with: updated)
                }
            }
        } else {
            // Ingrediente antigo, ainda sem alimento: escolher um da biblioteca.
            IngredientPickerView(replacing: ingredient) { updated in
                replace(ingredient, with: updated)
            }
        }
    }

    /// Ingredientes cujo alimento foi editado na biblioteca depois de ser adicionado a esta receita.
    private var outdatedIngredientCount: Int {
        draft.ingredients.filter { ingredient in
            guard let food = ingredient.foodID.flatMap({ foodIndex[$0] }) else { return false }
            return NutritionCalculator.isOutdated(ingredient, comparedTo: food)
        }.count
    }

    private func updateOutdatedIngredients() {
        draft.ingredients = draft.ingredients.map { ingredient in
            guard let food = ingredient.foodID.flatMap({ foodIndex[$0] }),
                  NutritionCalculator.isOutdated(ingredient, comparedTo: food) else { return ingredient }
            var updated = ingredient
            updated.name = food.name
            updated.snapshot = FoodSnapshot(food: food)
            return updated
        }
    }

    private func replace(_ ingredient: Ingredient, with updated: Ingredient) {
        if let index = draft.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
            draft.ingredients[index] = updated
        }
        editingIngredient = nil
    }

    // MARK: - Ações

    private func stepNumber(for id: UUID) -> Int {
        (draft.steps.firstIndex { $0.id == id } ?? 0) + 1
    }

    private func addTag() {
        let tag = newTag.trimmed
        guard !tag.isEmpty, !draft.tags.contains(tag) else { return }
        withAnimation { draft.tags.append(tag) }
        newTag = ""
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingPhoto = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let processed = await Task.detached(priority: .userInitiated) {
                    ImageProcessing.prepare(data)
                }.value
                if let processed {
                    withAnimation {
                        draft.photoData = processed.photo
                        draft.thumbnailData = processed.thumbnail
                    }
                }
            }
            isLoadingPhoto = false
        }
    }

    private func save() {
        let target: Recipe
        if let recipe {
            target = recipe
        } else {
            target = Recipe()
            context.insert(target)
        }
        draft.apply(to: target, foods: foodIndex)
        try? context.save()
        dismiss()
    }
}

/// Linha de ingrediente no editor: alimento, quantidade e calorias dessa quantidade.
private struct EditorIngredientRow: View {
    let ingredient: Ingredient
    let food: Food?

    private var isLinked: Bool { food != nil || ingredient.snapshot != nil }

    private var isOutdated: Bool {
        guard let food else { return false }
        return NutritionCalculator.isOutdated(ingredient, comparedTo: food)
    }

    private var detail: String {
        guard isLinked else { return "Não está na biblioteca · toca para escolher o alimento" }
        let amount = ingredient.amountText() ?? ingredient.unit
        guard let facts = NutritionCalculator.facts(for: ingredient, food: food) else {
            return "\(amount) · sem conversão para esta unidade"
        }
        var text = ingredient.unit == IngredientUnit.toTaste.rawValue
            ? amount
            : "\(amount) · \(Int(facts.calories.rounded())) kcal · \(facts.protein.cleanString) g proteína"
        if isOutdated { text += " · valores anteriores" }
        return text
    }

    var body: some View {
        HStack(spacing: 12) {
            if let food {
                FoodIcon(food: food, size: 30)
            } else if ingredient.snapshot != nil {
                FoodIcon(category: .other, size: 30)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(!isLinked || isOutdated ? Color.orange : Color.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
