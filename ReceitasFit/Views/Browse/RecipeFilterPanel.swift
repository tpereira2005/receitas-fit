import SwiftUI

/// Painel de filtros combinados (Receitas e Pesquisa). As categorias ficam nas cápsulas por cima da lista.
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
                .padding(.top, 12)
                .padding(.bottom, 8)
                // Fundo esbatido: as etiquetas que passam por baixo do botão deixam de se ver através dele.
                .background {
                    LinearGradient(
                        stops: [
                            .init(color: Color(.systemGroupedBackground).opacity(0), location: 0),
                            .init(color: Color(.systemGroupedBackground), location: 0.35),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
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

/// Filtros ativos por baixo das categorias, cada um com um toque para o remover.
struct ActiveFilterChips: View {
    @Binding var filters: RecipeFilterSet

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters.chips) { chip in
                    Button {
                        withAnimation(.snappy) { filters.remove(chip.remove) }
                    } label: {
                        HStack(spacing: 5) {
                            Text(chip.title)
                            Image(systemName: "xmark").font(.caption2.weight(.bold))
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15), in: .capsule)
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remover filtro \(chip.title)")
                }
                Button("Limpar tudo") {
                    withAnimation(.snappy) { filters = RecipeFilterSet() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollClipDisabled()
    }
}

/// Botão dos filtros na barra, com o número de filtros ativos.
struct FilterToolbarButton: View {
    let filters: RecipeFilterSet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Filtros", systemImage: filters.isEmpty
                  ? "line.3.horizontal.decrease"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .badge(filters.activeCount)
    }
}
