import SwiftUI
import SwiftData
import PhotosUI

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let recipe: Recipe?
    private let startWithImport: Bool
    private let original: RecipeDraft

    @State private var draft: RecipeDraft
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var showingImport = false
    @State private var confirmDiscard = false
    @State private var quickIngredient = ""
    @State private var newTag = ""
    @FocusState private var quickIngredientFocused: Bool

    init(recipe: Recipe? = nil, startWithImport: Bool = false) {
        self.recipe = recipe
        self.startWithImport = startWithImport
        let initial = recipe.map { RecipeDraft(recipe: $0) } ?? RecipeDraft()
        self.original = initial
        _draft = State(initialValue: initial)
    }

    private var hasChanges: Bool { draft != original }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                infoSection
                importSection
                timeSection
                nutritionSection
                ingredientsSection
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
            .confirmationDialog("Descartar alterações?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { dismiss() }
                Button("Continuar a editar", role: .cancel) {}
            }
            .sheet(isPresented: $showingImport) {
                ImportTextView { result in
                    withAnimation { draft.merge(result) }
                }
            }
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
            .task {
                guard startWithImport else { return }
                try? await Task.sleep(for: .milliseconds(450))
                showingImport = true
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
                        if let data = draft.thumbnailData ?? draft.photoData, let image = UIImage(data: data) {
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
                    Label(category.title, systemImage: category.symbol).tag(category)
                }
            }
        }
    }

    private var importSection: some View {
        Section {
            Button {
                showingImport = true
            } label: {
                Label("Importar de texto ou captura de ecrã", systemImage: "text.viewfinder")
            }
        } footer: {
            Text("Cola a legenda de uma publicação e a app preenche os ingredientes, os passos e os macros.")
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

    private var nutritionSection: some View {
        Section {
            DecimalFieldRow(title: "Calorias", unit: "kcal", value: $draft.calories)
            DecimalFieldRow(title: "Proteína", unit: "g", value: $draft.protein)
            DecimalFieldRow(title: "Hidratos", unit: "g", value: $draft.carbs)
            DecimalFieldRow(title: "Gordura", unit: "g", value: $draft.fat)
            DecimalFieldRow(title: "Fibra", unit: "g", value: $draft.fiber)
        } header: {
            Text("Nutrição por porção")
        } footer: {
            let estimate = draft.macroCalories.rounded()
            if estimate > 0 && abs(estimate - draft.calories) >= 5 {
                Button("Pelos macros dá \(Int(estimate)) kcal. Usar este valor") {
                    draft.calories = estimate
                }
                .font(.footnote.weight(.semibold))
            }
        }
    }

    private var ingredientsSection: some View {
        Section {
            ForEach($draft.ingredients) { $ingredient in
                IngredientEditorRow(ingredient: $ingredient)
            }
            .onDelete { draft.ingredients.remove(atOffsets: $0) }
            .onMove { draft.ingredients.move(fromOffsets: $0, toOffset: $1) }

            HStack {
                TextField("Ex.: 200 g peito de frango", text: $quickIngredient)
                    .focused($quickIngredientFocused)
                    .submitLabel(.next)
                    .onSubmit(addQuickIngredient)
                Button("Adicionar ingrediente", systemImage: "plus.circle.fill", action: addQuickIngredient)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .buttonStyle(.borderless)
                    .disabled(quickIngredient.trimmed.isEmpty)
            }
        } header: {
            Text("Ingredientes")
        } footer: {
            Text("Escreve a quantidade, a unidade e o ingrediente numa só linha. Arrasta para reordenar e desliza para apagar.")
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

    // MARK: - Ações

    private func stepNumber(for id: UUID) -> Int {
        (draft.steps.firstIndex { $0.id == id } ?? 0) + 1
    }

    private func addQuickIngredient() {
        let text = quickIngredient.trimmed
        guard !text.isEmpty else { return }
        withAnimation { draft.ingredients.append(RecipeTextParser.parseIngredient(text)) }
        quickIngredient = ""
        quickIngredientFocused = true
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
        draft.apply(to: target)
        try? context.save()
        dismiss()
    }
}

// MARK: - Linhas do formulário

struct IngredientEditorRow: View {
    @Binding var ingredient: Ingredient

    var body: some View {
        HStack(spacing: 8) {
            TextField("Qtd.", value: $ingredient.amount, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 54)
            TextField("un.", text: $ingredient.unit)
                .textInputAutocapitalization(.never)
                .foregroundStyle(.secondary)
                .frame(width: 60)
            Divider()
            TextField("Ingrediente", text: $ingredient.name)
        }
    }
}

struct DecimalFieldRow: View {
    let title: String
    let unit: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

struct IntegerFieldRow: View {
    let title: String
    let unit: String
    @Binding var value: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}
