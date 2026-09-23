import Foundation

enum Format {
    static func minutes(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    static func servings(_ count: Int) -> String {
        count == 1 ? "1 porção" : "\(count) porções"
    }

    static func recipes(_ count: Int) -> String {
        count == 1 ? "1 receita" : "\(count) receitas"
    }
}

extension Double {
    /// Número sem casas decimais desnecessárias ("12" em vez de "12,0").
    var cleanString: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Versão sem acentos e em minúsculas, para pesquisa ("Proteína" → "proteina").
    var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
    }
}
