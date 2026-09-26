import SwiftUI
import SwiftData

struct FilteredRecipesView: View {
    let filter: RecipeFilter
    let namespace: Namespace.ID

    @Query(filter: Recipe.notDeleted, sort: \Recipe.title) private var recipes: [Recipe]

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
