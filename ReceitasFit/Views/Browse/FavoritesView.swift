import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(filter: #Predicate<Recipe> { $0.isFavorite == true }, sort: \Recipe.title)
    private var favorites: [Recipe]
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "Sem favoritas",
                        systemImage: "heart",
                        description: Text("Toca no coração de uma receita para a teres sempre à mão.")
                    )
                } else {
                    ScrollView {
                        RecipeGrid(recipes: favorites, namespace: namespace, source: "favorites")
                            .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Favoritas")
            .recipeDestinations(namespace)
        }
    }
}

struct FilteredRecipesView: View {
    let filter: RecipeFilter
    let namespace: Namespace.ID

    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    private var results: [Recipe] { recipes.filter { filter.matches($0) } }

    var body: some View {
        Group {
            if results.isEmpty {
                ContentUnavailableView(
                    "Sem receitas",
                    systemImage: "tray",
                    description: Text("Ainda não há receitas em “\(filter.title)”.")
                )
            } else {
                ScrollView {
                    RecipeGrid(recipes: results, namespace: namespace, source: "filter")
                        .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(filter.title)
    }
}
