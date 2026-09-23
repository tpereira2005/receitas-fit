import SwiftUI

enum RecipeCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    // A ordem dos casos define a ordem em toda a app (filtros, Explorar e editor).
    case snack, iceCream, breakfast, lunch, dinner, dessert, drink, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Pequeno-almoço"
        case .lunch: "Almoço"
        case .dinner: "Jantar"
        case .snack: "Snacks"
        case .dessert: "Sobremesas"
        case .iceCream: "Gelados"
        case .drink: "Batidos"
        case .other: "Outras"
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sun.horizon.fill"
        case .lunch: "fork.knife"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        case .dessert: "birthday.cake.fill"
        case .iceCream: "snowflake"
        case .drink: "takeoutbag.and.cup.and.straw.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    /// Ícone desenhado para a app (quando não há um SF Symbol adequado).
    var assetName: String? {
        switch self {
        case .snack: "glyph.snack"
        default: nil
        }
    }

    var glyph: Image {
        assetName.map { Image($0) } ?? Image(systemName: symbol)
    }

    var color: Color {
        switch self {
        case .breakfast: .orange
        case .lunch: .green
        case .dinner: .indigo
        case .snack: .mint
        case .dessert: .pink
        case .iceCream: .cyan
        case .drink: .teal
        case .other: .gray
        }
    }
}

/// Filtros rápidos usados na pesquisa e nas coleções inteligentes.
enum QuickFilter: String, CaseIterable, Identifiable, Hashable {
    case highProtein, lowCalorie, quick, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highProtein: "Alta proteína"
        case .lowCalorie: "Até 400 kcal"
        case .quick: "Até 20 min"
        case .favorites: "Favoritas"
        }
    }

    var subtitle: String {
        switch self {
        case .highProtein: "25 g ou mais por porção"
        case .lowCalorie: "Leves, por porção"
        case .quick: "Prontas num instante"
        case .favorites: "As tuas preferidas"
        }
    }

    var symbol: String {
        switch self {
        case .highProtein: "bolt.fill"
        case .lowCalorie: "flame.fill"
        case .quick: "timer"
        case .favorites: "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .highProtein: .pink
        case .lowCalorie: .orange
        case .quick: .blue
        case .favorites: .red
        }
    }

    func matches(_ recipe: Recipe) -> Bool {
        switch self {
        case .highProtein: recipe.protein >= 25
        case .lowCalorie: recipe.calories > 0 && recipe.calories <= 400
        case .quick: recipe.totalMinutes > 0 && recipe.totalMinutes <= 20
        case .favorites: recipe.isFavorite
        }
    }
}

enum RecipeFilter: Hashable {
    case category(RecipeCategory)
    case tag(String)
    case quick(QuickFilter)

    var title: String {
        switch self {
        case .category(let category): category.title
        case .tag(let tag): tag
        case .quick(let filter): filter.title
        }
    }

    func matches(_ recipe: Recipe) -> Bool {
        switch self {
        case .category(let category): recipe.category == category
        case .tag(let tag): recipe.tags.contains(tag)
        case .quick(let filter): filter.matches(recipe)
        }
    }
}

enum RecipeSort: String, CaseIterable, Identifiable {
    case newest, oldest, name, calories, protein, time

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "Mais recentes"
        case .oldest: "Mais antigas"
        case .name: "Nome"
        case .calories: "Menos calorias"
        case .protein: "Mais proteína"
        case .time: "Mais rápidas"
        }
    }

    var symbol: String {
        switch self {
        case .newest: "clock"
        case .oldest: "clock.arrow.circlepath"
        case .name: "textformat"
        case .calories: "flame"
        case .protein: "bolt"
        case .time: "timer"
        }
    }

    func sorted(_ recipes: [Recipe]) -> [Recipe] {
        switch self {
        case .newest: recipes.sorted { $0.createdAt > $1.createdAt }
        case .oldest: recipes.sorted { $0.createdAt < $1.createdAt }
        case .name: recipes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .calories: recipes.sorted { $0.calories < $1.calories }
        case .protein: recipes.sorted { $0.protein > $1.protein }
        case .time: recipes.sorted { $0.totalMinutes < $1.totalMinutes }
        }
    }
}

/// Valor de navegação para abrir uma receita; `source` distingue a origem da animação de zoom.
struct RecipeRoute: Hashable {
    let recipe: Recipe
    var source: String = "grid"

    var transitionID: String { "\(source)-\(recipe.id.uuidString)" }
}
