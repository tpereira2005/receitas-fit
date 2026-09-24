import SwiftUI
import SwiftData

/// Separador Receitas: todas as receitas, com categorias, filtros combinados e ordenação.
struct RecipesView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @AppStorage("homeSort") private var sort: RecipeSort = .newest
    /// Não são guardados: voltam ao início sempre que a app abre.
    @State private var category: RecipeCategory?
    @State private var filters = RecipeFilterSet()
    @State private var showingFilters = ScreenshotMode.flag("screenshotFilters")
    @State private var showingNewRecipe = false
    @State private var path = NavigationPath()
    @Namespace private var namespace

    private var results: [Recipe] {
        sort.sorted(recipes.filter { recipe in
            (category == nil || recipe.category == category) && filters.matches(recipe)
        })
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("Ainda sem receitas", systemImage: "fork.knife")
                    } description: {
                        Text("Guarda aqui as receitas que crias ou encontras nas redes sociais.")
                    } actions: {
                        Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    content
                }
            }
            .navigationTitle("Receitas")
            .toolbar { toolbarContent }
            .recipeDestinations(namespace)
            .sheet(isPresented: $showingNewRecipe) {
                RecipeEditorView()
            }
            .sheet(isPresented: $showingFilters) {
                RecipeFilterPanel(filters: $filters, recipes: recipes)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CategoryChips(selection: $category)

                if !filters.isEmpty {
                    activeFilters
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: category?.title ?? "Todas as receitas", trailing: Format.recipes(results.count))
                    if results.isEmpty {
                        ContentUnavailableView {
                            Label("Nada por aqui", systemImage: "line.3.horizontal.decrease.circle")
                        } description: {
                            Text(filters.isEmpty ? "Ainda não tens receitas nesta categoria." : "Nenhuma receita com estes filtros.")
                        } actions: {
                            if !filters.isEmpty || category != nil {
                                Button("Limpar filtros") {
                                    withAnimation(.snappy) {
                                        filters = RecipeFilterSet()
                                        category = nil
                                    }
                                }
                                .buttonStyle(.glass)
                            }
                        }
                        .padding(.top, 20)
                    } else {
                        RecipeGrid(recipes: results, namespace: namespace, source: "recipes")
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .animation(.snappy, value: filters)
    }

    /// Filtros ativos, cada um com um toque para o remover.
    private var activeFilters: some View {
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingFilters = true
            } label: {
                Label("Filtros", systemImage: filters.isEmpty
                      ? "line.3.horizontal.decrease"
                      : "line.3.horizontal.decrease.circle.fill")
            }
            .badge(filters.activeCount)
            Menu {
                Picker("Ordenar por", selection: $sort) {
                    ForEach(RecipeSort.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                Label("Ordenar", systemImage: "arrow.up.arrow.down")
            }
            Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
        }
    }
}
