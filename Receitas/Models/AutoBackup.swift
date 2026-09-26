import CryptoKit
import Foundation
import Observation
import SwiftData
import UIKit

/// Cópias de segurança automáticas para uma pasta escolhida pelo utilizador (por exemplo, no iCloud Drive).
///
/// No máximo uma cópia por dia, feita ao abrir a app ou ao sair dela. Só se escreve um ficheiro novo
/// quando algo mudou desde a última cópia, e ficam guardadas as `keepCount` mais recentes.
/// As fotografias vão dentro do ficheiro, tal como na exportação manual.
@Observable
final class AutoBackup {
    static let shared = AutoBackup()

    nonisolated static let keepCount = 5
    nonisolated static let filePrefix = "Receitas-auto-"
    private static let interval: TimeInterval = 24 * 60 * 60

    private enum Keys {
        static let bookmark = "autoBackup.bookmark"
        static let folderName = "autoBackup.folderName"
        static let lastDate = "autoBackup.lastDate"
        static let lastHash = "autoBackup.lastHash"
        static let lastError = "autoBackup.lastError"
    }

    private let defaults = UserDefaults.standard

    private(set) var folderName: String?
    private(set) var lastDate: Date?
    private(set) var lastError: String?
    private(set) var isRunning = false

    var isEnabled: Bool { previewEnabled || defaults.data(forKey: Keys.bookmark) != nil }

    /// Estado simulado para as capturas de ecrã do CI (só em builds de desenvolvimento).
    private var previewEnabled = false

    private init() {
        folderName = defaults.string(forKey: Keys.folderName)
        lastDate = defaults.object(forKey: Keys.lastDate) as? Date
        lastError = defaults.string(forKey: Keys.lastError)

        if let state = ScreenshotMode.string("screenshotBackupState") {
            folderName = state == "off" ? nil : "Receitas"
            previewEnabled = state != "off"
            lastDate = .now.addingTimeInterval(-2 * 60 * 60)
            lastError = state == "failed" ? "Já não é possível aceder à pasta escolhida. Escolhe-a outra vez." : nil
        }
    }

    // MARK: - Pasta

    /// Guarda o acesso à pasta escolhida no seletor de ficheiros.
    func setFolder(_ url: URL) throws {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(bookmark, forKey: Keys.bookmark)
        defaults.set(url.lastPathComponent, forKey: Keys.folderName)
        // Pasta nova: a próxima cópia é feita já, mesmo que nada tenha mudado.
        defaults.removeObject(forKey: Keys.lastHash)
        folderName = url.lastPathComponent
        setError(nil)
    }

    func disable() {
        for key in [Keys.bookmark, Keys.folderName, Keys.lastHash, Keys.lastError] {
            defaults.removeObject(forKey: key)
        }
        folderName = nil
        lastError = nil
        previewEnabled = false
    }

    // MARK: - Cópias

    /// Faz a cópia diária se já passou um dia desde a última.
    func runIfDue(context: ModelContext) async {
        guard isEnabled, !ScreenshotMode.flag("screenshots") else { return }
        if let lastDate, Date.now.timeIntervalSince(lastDate) < Self.interval { return }
        await run(context: context, force: false)
    }

    /// Faz uma cópia agora. Com `force`, escreve mesmo que nada tenha mudado.
    @discardableResult
    func run(context: ModelContext, force: Bool) async -> Bool {
        guard isEnabled, !isRunning, let bookmark = defaults.data(forKey: Keys.bookmark) else { return false }
        isRunning = true
        defer { isRunning = false }

        // O iOS pode suspender a app logo a seguir a sair; pede tempo para terminar a escrita.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Cópia de segurança")
        defer { UIApplication.shared.endBackgroundTask(backgroundTask) }

        let payload: (data: Data, hash: String)
        do {
            // As apagadas (ainda em "Apagadas recentemente") não entram na cópia.
            let recipes = try context.fetch(FetchDescriptor<Recipe>(predicate: Recipe.notDeleted))
            let foods = try context.fetch(FetchDescriptor<Food>(predicate: Food.notDeleted))
            payload = try RecipeBackup.encodeWithFingerprint(recipes: recipes, foods: foods)
        } catch {
            setError("Não foi possível preparar a cópia: \(error.localizedDescription)")
            return false
        }

        if !force, payload.hash == defaults.string(forKey: Keys.lastHash) {
            // Nada mudou: não vale a pena ocupar uma das cópias guardadas.
            markDone(hash: payload.hash)
            return true
        }

        let filename = Self.filePrefix + Self.stamp(.now) + ".json"
        let result = await Task.detached(priority: .utility) {
            Self.write(payload.data, named: filename, bookmark: bookmark)
        }.value

        switch result {
        case .success(let refreshedBookmark):
            if let refreshedBookmark { defaults.set(refreshedBookmark, forKey: Keys.bookmark) }
            markDone(hash: payload.hash)
            return true
        case .failure(let error):
            setError(error.message)
            return false
        }
    }

    private func markDone(hash: String) {
        lastDate = .now
        defaults.set(lastDate, forKey: Keys.lastDate)
        defaults.set(hash, forKey: Keys.lastHash)
        setError(nil)
    }

    private func setError(_ message: String?) {
        lastError = message
        defaults.set(message, forKey: Keys.lastError)
    }

    // MARK: - Escrita (fora do MainActor)

    nonisolated struct WriteError: Error {
        let message: String
    }

    /// Escreve o ficheiro e apaga as cópias automáticas mais antigas.
    /// Devolve um marcador atualizado quando o sistema indica que o antigo expirou.
    nonisolated private static func write(_ data: Data, named filename: String, bookmark: Data) -> Result<Data?, WriteError> {
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return .failure(WriteError(message: "Já não é possível aceder à pasta escolhida. Escolhe-a outra vez."))
        }
        guard folder.startAccessingSecurityScopedResource() else {
            return .failure(WriteError(message: "Sem permissão para escrever na pasta escolhida. Escolhe-a outra vez."))
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: folder, options: [], error: &coordinationError) { folderURL in
            do {
                try data.write(to: folderURL.appending(path: filename), options: .atomic)
                try prune(folderURL)
            } catch {
                writeError = error
            }
        }
        if let error = writeError ?? coordinationError {
            return .failure(WriteError(message: "A cópia falhou: \(error.localizedDescription)"))
        }
        let refreshed = isStale ? try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) : nil
        return .success(refreshed)
    }

    /// Mantém só as cópias automáticas mais recentes. Os outros ficheiros da pasta nunca são tocados.
    nonisolated private static func prune(_ folder: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix(filePrefix) && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent } // o nome tem a data, por isso ordena por data
        for old in backups.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    // MARK: - Restaurar

    /// Uma cópia automática guardada na pasta.
    nonisolated struct StoredBackup: Identifiable, Hashable, Sendable {
        let name: String
        let date: Date
        let size: Int
        var id: String { name }
    }

    /// As cópias automáticas que estão na pasta, da mais recente para a mais antiga.
    func storedBackups() async -> Result<[StoredBackup], WriteError> {
        if previewEnabled {
            // Capturas do CI: três cópias de exemplo.
            return .success((0..<3).map { day in
                let date = Date.now.addingTimeInterval(TimeInterval(-day * 86_400 - 7_200))
                return StoredBackup(name: Self.filePrefix + Self.stamp(date) + ".json", date: date, size: 12_400_000 - day * 150_000)
            })
        }
        guard let bookmark = defaults.data(forKey: Keys.bookmark) else { return .success([]) }
        return await Task.detached(priority: .userInitiated) {
            Self.accessFolder(bookmark) { folder in
                let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
                let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)
                return files
                    .filter { $0.lastPathComponent.hasPrefix(Self.filePrefix) && $0.pathExtension == "json" }
                    .map { url in
                        let values = try? url.resourceValues(forKeys: Set(keys))
                        let stamp = url.deletingPathExtension().lastPathComponent.dropFirst(Self.filePrefix.count)
                        let date = Self.date(fromStamp: String(stamp)) ?? values?.contentModificationDate ?? .distantPast
                        return StoredBackup(name: url.lastPathComponent, date: date, size: values?.fileSize ?? 0)
                    }
                    .sorted { $0.date > $1.date }
            }
        }.value
    }

    /// Lê uma das cópias automáticas (para a importar).
    func readBackup(_ backup: StoredBackup) async -> Result<Data, WriteError> {
        guard let bookmark = defaults.data(forKey: Keys.bookmark) else {
            return .failure(WriteError(message: "Escolhe primeiro a pasta das cópias."))
        }
        let name = backup.name
        return await Task.detached(priority: .userInitiated) {
            Self.accessFolder(bookmark) { folder in
                var coordinationError: NSError?
                var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
                NSFileCoordinator().coordinate(readingItemAt: folder.appending(path: name), options: [], error: &coordinationError) { url in
                    result = Result { try Data(contentsOf: url) }
                }
                if let coordinationError { throw coordinationError }
                return try result.get()
            }
        }.value
    }

    /// Abre a pasta guardada, corre `body` e fecha o acesso.
    nonisolated private static func accessFolder<T>(_ bookmark: Data, _ body: (URL) throws -> T) -> Result<T, WriteError> {
        var isStale = false
        guard let folder = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return .failure(WriteError(message: "Já não é possível aceder à pasta escolhida. Escolhe-a outra vez."))
        }
        guard folder.startAccessingSecurityScopedResource() else {
            return .failure(WriteError(message: "Sem permissão para abrir a pasta escolhida. Escolhe-a outra vez."))
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        do {
            return .success(try body(folder))
        } catch {
            return .failure(WriteError(message: "Não foi possível ler a pasta: \(error.localizedDescription)"))
        }
    }

    nonisolated static func date(fromStamp stamp: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.date(from: stamp)
    }

    nonisolated static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}

extension RecipeBackup {
    /// Codifica a cópia e calcula uma impressão digital do conteúdo (sem a data da exportação),
    /// para saber se algo mudou desde a última cópia automática.
    static func encodeWithFingerprint(recipes: [Recipe], foods: [Food]) throws -> (data: Data, hash: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var backup = RecipeBackup(recipes: recipes.map(RecipeDTO.init(recipe:)), foods: foods.map(FoodDTO.init(food:)))
        let data = try encoder.encode(backup)
        backup.exportedAt = .distantPast
        let digest = SHA256.hash(data: try encoder.encode(backup))
        return (data, digest.map { String(format: "%02x", $0) }.joined())
    }
}
