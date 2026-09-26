import Foundation
import SwiftData
import Testing
@testable import Receitas

@MainActor
struct FormAndBackupTests {
    @Test func numberFieldAcceptsCommaAndDot() {
        #expect(NumberField.parse("12,5") == 12.5)
        #expect(NumberField.parse("12.5") == 12.5)
        #expect(NumberField.parse("7,") == 7)
        #expect(NumberField.parse(" 30 ") == 30)
        #expect(NumberField.parse("") == nil)
        #expect(NumberField.parse("abc") == nil)
        #expect(NumberField.format(nil, 2).isEmpty)
    }

    @Test func smallValuesKeepTwoDecimals() {
        #expect(Double(0.25).cleanString.hasSuffix("25"))
        #expect(!Double(12.25).cleanString.hasSuffix("25"))
        #expect(Double(0).cleanString == "0")
    }

    @Test func fingerprintIgnoresExportDateButSeesChanges() throws {
        let context = ModelContext(try ModelContainer(for: DataStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let recipe = Recipe(title: "Papas de aveia")
        context.insert(recipe)
        try context.save()

        let first = try RecipeBackup.encodeWithFingerprint(recipes: [recipe], foods: [])
        let second = try RecipeBackup.encodeWithFingerprint(recipes: [recipe], foods: [])
        #expect(first.hash == second.hash)

        recipe.isFavorite.toggle()
        let changed = try RecipeBackup.encodeWithFingerprint(recipes: [recipe], foods: [])
        #expect(changed.hash != first.hash)

        // O ficheiro continua a ser uma cópia válida.
        let restored = try RecipeBackup.restore(
            from: changed.data,
            into: ModelContext(try ModelContainer(for: DataStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        )
        #expect(restored.recipes == 1)
    }

    @Test func backupNamesSortByDate() {
        let older = AutoBackup.stamp(Date(timeIntervalSince1970: 1_700_000_000))
        let newer = AutoBackup.stamp(Date(timeIntervalSince1970: 1_800_000_000))
        #expect(older < newer)
        #expect(older.count == "yyyy-MM-dd-HHmm".count)
    }
}
