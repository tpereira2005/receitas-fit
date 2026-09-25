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
            recipe.isSample = true
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

    // MARK: - Receitas base

    /// Quantidade de um ingrediente das receitas base: uma unidade comum ou uma porção com nome do alimento.
    private struct Amount {
        var value: Double?
        var unit: IngredientUnit
        var portion: String?

        static func g(_ value: Double) -> Amount { Amount(value: value, unit: .gram) }
        static func ml(_ value: Double) -> Amount { Amount(value: value, unit: .milliliter) }
        static func un(_ value: Double) -> Amount { Amount(value: value, unit: .unit) }
        static func portion(_ value: Double, _ name: String) -> Amount { Amount(value: value, unit: .unit, portion: name) }
        static let toTaste = Amount(value: nil, unit: .toTaste)
    }

    private typealias Line = (food: String, amount: Amount)

    /// Receitas que já vêm com a app, sem o selo "Exemplo": são receitas a sério e ficam como as do utilizador.
    private struct BaseRecipe {
        let title: String
        let category: RecipeCategory
        let summary: String
        let servings: Int
        let prep: Int
        let cook: Int
        let tags: [String]
        var favorite = false
        var source = ""
        let lines: [Line]
        let steps: [String]
        var notes = ""
    }

    /// Insere as receitas base que ainda não existem (compara pelo título) e só os alimentos de origem
    /// de que precisam e que faltem na biblioteca. Devolve quantas receitas foram criadas.
    @MainActor
    @discardableResult
    static func insertBase(into context: ModelContext) -> Int {
        let existingTitles = Set(((try? context.fetch(FetchDescriptor<Recipe>())) ?? []).map(\.title.searchNormalized))
        let missing = baseRecipes.filter { !existingTitles.contains($0.title.searchNormalized) }
        guard !missing.isEmpty else { return 0 }

        let needed = Set(missing.flatMap { $0.lines.map(\.food) })
        let foodsByName = FoodLibrary.insertMissingDefaults(in: context, only: needed)
        let foodIndex = NutritionCalculator.index(Array(foodsByName.values))
        let now = Date()

        for (offset, base) in missing.enumerated() {
            let recipe = Recipe(title: base.title, category: base.category)
            recipe.summary = base.summary
            recipe.servings = base.servings
            recipe.prepMinutes = base.prep
            recipe.cookMinutes = base.cook
            recipe.tags = base.tags
            recipe.isFavorite = base.favorite
            recipe.sourceURL = base.source
            recipe.notes = base.notes
            recipe.ingredients = base.lines.map { ingredient($0, foods: foodsByName) }
            recipe.steps = base.steps.map { RecipeStep(text: $0) }
            // Pela ordem da lista: a primeira fica a mais recente.
            recipe.createdAt = now.addingTimeInterval(TimeInterval(-offset * 60))
            recipe.updatedAt = recipe.createdAt
            NutritionCalculator.update(recipe, foods: foodIndex)
            context.insert(recipe)
        }
        try? context.save()
        return missing.count
    }

    private static func ingredient(_ line: Line, foods: [String: Food]) -> Ingredient {
        let amount = line.amount
        guard let food = foods[line.food.searchNormalized] else {
            return Ingredient(name: line.food, amount: amount.value, unit: amount.portion ?? amount.unit.rawValue)
        }
        if let name = amount.portion, let portion = food.portions.first(where: { $0.name == name }) {
            return Ingredient(food: food, amount: amount.value, measure: .portion(portion))
        }
        return Ingredient(food: food, amount: amount.value, unit: amount.unit)
    }

    /// Títulos das receitas base.
    static var baseTitles: [String] { baseRecipes.map(\.title) }

    private static let creamiTags = ["Ninja CREAMi", "Alta proteína"]
    private static let untestedNote = "Proposta ainda por testar. Os valores nutricionais são calculados a partir dos ingredientes."

    private static let baseRecipes: [BaseRecipe] = [
        BaseRecipe(
            title: "Gelado Biscoff",
            category: .iceCream,
            summary: "Base de leite proteico com canela e pedaços estaladiços de Biscoff.",
            servings: 2, prep: 10, cook: 0,
            tags: creamiTags,
            lines: [
                ("Leite Proteína", .ml(375)),
                ("Leite magro", .ml(225)),
                ("Adoçante líquido (sucralose)", .toTaste),
                ("Canela", .g(2)),
                ("Sal", .g(0.5)),
                ("Goma xantana", .g(1)),
                ("Lotus Biscoff", .portion(3, "bolacha")),
            ],
            steps: [
                "Mistura os dois leites, o adoçante, a canela, o sal e a goma xantana com a varinha mágica até obteres uma base homogénea.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Coloca também as três bolachas Biscoff no congelador.",
                "Antes de processar, confirma que a superfície está mais ou menos plana. Se tiver um bico no centro, nivela com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM.",
                "Passa uma faca pelos lados do gelado e repete TOP ou BOTTOM → LITE ICE CREAM.",
                "Esmaga as bolachas congeladas em pedaços e junta-as ao gelado.",
            ],
            notes: "Rende 2 doses. Valor registado antes por dose: 190 kcal, 23,2 g de proteína, 1,9 g de gordura e 20,4 g de hidratos."
        ),
        BaseRecipe(
            title: "Gelado Oreo",
            category: .iceCream,
            summary: "Cookies & cream leve, com Oreo partida no fim.",
            servings: 2, prep: 10, cook: 0,
            tags: creamiTags,
            lines: [
                ("Leite Proteína", .ml(275)),
                ("Leite magro", .ml(275)),
                ("Água", .ml(50)),
                ("Adoçante líquido (sucralose)", .toTaste),
                ("Goma xantana", .g(1)),
                ("Aroma de baunilha", .ml(5)),
                ("Sal", .g(0.5)),
                ("Oreo sem recheio", .g(20)),
            ],
            steps: [
                "Mistura os leites, a água, o adoçante, a goma xantana, a baunilha e o sal com a varinha mágica até obteres uma base homogénea.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Coloca também as Oreo sem recheio no congelador.",
                "Antes de processar, confirma a superfície e, se for preciso, nivela-a com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM.",
                "Passa uma faca pelos lados do gelado e repete TOP ou BOTTOM → LITE ICE CREAM.",
                "Parte as Oreo congeladas, junta-as ao gelado e seleciona MIX-IN.",
            ],
            notes: "Rende 2 doses. Valor registado antes por dose: 225 kcal, 19,4 g de proteína, 4,3 g de gordura e 27,7 g de hidratos."
        ),
        BaseRecipe(
            title: "Gelado de mirtilos e baunilha",
            category: .iceCream,
            summary: "Iogurte proteico com mirtilos na base e por cima.",
            servings: 1, prep: 10, cook: 0,
            tags: creamiTags + ["Por testar"],
            lines: [
                ("Iogurte Natural +Proteínas", .un(2)),
                ("Leite magro", .ml(120)),
                ("Mirtilos", .g(150)),
                ("Aroma de baunilha", .toTaste),
                ("Adoçante líquido (sucralose)", .toTaste),
                ("Goma xantana", .g(0.4)),
            ],
            steps: [
                "Tritura os iogurtes, o leite, 100 g de mirtilos, a baunilha, o adoçante e a goma xantana com a varinha mágica até ficar liso.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Antes de processar, confirma a superfície e, se for preciso, nivela-a com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM.",
                "Se ficar farinhento, junta 1 colher de sopa de leite e usa RE-SPIN.",
                "Serve com os restantes 50 g de mirtilos por cima.",
            ],
            notes: untestedNote
        ),
        BaseRecipe(
            title: "Gelado de banana e aveia",
            category: .iceCream,
            summary: "Sabe a papas de aveia geladas, com banana e canela.",
            servings: 1, prep: 15, cook: 0,
            tags: creamiTags + ["Por testar"],
            lines: [
                ("Iogurte Natural +Proteínas", .un(2)),
                ("Leite magro", .ml(80)),
                ("Banana", .g(100)),
                ("Flocos de aveia", .g(25)),
                ("Aroma de baunilha", .toTaste),
                ("Canela", .toTaste),
                ("Adoçante líquido (sucralose)", .toTaste),
                ("Goma xantana", .g(0.4)),
            ],
            steps: [
                "Mistura a aveia com o leite e deixa hidratar 10 minutos.",
                "Junta os iogurtes, a banana, a baunilha, a canela, o adoçante e a goma xantana e tritura com a varinha mágica até ficar liso.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Antes de processar, confirma a superfície e, se for preciso, nivela-a com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM.",
                "Se ficar farinhento, junta 1 colher de sopa de leite e usa RE-SPIN.",
            ],
            notes: "Goma xantana: 0,3 a 0,4 g. " + untestedNote
        ),
        BaseRecipe(
            title: "Gelado de chocolate e avelã",
            category: .iceCream,
            summary: "Chocolate intenso, com avelãs e pedaços de chocolate negro.",
            servings: 1, prep: 10, cook: 0,
            tags: creamiTags + ["Por testar"],
            lines: [
                ("Iogurte Natural +Proteínas", .un(2)),
                ("Leite magro", .ml(100)),
                ("Cacau magro em pó", .g(5)),
                ("Avelãs", .g(15)),
                ("Chocolate Negro 70%", .g(10)),
                ("Aroma de baunilha", .toTaste),
                ("Adoçante líquido (sucralose)", .toTaste),
                ("Goma xantana", .g(0.4)),
            ],
            steps: [
                "Tritura os iogurtes, o leite, o cacau, a baunilha, o adoçante e a goma xantana com a varinha mágica até ficar liso.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Pica grosseiramente as avelãs e o chocolate e guarda-os no congelador.",
                "Antes de processar, confirma a superfície e, se for preciso, nivela-a com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM. Se ficar farinhento, usa RE-SPIN.",
                "Faz um buraco no centro, junta as avelãs e o chocolate e seleciona MIX-IN.",
            ],
            notes: untestedNote
        ),
        BaseRecipe(
            title: "Gelado de melão e chia",
            category: .iceCream,
            summary: "Fresco e leve, com melão e sementes de chia.",
            servings: 1, prep: 15, cook: 0,
            tags: creamiTags + ["Por testar"],
            lines: [
                ("Iogurte Natural +Proteínas", .un(2)),
                ("Leite magro", .ml(80)),
                ("Melão", .g(180)),
                ("Sementes de chia", .g(10)),
                ("Aroma de baunilha", .toTaste),
                ("Adoçante líquido (sucralose)", .toTaste),
            ],
            steps: [
                "Tritura os iogurtes, o leite, 120 g de melão, a baunilha e o adoçante com a varinha mágica até ficar liso.",
                "Junta as sementes de chia inteiras, mexe com uma colher e deixa repousar 10 minutos.",
                "Verte para o copo Deluxe sem passar a linha MAX FILL. Tapa e congela numa superfície plana durante pelo menos 24 horas.",
                "Antes de processar, confirma a superfície e, se for preciso, nivela-a com uma colher.",
                "Monta o copo e seleciona TOP ou BOTTOM → LITE ICE CREAM. Se ficar farinhento, usa RE-SPIN.",
                "Serve com os restantes 60 g de melão em cubos por cima.",
            ],
            notes: "Sem goma xantana na primeira experiência. " + untestedNote
        ),
        BaseRecipe(
            title: "Cookie Dough Cake",
            category: .snack,
            summary: "Bolo proteico de banana e iogurte com pepitas de chocolate, para comer frio.",
            servings: 2, prep: 10, cook: 30,
            tags: ["Alta proteína"],
            favorite: true,
            source: "https://vm.tiktok.com/ZGdQGjsMx",
            lines: [
                ("Banana", .g(60)),
                ("Iogurte Natural +Proteínas", .un(2)),
                ("Select Protein Powder Gourmet Vanilla", .portion(1, "scoop")),
                ("Ovo", .un(2)),
                ("Amido de milho", .g(5)),
                ("Fermento em pó", .g(4)),
                ("Stevia + Eritritol 1:1", .g(15)),
                ("Aroma de baunilha", .ml(5)),
                ("Sal", .g(0.5)),
                ("Chocolate Negro 70%", .g(10)),
            ],
            steps: [
                "Pré-aquece o forno a 170 °C.",
                "Coloca os 60 g de banana numa taça e esmaga-a muito bem com um garfo, até praticamente formar um puré.",
                "Adiciona as 2 embalagens de iogurte e mistura com a banana.",
                "Junta os 2 ovos e mexe bem até obteres uma mistura homogénea.",
                "Acrescenta os 15 g de adoçante, os 5 ml de aroma de baunilha e uma pequena pitada de sal. Mistura novamente.",
                "Noutra taça pequena, mistura os ingredientes secos: 30 g de whey, 5 g de amido de milho e 4 g de fermento.",
                "Junta gradualmente os ingredientes secos à mistura líquida. Mexe apenas até ficar completamente homogéneo.",
                "Transfere tudo para o recipiente que vai ao forno.",
                "Junta 10 g de pepitas de chocolate à massa e envolve-as.",
                "Leva ao forno durante 30 minutos.",
                "Retira do forno e deixa repousar 30 minutos.",
                "Coloca no frigorífico durante 2 horas antes de comer.",
            ]
        ),
    ]

    // MARK: - Receitas de exemplo

    /// Títulos das receitas de exemplo (atuais e de versões anteriores da app).
    static let titles: Set<String> = Set(samples.map(\.title)).union([
        "Panquecas proteicas de aveia e banana",
        "Bowl de frango teriyaki",
        "Salmão no forno com legumes",
        "Mousse de chocolate proteica",
        "Batido verde proteico",
        "Bolinhas energéticas de tâmara e cacau",
        "Gelado proteico de banana e amendoim",
    ])

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
                ("Cacau magro em pó", 15, .gram),
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
                ("Cacau magro em pó", 2, .tablespoon),
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
