import Foundation
import SwiftData

enum SampleData {
    @MainActor
    static func insert(into context: ModelContext) {
        let now = Date()
        for (offset, recipe) in makeRecipes().enumerated() {
            recipe.createdAt = now.addingTimeInterval(TimeInterval(-offset * 3600))
            recipe.updatedAt = recipe.createdAt
            context.insert(recipe)
        }
        try? context.save()
    }

    private static func ing(_ amount: Double?, _ unit: String, _ name: String) -> Ingredient {
        Ingredient(name: name, amount: amount, unit: unit)
    }

    private static func make(
        _ title: String,
        _ category: RecipeCategory,
        summary: String,
        servings: Int,
        prep: Int,
        cook: Int,
        macros: (kcal: Double, p: Double, c: Double, f: Double, fiber: Double),
        tags: [String],
        favorite: Bool = false,
        ingredients: [Ingredient],
        steps: [String],
        notes: String = ""
    ) -> Recipe {
        let recipe = Recipe(title: title, category: category)
        recipe.summary = summary
        recipe.servings = servings
        recipe.prepMinutes = prep
        recipe.cookMinutes = cook
        recipe.calories = macros.kcal
        recipe.protein = macros.p
        recipe.carbs = macros.c
        recipe.fat = macros.f
        recipe.fiber = macros.fiber
        recipe.tags = tags
        recipe.isFavorite = favorite
        recipe.ingredients = ingredients
        recipe.steps = steps.map { RecipeStep(text: $0) }
        recipe.notes = notes
        return recipe
    }

    private static func makeRecipes() -> [Recipe] {
        [
            make(
                "Panquecas proteicas de aveia e banana",
                .breakfast,
                summary: "Fofas, sem açúcar adicionado e prontas em 15 minutos.",
                servings: 2, prep: 5, cook: 10,
                macros: (310, 24, 38, 7, 5),
                tags: ["Alta proteína", "Rápida", "Vegetariana"],
                favorite: true,
                ingredients: [
                    ing(80, "g", "Flocos de aveia"),
                    ing(1, "un", "Banana madura"),
                    ing(2, "un", "Ovos"),
                    ing(100, "g", "Iogurte grego natural magro"),
                    ing(1, "c. chá", "Fermento em pó"),
                    ing(nil, "q.b.", "Canela"),
                ],
                steps: [
                    "Coloca todos os ingredientes no liquidificador e tritura até obteres uma massa homogénea.",
                    "Deixa a massa repousar 5 minutos para a aveia hidratar.",
                    "Aquece uma frigideira antiaderente em lume médio e unta com um fio de óleo.",
                    "Deita pequenas conchas de massa e cozinha 2 minutos de cada lado, até dourar.",
                    "Serve com fruta fresca e um fio de mel ou manteiga de amendoim.",
                ]
            ),
            make(
                "Bowl de frango teriyaki",
                .lunch,
                summary: "Clássico de meal prep: frango suculento, arroz e legumes crocantes.",
                servings: 2, prep: 10, cook: 15,
                macros: (480, 42, 52, 10, 6),
                tags: ["Alta proteína", "Meal prep"],
                favorite: true,
                ingredients: [
                    ing(300, "g", "Peito de frango em cubos"),
                    ing(120, "g", "Arroz basmati (cru)"),
                    ing(150, "g", "Brócolos"),
                    ing(1, "un", "Cenoura"),
                    ing(2, "c. sopa", "Molho de soja reduzido em sal"),
                    ing(1, "c. sopa", "Mel"),
                    ing(1, "c. chá", "Gengibre ralado"),
                    ing(1, "c. chá", "Amido de milho"),
                    ing(nil, "q.b.", "Sementes de sésamo"),
                ],
                steps: [
                    "Coze o arroz segundo as instruções da embalagem.",
                    "Coze os brócolos a vapor durante 4 minutos e corta a cenoura em palitos finos.",
                    "Salteia o frango numa frigideira quente até ficar dourado.",
                    "Mistura a soja, o mel, o gengibre, o amido e 3 colheres de água; junta ao frango e deixa engrossar.",
                    "Monta as taças com arroz, legumes e frango e finaliza com sésamo.",
                ],
                notes: "Aguenta 3 dias no frigorífico em caixas herméticas."
            ),
            make(
                "Salmão no forno com legumes",
                .dinner,
                summary: "Tudo num só tabuleiro, rico em ómega-3.",
                servings: 2, prep: 10, cook: 20,
                macros: (430, 34, 18, 24, 6),
                tags: ["Low carb", "Sem glúten"],
                ingredients: [
                    ing(2, "un", "Lombos de salmão (≈150 g)"),
                    ing(1, "un", "Curgete"),
                    ing(1, "un", "Pimento vermelho"),
                    ing(150, "g", "Tomate cherry"),
                    ing(1, "c. sopa", "Azeite"),
                    ing(1, "un", "Limão"),
                    ing(nil, "q.b.", "Sal, pimenta e orégãos"),
                ],
                steps: [
                    "Pré-aquece o forno a 200 °C.",
                    "Corta os legumes em pedaços, tempera com azeite, sal e orégãos e espalha num tabuleiro.",
                    "Leva ao forno 10 minutos.",
                    "Junta o salmão temperado com limão e pimenta e assa mais 10–12 minutos.",
                ]
            ),
            make(
                "Mousse de chocolate proteica",
                .dessert,
                summary: "Cremosa e com 20 g de proteína por taça.",
                servings: 2, prep: 5, cook: 0,
                macros: (190, 20, 14, 6, 3),
                tags: ["Alta proteína", "Rápida"],
                ingredients: [
                    ing(250, "g", "Skyr natural"),
                    ing(15, "g", "Cacau magro em pó"),
                    ing(15, "g", "Proteína whey de chocolate"),
                    ing(10, "g", "Chocolate negro 85%"),
                    ing(nil, "q.b.", "Adoçante a gosto"),
                ],
                steps: [
                    "Mistura o skyr com o cacau, a proteína e o adoçante até ficar liso.",
                    "Divide por duas taças e leva ao frigorífico 30 minutos.",
                    "Serve com raspas de chocolate negro.",
                ]
            ),
            make(
                "Batido verde proteico",
                .drink,
                summary: "Ideal para o pós-treino.",
                servings: 1, prep: 5, cook: 0,
                macros: (260, 28, 26, 5, 5),
                tags: ["Pós-treino", "Rápida"],
                ingredients: [
                    ing(250, "ml", "Bebida de amêndoa sem açúcar"),
                    ing(30, "g", "Proteína whey de baunilha"),
                    ing(1, "un", "Banana congelada"),
                    ing(30, "g", "Espinafres baby"),
                    ing(1, "c. chá", "Sementes de chia"),
                ],
                steps: [
                    "Coloca tudo no liquidificador.",
                    "Tritura durante 1 minuto até ficar cremoso e bebe de imediato.",
                ]
            ),
            make(
                "Bolinhas energéticas de tâmara e cacau",
                .snack,
                summary: "Snack sem forno para levar para o ginásio.",
                servings: 12, prep: 15, cook: 0,
                macros: (95, 3, 12, 4, 2),
                tags: ["Vegan", "Sem glúten", "Pré-treino"],
                ingredients: [
                    ing(150, "g", "Tâmaras sem caroço"),
                    ing(60, "g", "Amêndoas"),
                    ing(40, "g", "Flocos de aveia sem glúten"),
                    ing(2, "c. sopa", "Cacau em pó"),
                    ing(1, "c. sopa", "Manteiga de amendoim"),
                ],
                steps: [
                    "Demolha as tâmaras em água quente durante 10 minutos e escorre.",
                    "Tritura as amêndoas e a aveia até obteres uma farinha grossa.",
                    "Junta as tâmaras, o cacau e a manteiga de amendoim e tritura até formar uma massa.",
                    "Faz 12 bolinhas com as mãos e guarda no frigorífico.",
                ]
            ),
        ]
    }
}
