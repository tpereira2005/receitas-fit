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
