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
        #expect(facts[.fiber] == 0.5)
        #expect(facts.lessThan == [.fiber])
        #expect(close(facts[.salt], 0.13))
    }

    /// Casos reais vistos no Vision: nome da fibra ilegível; filas já endireitadas pelo leitor.
    @Test func unreadableFibreNameUsesLabelOrder() {
        let rows: [[String]] = [
            ["dos quais açúcares", "2,6 g", "6,5 g"],
            ["-ОГa", "<0,5 g", "<0,5 g"],
            ["Proteínas", "1,9 g", "4,8 g"],
            ["Sal", "0,13 g", "0,33 g"],
        ]
        let facts = LabelParser.parse(rows: rows)
        #expect(facts[.fiber] == 0.5)
        #expect(facts.lessThan.contains(.fiber))
        #expect(facts[.protein] == 1.9)
    }

    /// Blocos reais da fotografia inclinada do whey (o Vision devolve ângulo 0 mesmo com a imagem torta).
    @Test func straightensTiltedRowsFromTableGeometry() {
        func box(_ minX: Double, _ maxX: Double, _ y: Double, _ text: String) -> PackageReader.TextBox {
            PackageReader.TextBox(text: text, minX: minX, maxX: maxX, midY: y, height: 0.035, angle: 0)
        }
        let boxes = [
            box(0.093, 0.350, 0.209, "Energia / Energy"), box(0.651, 0.773, 0.224, "1620 kJ"), box(0.926, 1.033, 0.232, "486 kJ"),
            box(0.641, 0.772, 0.279, "383 kcal"), box(0.895, 1.033, 0.289, "115 kcal"), box(1.236, 1.291, 0.299, "6%"),
            box(0.087, 0.281, 0.316, "Lípidos / Fat"), box(0.691, 0.768, 0.337, "5,6 g"), box(0.951, 1.028, 0.348, "1,7 g"),
            box(1.232, 1.286, 0.354, "2%"),
            box(0.078, 0.365, 0.538, "Proteínas / Protein"), box(0.691, 0.760, 0.558, "76 g"), box(0.951, 1.020, 0.568, "23 g"),
            box(0.077, 0.221, 0.591, "Sal / Salt"), box(0.662, 0.758, 0.615, "0,48 g"), box(0.920, 1.018, 0.623, "0,14 g"),
        ]
        let rows = PackageReader.rows(from: boxes)
        #expect(rows.contains(["Lípidos / Fat", "5,6 g", "1,7 g", "2%"]))
        #expect(rows.contains(["Sal / Salt", "0,48 g", "0,14 g"]))
        let facts = LabelParser.parse(rows: rows)
        #expect(facts[.calories] == 383)
        #expect(facts[.fat] == 5.6)
        #expect(facts[.salt] == 0.48)
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

    // MARK: - Gemini

    @Test func geminiRequestHasImagesAndSchema() throws {
        let body = GeminiReader.requestBody(images: [Data([1, 2, 3])])
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let contents = try #require(json["contents"] as? [[String: Any]])
        let parts = try #require(contents.first?["parts"] as? [[String: Any]])
        let image = try #require(parts.first?["inline_data"] as? [String: Any])
        #expect(image["mime_type"] as? String == "image/jpeg")
        #expect(image["data"] as? String == Data([1, 2, 3]).base64EncodedString())
        let config = try #require(json["generationConfig"] as? [String: Any])
        #expect(config["responseMimeType"] as? String == "application/json")
        #expect(config["responseSchema"] != nil)
    }

    @Test func parsesGeminiAnswer() throws {
        let answer = """
        {"nome": "Iogurte Grego Natural", "marca": "Marca", "base": "100g", "energia_kcal": 97,
         "lipidos": 0.4, "saturados": 0.1, "hidratos": 3.6, "acucares": 3.6, "fibra": 0.5, "proteina": 10,
         "sal": 0.1, "menor_que": ["fibra"], "porcao_nome": "Iogurte", "porcao_gramas": 170,
         "codigo_barras": "5601234567890", "notas": ""}
        """
        let envelope: [String: Any] = ["candidates": [["content": ["parts": [["text": answer]]]]]]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let result = try #require(GeminiReader.parse(response: data))
        #expect(result.name == "Iogurte Grego Natural")
        #expect(result.facts[.calories] == 97)
        #expect(result.facts[.protein] == 10)
        #expect(result.facts.lessThan == [.fiber])
        #expect(result.servingGrams == 170)
        #expect(result.barcode == "5601234567890")

        let reading = PackageReading.merge(label: result.facts, product: nil, gemini: result)
        #expect(reading.draft.name == "Iogurte Grego Natural")
        #expect(reading.draft.portions.first?.name == "iogurte")
        #expect(reading.draft.portions.first?.grams == 170)
        #expect(reading.lessThan == [.fiber])
        #expect(reading.draft.facts.fiber == 0.5)
    }

    @Test func geminiNullsAreMissingNotZero() throws {
        let answer = #"{"nome": "", "marca": "", "base": "100ml", "energia_kcal": 45, "lipidos": null, "menor_que": [], "notas": "Tabela desfocada"}"#
        let envelope: [String: Any] = ["candidates": [["content": ["parts": [["text": answer]]]]]]
        let result = try #require(GeminiReader.parse(response: try JSONSerialization.data(withJSONObject: envelope)))
        #expect(result.facts.base == .milliliters)
        #expect(result.facts[.fat] == nil)
        #expect(result.notes == "Tabela desfocada")
        #expect(result.barcode == nil)
    }

    // MARK: - Fotografias reais (Vision no simulador)

    /// Guarda o que o Vision leu num ficheiro no Mac do CI (o simulador escreve na pasta do utilizador
    /// do Mac), que o workflow mostra no registo. Serve para afinar a leitura quando um teste falha.
    private func log(_ name: String, _ result: PackageReader.PhotoResult) {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return }
        var lines = ["== \(name)", "-- filas"]
        lines += result.rows.map { "  " + $0.joined(separator: " | ") }
        lines.append("-- blocos (x inicial-final, y, altura, ângulo)")
        lines += result.boxes.map {
            String(format: "  %.3f-%.3f  y %.3f  h %.3f  %+.2f°  %@", $0.minX, $0.maxX, $0.midY, $0.height, $0.angle * 180 / .pi, $0.text)
        }
        try? lines.joined(separator: "\n").write(toFile: "\(home)/receitas-ocr-\(name).txt", atomically: true, encoding: .utf8)
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
        #expect(facts[.fiber] == 0.5, "\(text)")
        #expect(facts[.protein] == 1.9, "\(text)")
        #expect(facts[.salt] == 0.13, "\(text)")
    }
}
