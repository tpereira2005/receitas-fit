import SwiftUI
import PhotosUI

/// Colar a legenda de uma publicação (ou ler o texto de uma captura de ecrã) e convertê-la numa receita.
struct ImportTextView: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: (RecipeTextParser.Result) -> Void

    @State private var text = ""
    @State private var imageItem: PhotosPickerItem?
    @State private var isRecognizing = false

    private var preview: RecipeTextParser.Result { RecipeTextParser.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.callout)
                        .frame(minHeight: 240)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("Cola aqui a legenda da publicação ou o texto da receita…")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                } footer: {
                    Text("Dica: títulos como “Ingredientes” e “Preparação” ajudam a separar as secções.")
                }

                Section {
                    PasteButton(payloadType: String.self) { strings in
                        let pasted = strings.joined(separator: "\n")
                        text = text.isEmpty ? pasted : text + "\n" + pasted
                    }
                    PhotosPicker(selection: $imageItem, matching: .images) {
                        HStack {
                            Label("Ler texto de uma captura de ecrã", systemImage: "text.viewfinder")
                            Spacer()
                            if isRecognizing { ProgressView() }
                        }
                    }
                    .disabled(isRecognizing)
                }

                if !text.trimmed.isEmpty {
                    let result = preview
                    Section("Pré-visualização") {
                        LabeledContent("Título", value: result.title ?? "—")
                        LabeledContent("Ingredientes", value: "\(result.ingredients.count)")
                        LabeledContent("Passos", value: "\(result.steps.count)")
                        if let servings = result.servings {
                            LabeledContent("Porções", value: "\(servings)")
                        }
                        if let calories = result.calories {
                            LabeledContent("Calorias", value: "\(calories.cleanString) kcal")
                        }
                        if let protein = result.protein {
                            LabeledContent("Proteína", value: "\(protein.cleanString) g")
                        }
                    }
                }
            }
            .navigationTitle("Importar receita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importar", systemImage: "checkmark") {
                        onImport(preview)
                        dismiss()
                    }
                    .disabled(preview.isEmpty)
                }
            }
            .onChange(of: imageItem) { _, item in
                recognize(item)
            }
        }
    }

    private func recognize(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isRecognizing = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let recognized = await TextRecognizer.recognizeText(in: data)
                if !recognized.isEmpty {
                    text = text.isEmpty ? recognized : text + "\n" + recognized
                }
            }
            isRecognizing = false
            imageItem = nil
        }
    }
}
