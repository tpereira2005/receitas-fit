import Foundation
import Observation
import UIKit
import UserNotifications

// MARK: - Progresso guardado

/// Ingredientes e passos marcados numa receita. Ficam guardados durante 12 horas
/// (sair da receita a meio não perde nada) ou até "Fiz esta receita".
nonisolated struct CookingProgress: Codable, Equatable, Sendable {
    var ingredients: Set<UUID> = []
    var steps: Set<UUID> = []
    var updatedAt = Date()

    static let lifetime: TimeInterval = 12 * 60 * 60

    var isEmpty: Bool { ingredients.isEmpty && steps.isEmpty }

    private static func key(_ id: UUID) -> String { "cooking.\(id.uuidString)" }

    static func load(for id: UUID, now: Date = .now, defaults: UserDefaults = .standard) -> CookingProgress {
        guard let data = defaults.data(forKey: key(id)),
              let progress = try? JSONDecoder().decode(CookingProgress.self, from: data),
              now.timeIntervalSince(progress.updatedAt) < lifetime
        else { return CookingProgress() }
        return progress
    }

    static func save(_ progress: CookingProgress, for id: UUID, defaults: UserDefaults = .standard) {
        if progress.isEmpty {
            defaults.removeObject(forKey: key(id))
        } else if let data = try? JSONEncoder().encode(progress) {
            defaults.set(data, forKey: key(id))
        }
    }

    static func clear(for id: UUID, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(id))
    }
}

// MARK: - Leitura dos passos

/// Tira de cada passo os temporizadores ("forno durante 30 minutos") e os ingredientes que usa.
nonisolated enum StepAnalysis {
    struct Duration: Hashable, Sendable {
        let seconds: Int

        var label: String {
            if seconds < 60 { return "\(seconds) s" }
            return Format.minutes(seconds / 60)
        }
    }

    // Só se lê depois de criada (não muda): partilhá-la entre tarefas é seguro.
    nonisolated(unsafe) private static let durationPattern = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)(?:\s*(?:a|-|–)\s*\d+(?:[.,]\d+)?)?\s*(minutos|minuto|min|horas|hora|h|segundos|segundo|seg|s)\b"#,
        options: [.caseInsensitive]
    )

    /// Temporizadores de 10 segundos a 3 horas (esperas maiores, como congelar 24 h, têm o seu próprio aviso).
    static func durations(in text: String) -> [Duration] {
        let range = NSRange(text.startIndex..., in: text)
        var result: [Duration] = []
        for match in durationPattern.matches(in: text, range: range) {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[numberRange].replacingOccurrences(of: ",", with: "."))
            else { continue }
            let unit = text[unitRange].lowercased()
            let factor: Double = unit.hasPrefix("h") ? 3600 : unit.hasPrefix("s") ? 1 : 60
            let seconds = Int((value * factor).rounded())
            guard (10...(3 * 3600)).contains(seconds) else { continue }
            let duration = Duration(seconds: seconds)
            if !result.contains(duration) { result.append(duration) }
        }
        return result
    }

    /// Palavras dos nomes que não identificam um ingrediente ("Leite magro" → "leite").
    private static let ignoredWords: Set<String> = [
        "natural", "magro", "magra", "inteiro", "inteira", "liquido", "liquida", "proteina", "proteinas",
        "recheio", "powder", "gourmet", "select", "protein", "fresco", "fresca", "reduzido", "sucralose",
    ]

    private static func words(_ text: String) -> [String] {
        text.searchNormalized
            .split { !$0.isLetter }
            .map { word in
                // Plural simples: "leites" → "leite", "avelãs" → "avela".
                let word = String(word)
                return word.count > 3 && word.hasSuffix("s") ? String(word.dropLast()) : word
            }
    }

    /// Ingredientes mencionados no texto de um passo, pela ordem da lista de ingredientes.
    static func ingredients(in text: String, from ingredients: [Ingredient]) -> [Ingredient] {
        let stepWords = Set(words(text))
        return ingredients.filter { ingredient in
            words(ingredient.name).contains { word in
                guard word.count >= 3, !ignoredWords.contains(word) else { return false }
                if stepWords.contains(word) { return true }
                // Palavras compridas também valem pelo início ("proteico" não, "amêndoas" sim).
                return word.count >= 5 && stepWords.contains { $0.count >= 5 && ($0.hasPrefix(word) || word.hasPrefix($0)) }
            }
        }
    }
}

// MARK: - Temporizadores

/// Temporizadores do modo cozinhar. Contam dentro da app; se saíres dela, chega uma notificação no fim.
@Observable
final class CookingTimers {
    static let shared = CookingTimers()

    struct ActiveTimer: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let recipeTitle: String
        let end: Date

        func remaining(at date: Date) -> TimeInterval { max(0, end.timeIntervalSince(date)) }
    }

    private(set) var timers: [ActiveTimer] = []

    func start(_ duration: StepAnalysis.Duration, label: String, recipeTitle: String) {
        let timer = ActiveTimer(label: label, recipeTitle: recipeTitle, end: .now.addingTimeInterval(TimeInterval(duration.seconds)))
        timers.append(timer)
        Task { await Self.schedule(timer) }
    }

    func cancel(_ timer: ActiveTimer) {
        timers.removeAll { $0.id == timer.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier(timer)])
    }

    private static func identifier(_ timer: ActiveTimer) -> String { "timer-\(timer.id.uuidString)" }

    private static func schedule(_ timer: ActiveTimer) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Temporizador terminado"
        content.body = "\(timer.label) · \(timer.recipeTitle)"
        content.sound = .default
        let interval = max(1, timer.end.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier(timer), content: content, trigger: trigger))
    }

    /// "4:59" ou "1:02:30".
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded(.up))
        let hours = total / 3600, minutes = total % 3600 / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - À espera (congelador, frigorífico, repouso)

/// "Congelei agora": marca o início da espera e avisa quando a receita está pronta.
enum WaitReminder {
    private static func identifier(_ recipe: Recipe) -> String { "wait-\(recipe.id.uuidString)" }

    /// Quando fica pronta (início da espera + tempo de espera).
    static func readyDate(of recipe: Recipe) -> Date? {
        recipe.frozenAt.map { $0.addingTimeInterval(TimeInterval(recipe.waitMinutes * 60)) }
    }

    static func isReady(_ recipe: Recipe, now: Date = .now) -> Bool {
        readyDate(of: recipe).map { $0 <= now } ?? false
    }

    static func start(_ recipe: Recipe) {
        recipe.frozenAt = .now
        Task { await schedule(recipe) }
    }

    static func cancel(_ recipe: Recipe) {
        recipe.frozenAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(recipe)])
    }

    /// Terminou a espera e a receita foi feita: conta como "Fiz esta receita".
    static func finish(_ recipe: Recipe) {
        cancel(recipe)
        recipe.cookedDates.append(.now)
        CookingProgress.clear(for: recipe.id)
    }

    private static func schedule(_ recipe: Recipe) async {
        guard let ready = readyDate(of: recipe), ready > .now else { return }
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        switch recipe.waitKind {
        case .freezer?:
            content.title = "\(recipe.title): pronto a processar"
            content.body = "A base já está congelada há \(Format.minutes(recipe.waitMinutes))."
        case .fridge?:
            content.title = "\(recipe.title): pronto a comer"
            content.body = "Já passaram \(Format.minutes(recipe.waitMinutes)) no frigorífico."
        default:
            content.title = "\(recipe.title): pronto"
            content.body = "Já passaram \(Format.minutes(recipe.waitMinutes)) de repouso."
        }
        content.sound = .default
        content.userInfo = ["recipeID": recipe.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, ready.timeIntervalSinceNow), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier(recipe), content: content, trigger: trigger))
    }
}

extension WaitKind {
    /// Botão para começar a espera.
    var startTitle: String {
        switch self {
        case .freezer: "Congelei agora"
        case .fridge: "Pus no frigorífico"
        case .rest: "Pus a repousar"
        }
    }

    /// Botão para terminar quando está pronta.
    var finishTitle: String {
        switch self {
        case .freezer: "Processei"
        case .fridge, .rest: "Já está feita"
        }
    }

    /// "No congelador", "No frigorífico", "A repousar".
    var waitingTitle: String {
        switch self {
        case .freezer: "No congelador"
        case .fridge: "No frigorífico"
        case .rest: "A repousar"
        }
    }
}

// MARK: - Notificações com a app aberta

/// Mostra as notificações (temporizadores, esperas) mesmo com a app aberta,
/// e abre a receita quando se toca no aviso de uma espera.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["recipeID"] as? String,
              let id = UUID(uuidString: raw) else { return }
        await MainActor.run { AppRouter.shared.open(id) }
    }
}

// MARK: - Ecrã aceso

/// Mantém o ecrã aceso enquanto alguma vista o pedir (receita a meio, modo cozinhar).
enum ScreenAwake {
    private static var holders: Set<String> = []

    static func set(_ holder: String, _ isOn: Bool) {
        if isOn { holders.insert(holder) } else { holders.remove(holder) }
        UIApplication.shared.isIdleTimerDisabled = !holders.isEmpty
    }
}
