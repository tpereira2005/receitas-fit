import Foundation
import Testing
import UIKit
@testable import ReceitasFit

private final class BundleToken {}

@MainActor
struct PackageReadingTests {
    private func close(_ value: Double?, _ expected: Double, tolerance: Double = 0.01) -> Bool {
        guard let value else { return false }
        return abs(value - expected) <= tolerance
    }

    // MARK: - Interpretação do texto

    @Test func parsesPortugueseTable() {
        let rows: [[String]] = [
            ["Declaração nutricional"],
            ["Por 100 g", "Por dose (40 g)"],
            ["Energia", "1569 kJ / 375 kcal", "628 kJ / 150 kcal"],
            ["Lípidos", "6,5 g", "2,6 g"],
            ["dos quais saturados", "1,2 g", "0,5 g"],
            ["Hidratos de carbono", "55 g", "22 g"],
            ["dos quais açúcares", "12 g", "4,8 g"],
            ["Fibra", "8,5 g", "3,4 g"],
            ["Proteínas", "20 g", "8,0 g"],
            ["Sal", "0,35 g", "0,14 g"],
        ]
        let facts = LabelParser.parse(rows: rows)
        #expect(facts.base == .grams)
        #expect(facts[.calories] == 375)
        #expect(facts[.fat] == 6.5)
        #expect(facts[.saturatedFat] == 1.2)
        #expect(facts[.carbs] == 55)
        #expect(facts[.sugars] == 12)
        #expect(facts[.fiber] == 8.5)
        #expect(facts[.protein] == 20)
        #expect(facts[.salt] == 0.35)
    }

    @Test func parsesEnergyOnNextRowAndMergedCells() {
        let rows: [[String]] = [
            ["Energia / Energy", "1620 kJ", "486 kJ"],
            ["383 kcal", "115 kcal", "6%"],
            ["Lípidos / Fat 5,6 g", "1,7 g", "2%"],
            ["Proteínas / Protein", "76g", "23 g", "46%"],
            ["Sal / Salt", "O,48 g"],
        ]
        let facts = LabelParser.parse(rows: rows)
        #expect(facts[.calories] == 383)
        #expect(facts[.fat] == 5.6)
        #expect(facts[.protein] == 76)
        #expect(facts[.salt] == 0.48)
        #expect(facts[.fiber] == nil)
    }

    @Test func handlesMillilitresLessThanAndKilojoulesOnly() {
        let rows: [[String]] = [
            ["Valores médios por 100 ml"],
            ["Valor energético", "188 kJ"],
            ["Fibra", "<0,5 g"],
            ["Sal", "130 mg"],
        ]
        let facts = LabelParser.parse(rows: rows)
        #expect(facts.base == .milliliters)
        #expect(facts[.calories] == 45)  // 188 / 4,184
        #expect(facts[.fiber] == 0)
        #expect(close(facts[.salt], 0.13))
    }

    @Test func wordBoundariesAvoidFalseMatches() {
        let rows: [[String]] = [["Molho de salsa", "12 g"], ["Universal", "3 g"]]
        #expect(LabelParser.parse(rows: rows).isEmpty)
    }

    // MARK: - Open Food Facts e junção

    @Test func parsesOpenFoodFactsResponse() throws {
        let json = """
        {"status": 1, "product": {"product_name": "Oat drink", "product_name_pt": "Bebida de aveia",
         "brands": "Marca, Outra", "nutrition_data_per": "100ml",
         "nutriments": {"energy-kcal_100g": 45, "fat_100g": "1.5", "proteins_100g": 1.0, "salt_100g": 0.1}}}
        """
        let product = try #require(OpenFoodFacts.parse(Data(json.utf8)))
        #expect(product.name == "Bebida de aveia")
        #expect(product.brand == "Marca")
        #expect(product.facts.base == .milliliters)
        #expect(product.facts[.calories] == 45)
        #expect(product.facts[.fat] == 1.5)
        #expect(product.facts[.carbs] == nil)
        #expect(OpenFoodFacts.parse(Data(#"{"status": 0}"#.utf8)) == nil)
    }

    @Test func labelWinsAndDatabaseFillsGaps() {
        var label = PartialFacts()
        label[.calories] = 375
        label[.protein] = 20
        var database = PartialFacts()
        database[.calories] = 400  // mais de 5 %: conflito
        database[.protein] = 20.5  // diferença pequena: sem conflito
        database[.salt] = 0.3
        let reading = PackageReading.merge(
            label: label,
            product: OpenFoodFacts.Product(name: "Aveia", brand: "Marca", facts: database)
        )
        #expect(reading.draft.facts.calories == 375)
        #expect(reading.draft.facts.salt == 0.3)
        #expect(reading.sources[.salt] == .openFoodFacts)
        #expect(reading.sources[.protein] == .label)
        #expect(reading.conflicts.map(\.nutrient) == [.calories])
        #expect(reading.missing.contains(.fiber))
        #expect(reading.draft.name == "Aveia")
    }

    // MARK: - Fotografias reais (Vision no simulador)

    /// Mostra no registo do CI o que o Vision leu (para afinar a leitura).
    private func log(_ name: String, _ result: PackageReader.PhotoResult) {
        print("OCR[\(name)] rows:")
        for row in result.rows { print("OCR[\(name)]   " + row.joined(separator: " | ")) }
        for box in result.boxes {
            print(String(format: "OCR[%@] box x=%.3f-%.3f y=%.3f h=%.3f a=%.2f° %@",
                         name, box.minX, box.maxX, box.midY, box.height, box.angle * 180 / .pi, box.text))
        }
    }

    private func image(_ name: String) throws -> UIImage {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: name, withExtension: "jpg"))
        return try #require(UIImage(contentsOfFile: url.path))
    }

    @Test func readsTiltedOatLabel() async throws {
        let result = try await PackageReader.read(image("aveia-proteica"))
        log("aveia-proteica", result)
        let facts = LabelParser.parse(rows: result.rows)
        let text = result.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        #expect(facts[.calories] == 375, "\(text)")
        #expect(facts[.fat] == 6.5, "\(text)")
        #expect(facts[.saturatedFat] == 1.2, "\(text)")
        #expect(facts[.carbs] == 55, "\(text)")
        #expect(facts[.sugars] == 12, "\(text)")
        #expect(facts[.fiber] == 8.5, "\(text)")
        #expect(facts[.protein] == 20, "\(text)")
        #expect(facts[.salt] == 0.35, "\(text)")
    }

    @Test func readsMultilingualWheyLabel() async throws {
        let result = try await PackageReader.read(image("whey"))
        log("whey", result)
        let facts = LabelParser.parse(rows: result.rows)
        let text = result.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        #expect(facts[.calories] == 383, "\(text)")
        #expect(facts[.fat] == 5.6, "\(text)")
        #expect(facts[.saturatedFat] == 3.4, "\(text)")
        #expect(facts[.carbs] == 6.2, "\(text)")
        #expect(facts[.sugars] == 4.1, "\(text)")
        #expect(facts[.protein] == 76, "\(text)")
        #expect(facts[.salt] == 0.48, "\(text)")
    }

    @Test func readsDrinkLabelPer100ml() async throws {
        let result = try await PackageReader.read(image("bebida-aveia"))
        log("bebida-aveia", result)
        let facts = LabelParser.parse(rows: result.rows)
        let text = result.rows.map { $0.joined(separator: " | ") }.joined(separator: "\n")
        #expect(facts.base == .milliliters, "\(text)")
        #expect(facts[.calories] == 45, "\(text)")
        #expect(facts[.fat] == 1.5, "\(text)")
        #expect(facts[.carbs] == 5.9, "\(text)")
        #expect(facts[.fiber] == 0, "\(text)")
        #expect(facts[.protein] == 1.9, "\(text)")
        #expect(facts[.salt] == 0.13, "\(text)")
    }
}
