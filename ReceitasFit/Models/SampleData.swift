import Foundation
import SwiftData

enum SampleData {
    private typealias Item = (food: String, amount: Double?, unit: IngredientUnit)

    private struct Sample {
        let title: String
        let category: RecipeCategory
        let summary: String
        let servings: Int
        let prep: Int
        let cook: Int
        let tags: [String]
        var favorite = false
        let items: [Item]
        let steps: [String]
        var notes = ""
    }

    /// Insere as receitas de exemplo (e os alimentos de que precisam). Devolve quantas foram criadas.
    @MainActor
    @discardableResult
    static func insert(into context: ModelContext) -> Int {
        let foodsByName = FoodLibrary.insertMissingDefaults(in: context)
        let foodIndex = NutritionCalculator.index(Array(foodsByName.values))
        let now = Date()

        for (offset, sample) in samples.enumerated() {
            let recipe = Recipe(title: sample.title, category: sample.category)
            recipe.summary = sample.summary
            recipe.servings = sample.servings
            recipe.prepMinutes = sample.prep
            recipe.cookMinutes = sample.cook
            recipe.tags = sample.tags
            recipe.isFavorite = sample.favorite
            recipe.notes = sample.notes
            recipe.ingredients = sample.items.map { item in
                if let food = foodsByName[item.food.searchNormalized] {
                    return Ingredient(food: food, amount: item.amount, unit: item.unit)
                }
                return Ingredient(name: item.food, amount: item.amount, unit: item.unit.rawValue)
            }
            recipe.steps = sample.steps.map { RecipeStep(text: $0) }
            recipe.createdAt = now.addingTimeInterval(TimeInterval(-offset * 3600))
            recipe.updatedAt = recipe.createdAt
            NutritionCalculator.update(recipe, foods: foodIndex)
            context.insert(recipe)
        }
        try? context.save()
        return samples.count
    }

    private static let samples: [Sample] = [
        Sample(
            title: "Panquecas proteicas de aveia e banana",
            category: .breakfast,
            summary: "Fofas, sem açúcar adicionado e prontas em 15 minutos.",
            servings: 2, prep: 5, cook: 10,
            tags: ["Alta proteína", "Rápida"],
            favorite: true,
            items: [
                ("Flocos de aveia", 80, .gram),
                ("Banana", 1, .unit),
                ("Ovo", 2, .unit),
                ("Iogurte grego natural magro", 100, .gram),
                ("Fermento em pó", 1, .teaspoon),
                ("Canela", nil, .toTaste),
            ],
            steps: [
                "Coloca todos os ingredientes no liquidificador e tritura até obteres uma massa homogénea.",
                "Deixa a massa repousar 5 minutos para a aveia hidratar.",
                "Aquece uma frigideira antiaderente em lume médio e unta com um fio de óleo.",
                "Deita pequenas conchas de massa e cozinha 2 minutos de cada lado, até dourar.",
                "Serve com fruta fresca e um fio de mel ou manteiga de amendoim.",
            ]
        ),
        Sample(
            title: "Bowl de frango teriyaki",
            category: .lunch,
            summary: "Clássico de meal prep: frango suculento, arroz e legumes crocantes.",
            servings: 2, prep: 10, cook: 15,
            tags: ["Alta proteína", "Meal prep"],
            favorite: true,
            items: [
                ("Peito de frango", 300, .gram),
                ("Arroz basmati", 120, .gram),
                ("Brócolos", 150, .gram),
                ("Cenoura", 1, .unit),
                ("Molho de soja reduzido em sal", 2, .tablespoon),
                ("Mel", 1, .tablespoon),
                ("Gengibre ralado", 1, .teaspoon),
                ("Amido de milho", 1, .teaspoon),
                ("Sementes de sésamo", 5, .gram),
            ],
            steps: [
                "Coze o arroz segundo as instruções da embalagem.",
                "Coze os brócolos a vapor durante 4 minutos e corta a cenoura em palitos finos.",
                "Salteia o frango em cubos numa frigideira quente até ficar dourado.",
                "Mistura a soja, o mel, o gengibre, o amido e 3 colheres de água; junta ao frango e deixa engrossar.",
                "Monta as taças com arroz, legumes e frango e finaliza com sésamo.",
            ],
            notes: "Aguenta 3 dias no frigorífico em caixas herméticas."
        ),
        Sample(
            title: "Salmão no forno com legumes",
            category: .dinner,
            summary: "Tudo num só tabuleiro, rico em ómega-3.",
            servings: 2, prep: 10, cook: 20,
            tags: ["Low carb"],
            items: [
                ("Lombo de salmão", 2, .unit),
                ("Curgete", 1, .unit),
                ("Pimento vermelho", 1, .unit),
                ("Tomate cherry", 150, .gram),
                ("Azeite", 1, .tablespoon),
                ("Limão", 1, .unit),
                ("Sal", nil, .toTaste),
                ("Orégãos secos", nil, .toTaste),
            ],
            steps: [
                "Pré-aquece o forno a 200 °C.",
                "Corta os legumes em pedaços, tempera com azeite, sal e orégãos e espalha num tabuleiro.",
                "Leva ao forno 10 minutos.",
                "Junta o salmão temperado com limão e assa mais 10–12 minutos.",
            ]
        ),
        Sample(
            title: "Mousse de chocolate proteica",
            category: .dessert,
            summary: "Cremosa e com mais de 20 g de proteína por taça.",
            servings: 2, prep: 5, cook: 0,
            tags: ["Alta proteína", "Rápida"],
            items: [
                ("Skyr natural", 250, .gram),
                ("Cacau em pó magro", 15, .gram),
                ("Proteína whey de chocolate", 15, .gram),
                ("Chocolate negro 85%", 10, .gram),
                ("Adoçante", nil, .toTaste),
            ],
            steps: [
                "Mistura o skyr com o cacau, a proteína e o adoçante até ficar liso.",
                "Divide por duas taças e leva ao frigorífico 30 minutos.",
                "Serve com raspas de chocolate negro.",
            ]
        ),
        Sample(
            title: "Gelado proteico de banana e amendoim",
            category: .iceCream,
            summary: "“Nice cream” cremoso, sem máquina de gelados.",
            servings: 2, prep: 10, cook: 0,
            tags: ["Alta proteína", "Pós-treino"],
            items: [
                ("Banana", 2, .unit),
                ("Skyr natural", 150, .gram),
                ("Proteína whey de baunilha", 1, .unit),
                ("Manteiga de amendoim", 20, .gram),
                ("Canela", nil, .toTaste),
            ],
            steps: [
                "Corta as bananas às rodelas e congela durante pelo menos 4 horas.",
                "Tritura a banana congelada com o skyr e a proteína até ficar cremoso, raspando as paredes do copo.",
                "Junta a manteiga de amendoim e envolve só um pouco, para ficar marmoreado.",
                "Serve logo ou leva ao congelador 30 minutos para ficar mais firme.",
            ]
        ),
        Sample(
            title: "Batido verde proteico",
            category: .drink,
            summary: "Ideal para o pós-treino.",
            servings: 1, prep: 5, cook: 0,
            tags: ["Pós-treino", "Rápida"],
            items: [
                ("Bebida de amêndoa sem açúcar", 250, .milliliter),
                ("Proteína whey de baunilha", 1, .unit),
                ("Banana", 1, .unit),
                ("Espinafres baby", 30, .gram),
                ("Sementes de chia", 1, .teaspoon),
            ],
            steps: [
                "Coloca tudo no liquidificador.",
                "Tritura durante 1 minuto até ficar cremoso e bebe de imediato.",
            ]
        ),
        Sample(
            title: "Bolinhas energéticas de tâmara e cacau",
            category: .snack,
            summary: "Snack sem forno para levar para o ginásio.",
            servings: 12, prep: 15, cook: 0,
            tags: ["Pré-treino"],
            items: [
                ("Tâmaras sem caroço", 150, .gram),
                ("Amêndoas", 60, .gram),
                ("Flocos de aveia", 40, .gram),
                ("Cacau em pó magro", 2, .tablespoon),
                ("Manteiga de amendoim", 1, .tablespoon),
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
