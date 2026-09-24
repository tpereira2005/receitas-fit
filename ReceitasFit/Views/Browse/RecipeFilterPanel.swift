import SwiftUI

/// Painel de filtros combinados do separador Receitas.
/// Mostra ao vivo quantas receitas ficam; os filtros não são guardados entre utilizações.
struct RecipeFilterPanel: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filters: RecipeFilterSet
    let recipes: [Recipe]

    @State private var draft: RecipeFilterSet

    init(filters: Binding<RecipeFilterSet>, recipes: [Recipe]) {
        _filters = filters
        self.recipes = recipes
        _draft = State(initialValue: filters.wrappedValue)
    }

    private var tags: [String] { TagLibrary.counts(in: recipes).map(\.tag) }
    private var hasSamples: Bool { recipes.contains(where: \.isSample) }
    private var resultCount: Int { recipes.filter(draft.matches).count }

    var body: some View {
        NavigationStack {
            Form {
                Section("Categorias") {
                    FlowLayout(spacing: 8) {
                        ForEach(RecipeCategory.allCases) { category in
                            toggleChip(
                                title: category.title,
                                icon: GlyphImage(image: category.glyph, isAsset: category.assetName != nil),
                                color: category.color,
                                isOn: draft.categories.contains(category)
                            ) {
                                draft.categories.formSymmetricDifference([category])
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Coleções") {
                    ForEach(QuickFilter.allCases) { filter in
                        Toggle(isOn: Binding(
                            get: { draft.quick.contains(filter) },
                            set: { isOn in if isOn { draft.quick.insert(filter) } else { draft.quick.remove(filter) } }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(filter.title)
                                    Text(filter.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: filter.symbol)
                                    .foregroundStyle(.white)
                                    .font(.footnote.weight(.semibold))
                                    .frame(width: 28, height: 28)
                                    .background(filter.color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }

                if !tags.isEmpty {
                    Section {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                toggleChip(
                                    title: tag,
                                    icon: GlyphImage(image: Image(systemName: "tag"), isAsset: false),
                                    color: .accentColor,
                                    isOn: draft.tags.contains(tag)
                                ) {
                                    draft.tags.formSymmetricDifference([tag])
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Etiquetas")
                    } footer: {
                        Text("Com várias etiquetas, basta a receita ter uma delas.")
                    }
                }

                Section("Já fizeste?") {
                    Picker("Já fizeste?", selection: $draft.cooked) {
                        ForEach(RecipeFilterSet.CookedFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if hasSamples {
                    Section {
                        Toggle("Esconder receitas de exemplo", isOn: $draft.hideSamples)
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpar") {
                        withAnimation(.snappy) { draft = RecipeFilterSet() }
                    }
                    .disabled(draft.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") {
                        filters = draft
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    filters = draft
                    dismiss()
                } label: {
                    Text(resultCount == 0 ? "Nenhuma receita com estes filtros" : "Mostrar \(Format.recipes(resultCount))")
                        .font(.headline)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(resultCount == 0)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.snappy, value: resultCount)
            }
            .sensoryFeedback(.selection, trigger: draft)
        }
    }

    private func toggleChip(title: String, icon: GlyphImage, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            // HStack e não Label: dentro de um Form, o Label ganha o estilo das linhas da lista.
            HStack(spacing: 6) {
                icon
                Text(title)
            }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)), in: .capsule)
                // Dentro de um Form, o FlowLayout propõe pouca largura: sem isto o texto partia-se letra a letra.
                .fixedSize()
        }
        .buttonStyle(.borderless)
    }
}
