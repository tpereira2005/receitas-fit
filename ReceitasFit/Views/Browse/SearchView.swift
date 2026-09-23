import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var searchText: String

    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @State private var filters: Set<QuickFilter> = []
    @Namespace private var namespace

    private var isIdle: Bool { searchText.trimmed.isEmpty && filters.isEmpty }

    private var results: [Recipe] {
        recipes.filter { recipe in
            recipe.matches(query: searchText) && filters.allSatisfy { $0.matches(recipe) }
        }
    }

    private var popularTags: [String] {
        var counts: [String: Int] = [:]
        for recipe in recipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(12)
            .map(\.key)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    filterChips

                    if isIdle {
                        idleContent
                    } else if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Resultados", trailing: Format.recipes(results.count))
                            RecipeGrid(recipes: results, namespace: namespace, source: "search")
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Pesquisar")
            .recipeDestinations(namespace)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(QuickFilter.allCases) { filter in
                        let isOn = filters.contains(filter)
                        Button {
                            withAnimation(.snappy) {
                                if isOn { filters.remove(filter) } else { filters.insert(filter) }
                            }
                        } label: {
                            Label(filter.title, systemImage: filter.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? .regular.tint(filter.color).interactive() : .regular.interactive(), in: .capsule)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var idleContent: some View {
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
                        NavigationLink(value: RecipeRoute(recipe: recipe, source: "list")) {
                            RecipeRow(recipe: recipe)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
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
