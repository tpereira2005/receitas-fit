import Foundation
import SwiftData

/// Filtros combinados do separador Receitas (painel de filtros).
/// Vivem só enquanto a app está aberta: não são guardados entre utilizações.
struct RecipeFilterSet: Equatable {
    var categories: Set<RecipeCategory> = []
    var quick: Set<QuickFilter> = []
    var tags: Set<String> = []
    var cooked: CookedFilter = .any
    var hideSamples = false

    enum CookedFilter: String, CaseIterable, Identifiable {
        case any, cooked, neverCooked

        var id: String { rawValue }

        var title: String {
            switch self {
            case .any: "Todas"
            case .cooked: "Já feitas"
            case .neverCooked: "Por fazer"
            }
        }
    }

    var isEmpty: Bool { self == RecipeFilterSet() }

    /// Número de critérios ativos (para o selo no botão de filtros).
    var activeCount: Int {
        categories.count + quick.count + tags.count + (cooked == .any ? 0 : 1) + (hideSamples ? 1 : 0)
    }

    /// Todas as condições têm de se verificar; dentro das categorias e das etiquetas basta uma.
    func matches(_ recipe: Recipe) -> Bool {
        if !categories.isEmpty && !categories.contains(recipe.category) { return false }
        if !quick.allSatisfy({ $0.matches(recipe) }) { return false }
        if !tags.isEmpty && tags.isDisjoint(with: recipe.tags) { return false }
        switch cooked {
        case .any: break
        case .cooked: if recipe.timesCooked == 0 { return false }
        case .neverCooked: if recipe.timesCooked > 0 { return false }
        }
        if hideSamples && recipe.isSample { return false }
        return true
    }

    /// Etiquetas curtas dos filtros ativos, para mostrar e remover um a um.
    var chips: [Chip] {
        var chips: [Chip] = []
        chips += categories.sorted { $0.order < $1.order }.map { Chip(id: "c-\($0.rawValue)", title: $0.title, remove: .category($0)) }
        chips += QuickFilter.allCases.filter(quick.contains).map { Chip(id: "q-\($0.rawValue)", title: $0.title, remove: .quick($0)) }
        chips += tags.sorted().map { Chip(id: "t-\($0)", title: $0, remove: .tag($0)) }
        if cooked != .any { chips.append(Chip(id: "cooked", title: cooked.title, remove: .cooked)) }
        if hideSamples { chips.append(Chip(id: "samples", title: "Sem exemplos", remove: .samples)) }
        return chips
    }

    struct Chip: Identifiable, Equatable {
        let id: String
        let title: String
        let remove: Removal
    }

    enum Removal: Equatable {
        case category(RecipeCategory), quick(QuickFilter), tag(String), cooked, samples
    }

    mutating func remove(_ removal: Removal) {
        switch removal {
        case .category(let category): categories.remove(category)
        case .quick(let filter): quick.remove(filter)
        case .tag(let tag): tags.remove(tag)
        case .cooked: cooked = .any
        case .samples: hideSamples = false
        }
    }
}

extension RecipeCategory {
    /// Posição na ordem da app (a ordem dos casos).
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

// MARK: - Pesquisa

extension Recipe {
    /// Relevância para a pesquisa: o título conta mais do que ingredientes, etiquetas ou notas.
    /// `nil` quando a receita não corresponde.
    func searchScore(_ query: String) -> Int? {
        let tokens = query.searchNormalized.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return 0 }
        guard matches(query: query) else { return nil }
        let title = self.title.searchNormalized
        let tagText = tags.joined(separator: " ").searchNormalized
        let ingredientText = ingredients.map(\.name).joined(separator: " ").searchNormalized
        var score = 0
        for token in tokens {
            if title.hasPrefix(token) { score += 6 }
            else if title.split(separator: " ").contains(where: { $0.hasPrefix(token) }) { score += 4 }
            else if title.contains(token) { score += 3 }
            if tagText.contains(token) { score += 2 }
            if ingredientText.contains(token) { score += 1 }
        }
        return score
    }
}

extension Food {
    func matches(query: String) -> Bool {
        let tokens = query.searchNormalized.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty else { return false }
        let index = "\(name) \(brand) \(category.title)".searchNormalized
        return tokens.allSatisfy { index.contains($0) }
    }
}

/// Pesquisas recentes (as últimas 8), guardadas entre utilizações.
enum RecentSearches {
    private static let key = "recentSearches"
    static let limit = 8

    static var all: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ query: String) {
        let trimmed = query.trimmed
        guard trimmed.count >= 2 else { return }
        var list = all.filter { $0.searchNormalized != trimmed.searchNormalized }
        list.insert(trimmed, at: 0)
        UserDefaults.standard.set(Array(list.prefix(limit)), forKey: key)
    }

    static func remove(_ query: String) {
        UserDefaults.standard.set(all.filter { $0 != query }, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Etiquetas

/// Operações sobre as etiquetas de todas as receitas (gestão nas Definições).
enum TagLibrary {
    /// Etiquetas em uso, com o número de receitas, das mais usadas para as menos.
    static func counts(in recipes: [Recipe]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for recipe in recipes {
            for tag in Set(recipe.tags) { counts[tag, default: 0] += 1 }
        }
        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.tag.localizedStandardCompare($1.tag) == .orderedAscending : $0.count > $1.count }
    }

    /// Muda o nome de uma etiqueta em todas as receitas. Se o novo nome já existir, as duas juntam-se.
    @discardableResult
    static func rename(_ tag: String, to newName: String, in recipes: [Recipe]) -> Int {
        let name = newName.trimmed
        guard !name.isEmpty, name != tag else { return 0 }
        var changed = 0
        for recipe in recipes where recipe.tags.contains(tag) {
            var tags = recipe.tags.map { $0 == tag ? name : $0 }
            var seen = Set<String>()
            tags = tags.filter { seen.insert($0).inserted }
            recipe.tags = tags
            changed += 1
        }
        return changed
    }

    /// Tira a etiqueta de todas as receitas (as receitas não são apagadas).
    @discardableResult
    static func delete(_ tag: String, in recipes: [Recipe]) -> Int {
        var changed = 0
        for recipe in recipes where recipe.tags.contains(tag) {
            recipe.tags.removeAll { $0 == tag }
            changed += 1
        }
        return changed
    }
}
