import Foundation
import SwiftData

// Versões do esquema de dados.
//
// Cada versão congela os modelos tal como foram publicados. Para mudar os modelos no futuro:
// 1. copia os modelos atuais para um novo `SchemaVn` (congelados);
// 2. altera os modelos de topo (`Recipe`, `Food`) e cria `SchemaVn+1` a apontar para eles;
// 3. acrescenta a etapa em `ReceitasMigrationPlan.stages` e um teste em `MigrationTests`.

/// Versão 1: os modelos das versões 1.0 e 1.1 da app (antes do esquema ter versões).
nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Recipe.self, Food.self] }

    @Model
    final class Recipe {
        var id: UUID = UUID()
        var title: String = ""
        var summary: String = ""
        var categoryRaw: String = "lunch"
        var tags: [String] = []
        var servings: Int = 1
        var prepMinutes: Int = 0
        var cookMinutes: Int = 0
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sugars: Double = 0
        var saturatedFat: Double = 0
        var salt: Double = 0
        var nutritionIsComputed: Bool = false
        var sourceURL: String = ""
        var notes: String = ""
        var isFavorite: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        @Attribute(.externalStorage) var photoData: Data?
        var thumbnailData: Data?
        var ingredientsData: Data = Data()
        var stepsData: Data = Data()

        init(title: String = "") {
            self.title = title
        }
    }

    @Model
    final class Food {
        var id: UUID = UUID()
        var name: String = ""
        var brand: String = ""
        var categoryRaw: String = "other"
        var measureBaseRaw: String = "g"
        var unitWeight: Double?
        @Attribute(.externalStorage) var imageData: Data?
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var sugars: Double = 0
        var fat: Double = 0
        var saturatedFat: Double = 0
        var fiber: Double = 0
        var salt: Double = 0
        var createdAt: Date = Date()
        var updatedAt: Date = Date()

        init(name: String = "") {
            self.name = name
        }
    }
}

/// Versão 2 (app 1.2): receitas de exemplo, registo de "Fiz esta receita", ponto de foco da foto,
/// porções com nome e peso das colheres por alimento.
nonisolated enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Recipe.self, Food.self] }
}

nonisolated enum ReceitasMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    // Só se acrescentam campos com valores por omissão: migração automática, sem perda de dados.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

/// Cria o contentor de dados da app, protegendo a base de dados antes de a abrir.
enum DataStore {
    static let schema = Schema(versionedSchema: SchemaV2.self)

    static func makeContainer() throws -> ModelContainer {
        StoreSafety.backupIfVersionChanged()
        return try ModelContainer(
            for: schema,
            migrationPlan: ReceitasMigrationPlan.self,
            configurations: ModelConfiguration(schema: schema)
        )
    }
}

/// Antes de abrir os dados numa versão nova da app, guarda uma cópia da base de dados.
/// Se uma migração correr mal, os dados antigos continuam intactos nesta cópia.
enum StoreSafety {
    private static let versionKey = "lastStoreBackupVersion"

    static var backupsFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Proteção", directoryHint: .isDirectory)
    }

    static func backupIfVersionChanged() {
        let info = Bundle.main.infoDictionary
        let version = "\(info?["CFBundleShortVersionString"] as? String ?? "?")-\(info?["CFBundleVersion"] as? String ?? "?")"
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: versionKey) != version else { return }

        let fileManager = FileManager.default
        let store = URL.applicationSupportDirectory.appending(path: "default.store")
        guard fileManager.fileExists(atPath: store.path()) else {
            defaults.set(version, forKey: versionKey)
            return
        }
        let destination = backupsFolder.appending(path: "antes-de-\(version)", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for suffix in ["", "-wal", "-shm"] {
                let source = URL.applicationSupportDirectory.appending(path: "default.store\(suffix)")
                let target = destination.appending(path: "default.store\(suffix)")
                if fileManager.fileExists(atPath: source.path()) {
                    try? fileManager.removeItem(at: target)
                    try fileManager.copyItem(at: source, to: target)
                }
            }
            // Os ficheiros das fotos (armazenamento externo) ficam numa pasta própria.
            let external = URL.applicationSupportDirectory.appending(path: ".default_SUPPORT", directoryHint: .isDirectory)
            if fileManager.fileExists(atPath: external.path()) {
                let target = destination.appending(path: ".default_SUPPORT", directoryHint: .isDirectory)
                try? fileManager.removeItem(at: target)
                try fileManager.copyItem(at: external, to: target)
            }
            defaults.set(version, forKey: versionKey)
            pruneOldBackups(keeping: 2)
        } catch {
            // Sem cópia não se bloqueia a app; tenta de novo no próximo arranque.
        }
    }

    private static func pruneOldBackups(keeping count: Int) {
        let fileManager = FileManager.default
        guard let folders = try? fileManager.contentsOfDirectory(
            at: backupsFolder, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let sorted = folders.sorted {
            let a = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return a > b
        }
        for folder in sorted.dropFirst(count) {
            try? fileManager.removeItem(at: folder)
        }
    }
}
