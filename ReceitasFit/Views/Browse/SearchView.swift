import SwiftUI
import SwiftData

/// Pesquisa de receitas e alimentos, com as mesmas categorias e filtros do separador Receitas.
/// Os resultados vêm por relevância: primeiro o que tem a palavra no título.
struct SearchView: View {
    @Binding var searchText: String

    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query(sort: \Food.name) private var foods: [Food]
    @State private var category: RecipeCategory?
    @State private var filters = RecipeFilterSet()
    @State private var showingFilters = false
    @State private var recent = RecentSearches.all
    @Namespace private var namespace

    private var query: String { searchText.trimmed }
    private var isFiltering: Bool { category != nil || !filters.isEmpty }
    private var isIdle: Bool { query.isEmpty && !isFiltering }

    private struct Scored {
        let recipe: Recipe
        let score: Int
    }

    private var recipeResults: [Recipe] {
        var scored: [Scored] = []
        for recipe in recipes where (category == nil || recipe.category == category) && filters.matches(recipe) {
            if let score = recipe.searchScore(query) {
                scored.append(Scored(recipe: recipe, score: score))
            }
        }
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.recipe.title.localizedStandardCompare(b.recipe.title) == .orderedAscending
        }
        return scored.map(\.recipe)
    }

    private var foodResults: [Food] {
        guard !query.isEmpty, !isFiltering else { return [] }
        return foods.filter { $0.matches(query: query) }
    }

    private var popularTags: [String] {
        TagLibrary.counts(in: recipes).prefix(12).map(\.tag)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        CategoryChips(selection: $category, recipes: recipes)
                        if !filters.isEmpty {
                            ActiveFilterChips(filters: $filters)
                        }
                    }

                    if isIdle {
                        idleContent
                    } else if recipeResults.isEmpty && foodResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else {
                        results
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Pesquisar")
            .searchable(text: $searchText, prompt: "Receitas, alimentos, etiquetas…")
            .onSubmit(of: .search) { remember(query) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    FilterToolbarButton(filters: filters) { showingFilters = true }
                }
            }
            .sheet(isPresented: $showingFilters) {
                RecipeFilterPanel(filters: $filters, recipes: recipes.filter { category == nil || $0.category == category })
            }
            .animation(.snappy, value: filters)
            .animation(.snappy, value: category)
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, namespace: namespace)
            }
            .recipeDestinations(namespace)
        }
    }

    // MARK: - Resultados

    @ViewBuilder
    private var results: some View {
        if !recipeResults.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Receitas", trailing: Format.recipes(recipeResults.count))
                RecipeGrid(recipes: recipeResults, namespace: namespace, source: "search")
            }
            .simultaneousGesture(TapGesture().onEnded { remember(query) })
        }

        if !foodResults.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Alimentos", trailing: foodResults.count == 1 ? "1 alimento" : "\(foodResults.count) alimentos")
                VStack(spacing: 0) {
                    ForEach(foodResults) { food in
                        NavigationLink(value: food) {
                            FoodRow(food: food)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { remember(query) })
                        if food.id != foodResults.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    private func remember(_ text: String) {
        guard !text.isEmpty else { return }
        RecentSearches.add(text)
        recent = RecentSearches.all
    }

    // MARK: - Sem pesquisa

    @ViewBuilder
    private var idleContent: some View {
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Recentes").font(.title3.bold())
                    Spacer()
                    Button("Limpar") {
                        withAnimation {
                            RecentSearches.clear()
                            recent = []
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(recent, id: \.self) { item in
                        HStack(spacing: 12) {
                            Button {
                                searchText = item
                            } label: {
                                Label(item, systemImage: "clock.arrow.circlepath")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Button {
                                withAnimation {
                                    RecentSearches.remove(item)
                                    recent = RecentSearches.all
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remover “\(item)”")
                        }
                        .padding(.vertical, 11)
                        if item != recent.last {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }

        if !popularTags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Etiquetas populares")
                FlowLayout(spacing: 8) {
                    ForEach(popularTags, id: \.self) { tag in
                        Button {
                            searchText = tag
                        } label: {
                            Label(tag, systemImage: "tag")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(.tertiarySystemFill), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }

        if !recipes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Todas de A a Z", trailing: Format.recipes(recipes.count))
                LazyVStack(spacing: 0) {
                    ForEach(recipes) { recipe in
                        RecipeListItem(recipe: recipe)
                        if recipe.id != recipes.last?.id {
                            Divider().padding(.leading, 74)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
