import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var photoItem: PhotosPickerItem?
    @State private var importingImage = false
    @State private var isProcessingImage = false
    @State private var imageError: String?

    /// Leitura de uma embalagem que preencheu este alimento novo (para rever antes de guardar).
    private let reading: PackageReading?
    @State private var showsRecognizedText = false

    init(food: Food?, onSave: ((Food) -> Void)? = nil) {
        self.food = food
        self.onSave = onSave
        self.reading = nil
        let initial = food.map { FoodDraft(food: $0) } ?? FoodDraft()
        self.original = initial
        _draft = State(initialValue: initial)
    }

    /// Alimento novo preenchido a partir das fotografias da embalagem.
    init(reading: PackageReading, onSave: ((Food) -> Void)? = nil) {
        self.food = nil
        self.onSave = onSave
        self.reading = reading
        // Parte de um alimento vazio: sair sem guardar pede sempre confirmação.
        self.original = FoodDraft()
        _draft = State(initialValue: reading.draft)
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
            ScrollViewReader { proxy in
            Form {
                if let reading {
                    readingSection(reading)
                }

                Section("Alimento") {
                    TextField("Nome (ex.: Peito de frango)", text: $draft.name)
                        .font(.headline)
                    TextField("Marca (opcional)", text: $draft.brand)
                    Picker("Categoria", selection: $draft.category) {
                        ForEach(FoodCategory.allCases) { category in
                            FoodCategoryLabel(category: category).tag(category)
                        }
                    }
                }

                imageSection

                Section {
                    Picker("Valores", selection: $draft.base) {
                        ForEach(MeasureBase.allCases) { base in
                            Text(base.title).tag(base)
                        }
                    }
                    .pickerStyle(.segmented)
                    OptionalDecimalFieldRow(title: "Peso de 1 unidade", unit: draft.base.rawValue, value: $draft.unitWeight)
                    OptionalDecimalFieldRow(title: "Colher de sopa", unit: draft.base.rawValue, value: $draft.tablespoonWeight,
                                            placeholder: IngredientUnit.defaultTablespoon.cleanString)
                    OptionalDecimalFieldRow(title: "Colher de chá", unit: draft.base.rawValue, value: $draft.teaspoonWeight,
                                            placeholder: IngredientUnit.defaultTeaspoon.cleanString)
                } header: {
                    Text("Medidas")
                } footer: {
                    Text("Tudo opcional. O peso de uma unidade (p. ex. 1 ovo ≈ 60 g) permite usar unidades nas receitas. As colheres valem \(IngredientUnit.defaultTablespoon.cleanString) e \(IngredientUnit.defaultTeaspoon.cleanString) \(draft.base.rawValue) se não indicares outro peso (p. ex. 1 colher de sopa de azeite ≈ 13 g).")
                }
                .id("measures")

                portionsSection

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
            .task {
                // Usado apenas nas capturas automáticas do CI.
                guard ScreenshotMode.flag("screenshotEditFood") else { return }
                try? await Task.sleep(for: .milliseconds(600))
                proxy.scrollTo("measures", anchor: .top)
            }
            }
            .navigationTitle(food == nil ? "Novo alimento" : "Editar alimento")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
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
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await setImage(from: data)
                    }
                    photoItem = nil
                }
            }
            .fileImporter(isPresented: $importingImage, allowedContentTypes: [.image]) { result in
                guard case .success(let url) = result else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) {
                    Task { await setImage(from: data) }
                } else {
                    imageError = "Não foi possível abrir este ficheiro."
                }
            }
            .alert(
                "Imagem",
                isPresented: Binding(get: { imageError != nil }, set: { if !$0 { imageError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(imageError ?? "")
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

    // MARK: - Leitura da embalagem

    @ViewBuilder
    private func readingSection(_ reading: PackageReading) -> some View {
        Section {
            readingStatus(reading)

            ForEach(reading.conflicts) { conflict in
                let current = draft.facts[keyPath: conflict.nutrient.keyPath]
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("\(conflict.nutrient.title): rótulo \(conflict.labelValue.cleanString) \(conflict.nutrient.unit) · Open Food Facts \(conflict.databaseValue.cleanString) \(conflict.nutrient.unit)")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    .font(.subheadline)
                    HStack {
                        Button("Rótulo") { draft.facts[keyPath: conflict.nutrient.keyPath] = conflict.labelValue }
                            .buttonStyle(.bordered)
                            .tint(current == conflict.labelValue ? .accentColor : .secondary)
                        Button("Open Food Facts") { draft.facts[keyPath: conflict.nutrient.keyPath] = conflict.databaseValue }
                            .buttonStyle(.bordered)
                            .tint(current == conflict.databaseValue ? .accentColor : .secondary)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(.vertical, 2)
            }

            if !reading.missing.isEmpty {
                Label {
                    Text("Não encontrado: \(reading.missing.map { $0.title.lowercased() }.formatted(.list(type: .and))). Confirma com o rótulo.")
                } icon: {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            let lessThan = Nutrient.allCases.filter { reading.lessThan.contains($0) }
            if !lessThan.isEmpty {
                Label {
                    Text("No rótulo com “<”: \(lessThan.map { "\($0.title.lowercased()) <\((reading.draft.facts[keyPath: $0.keyPath]).cleanString) g" }.formatted(.list(type: .and))). Ficou o valor indicado; podes pôr 0 se preferires.")
                } icon: {
                    Image(systemName: "lessthan.circle.fill").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if let portion = reading.labelPortion {
                Label {
                    Text("Porção do rótulo acrescentada: 1 \(portion.name) = \(portion.grams.cleanString) \(reading.draft.base.rawValue).")
                } icon: {
                    Image(systemName: "scalemass.fill").foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)
            }

            if !reading.notes.isEmpty {
                Label {
                    Text(reading.notes)
                } icon: {
                    Image(systemName: "text.bubble.fill").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if !reading.recognizedRows.isEmpty {
                DisclosureGroup("Texto lido", isExpanded: $showsRecognizedText) {
                    Text(reading.recognizedRows.map { $0.joined(separator: "  ·  ") }.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .font(.subheadline)
            }
        } header: {
            Text("Leitura da embalagem")
        } footer: {
            Text("Confirma cada valor com a embalagem. Nada fica guardado até tocares em Guardar; as fotografias e o código de barras não são guardados na app.")
        }
    }

    @ViewBuilder
    private func readingStatus(_ reading: PackageReading) -> some View {
        let fromLabel = reading.sources.values.filter { $0 == .label }.count
        let fromDatabase = reading.sources.values.filter { $0 == .openFoodFacts }.count
        VStack(alignment: .leading, spacing: 8) {
            Label {
                switch reading.reader {
                case .gemini:
                    Text("Lido com o Gemini")
                case .device(let reason):
                    Text(reason.map { "Lido no iPhone · \($0)" } ?? "Lido no iPhone")
                }
            } icon: {
                Image(systemName: reading.reader == .gemini ? "sparkles" : "iphone")
                    .foregroundStyle(reading.reader == .gemini ? Color.accentColor : .orange)
            }
            Label {
                Text(fromLabel > 0
                     ? "Rótulo: \(fromLabel) de \(Nutrient.allCases.count) valores lidos"
                     : "Não foi possível ler a tabela nutricional")
            } icon: {
                Image(systemName: fromLabel > 0 ? "text.viewfinder" : "exclamationmark.triangle.fill")
                    .foregroundStyle(fromLabel > 0 ? Color.accentColor : .orange)
            }
            Label {
                switch reading.databaseStatus {
                case .found(let name):
                    Text("Open Food Facts: \(name.isEmpty ? "produto encontrado" : name)\(fromDatabase > 0 ? " · completou \(fromDatabase) valores" : "")")
                case .notFound:
                    Text("Open Food Facts: produto não encontrado")
                case .unavailable:
                    Text("Open Food Facts: sem ligação à internet")
                case .noBarcode:
                    Text("Sem código de barras nas fotografias")
                }
            } icon: {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(reading.databaseStatus == .noBarcode ? Color.secondary : Color.accentColor)
            }
        }
        .font(.subheadline)
    }

    // MARK: - Porções

    private var portionsSection: some View {
        Section {
            ForEach($draft.portions) { $portion in
                HStack(spacing: 10) {
                    TextField("Nome (ex.: scoop)", text: $portion.name)
                        .textInputAutocapitalization(.never)
                    NumberField("0", value: $portion.grams, maxFractionDigits: 1)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 64)
                    Text(draft.base.rawValue)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)
                }
            }
            .onDelete { draft.portions.remove(atOffsets: $0) }

            Button {
                withAnimation { draft.portions.append(FoodPortion(name: "", grams: 0)) }
            } label: {
                Label("Adicionar porção", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Porções")
        } footer: {
            Text("Dá nome às porções que usas muitas vezes, no singular: “scoop” = 30 g, “fatia” = 25 g, “iogurte” = 120 g. Nas receitas passas a poder escrever “2 scoops”.")
        }
    }

    private var imageSection: some View {
        Section {
            HStack(spacing: 16) {
                FoodIcon(category: draft.category, imageData: draft.imageData, size: 64)
                    .overlay {
                        if isProcessingImage {
                            ProgressView()
                        }
                    }
                VStack(alignment: .leading, spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(draft.imageData == nil ? "Escolher das Fotos" : "Trocar pelas Fotos", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        importingImage = true
                    } label: {
                        Label("Escolher dos Ficheiros", systemImage: "folder")
                    }
                    if draft.imageData != nil {
                        Button("Remover imagem", systemImage: "trash", role: .destructive) {
                            withAnimation { draft.imageData = nil }
                        }
                    }
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Imagem")
        } footer: {
            Text("Opcional. Usa uma imagem quadrada, de preferência em PNG com fundo transparente. Quando existe, substitui o ícone da categoria.")
        }
    }

    private func setImage(from data: Data) async {
        isProcessingImage = true
        let processed = await Task.detached(priority: .userInitiated) {
            ImageProcessing.foodImage(from: data)
        }.value
        isProcessingImage = false
        if let processed {
            withAnimation { draft.imageData = processed }
        } else {
            imageError = "Este formato de imagem não é suportado."
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
        Haptics.success()
        dismiss()
    }
}
