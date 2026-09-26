import Foundation

nonisolated enum Format {
    static func minutes(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// Versão curta para cartões e listas: "2 h 30" em vez de "2 h 30 min".
    static func shortMinutes(_ minutes: Int) -> String {
        guard minutes >= 60, minutes % 60 != 0 else { return self.minutes(minutes) }
        return "\(minutes / 60) h \(minutes % 60)"
    }

    /// "Faltam 3 h", "Falta 1 h", "Faltam 45 min".
    static func remaining(_ minutes: Int) -> String {
        let text = self.minutes(minutes)
        return text.hasPrefix("1 ") ? "Falta \(text)" : "Faltam \(text)"
    }

    /// "hoje", "ontem", "há 3 dias", "há 2 semanas" ou a data ("12 set.").
    nonisolated static func relativeDay(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "hoje"
        case 1: return "ontem"
        case 2..<7: return "há \(days) dias"
        case 7..<14: return "há 1 semana"
        case 14..<35: return "há \(days / 7) semanas"
        default:
            let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
            return date.formatted(sameYear ? .dateTime.day().month(.abbreviated) : .dateTime.day().month(.abbreviated).year())
        }
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
    /// Uma casa decimal; abaixo de 1 usa duas, para que valores pequenos (sal, p. ex.) não fiquem arredondados a 0.
    nonisolated var cleanString: String {
        let digits = abs(self) < 1 && self != 0 ? 2 : 1
        return formatted(.number.precision(.fractionLength(0...digits)))
    }
}

extension String {
    /// Primeira letra em maiúscula ("quarta-feira, 24…" → "Quarta-feira, 24…").
    nonisolated var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }

    nonisolated var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Versão sem acentos e em minúsculas, para pesquisa ("Proteína" → "proteina").
    nonisolated var searchNormalized: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "pt_PT"))
    }
}
