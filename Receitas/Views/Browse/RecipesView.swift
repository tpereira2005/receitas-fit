import SwiftUI
import SwiftData

/// Separador Receitas: todas as receitas, com categorias, filtros combinados e ordenação.
struct RecipesView: View {
    @Query(filter: Recipe.notDeleted, sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
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
                RecipeFilterPanel(filters: $filters, recipes: recipes.filter { category == nil || $0.category == category })
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CategoryChips(selection: $category, recipes: recipes)

                if !filters.isEmpty {
                    ActiveFilterChips(filters: $filters)
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            FilterToolbarButton(filters: filters) { showingFilters = true }
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
