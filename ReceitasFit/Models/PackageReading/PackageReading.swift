import Foundation
import UIKit

/// Resultado da leitura de uma embalagem: um alimento por guardar e o relatório para o utilizador rever.
///
/// Regras (decididas com o utilizador):
/// - nunca guarda nada sozinho: o resultado abre no editor de alimentos e só fica guardado com "Guardar";
/// - não guarda as fotografias, o código de barras nem a lista de ingredientes do produto;
/// - o rótulo fotografado tem prioridade; o Open Food Facts só preenche o que faltar.
struct PackageReading {
    enum Source: Equatable {
        case label, openFoodFacts
    }

    struct Conflict: Identifiable, Equatable {
        let nutrient: Nutrient
        let labelValue: Double
        let databaseValue: Double
        var id: Nutrient { nutrient }
    }

    enum DatabaseStatus: Equatable {
        case noBarcode
        case found(name: String)
        case notFound
        case unavailable
    }

    /// Quem leu o rótulo.
    enum Reader: Equatable {
        case gemini
        /// Leitura no iPhone (Vision); `reason` explica porque não foi usado o Gemini.
        case device(reason: String?)
    }

    var draft: FoodDraft
    var sources: [Nutrient: Source]
    var conflicts: [Conflict]
    var databaseStatus: DatabaseStatus
    var reader: Reader = .device(reason: nil)
    /// Valores escritos como "<0,5 g" no rótulo (guardados como 0,5).
    var lessThan: Set<Nutrient> = []
    /// Porção indicada no rótulo e já acrescentada às porções do alimento.
    var labelPortion: FoodPortion?
    /// Observações do Gemini sobre a leitura.
    var notes = ""
    var photoCount: Int
    /// Texto reconhecido, fila a fila (só na leitura no iPhone).
    var recognizedRows: [[String]]

    var missing: [Nutrient] { Nutrient.allCases.filter { sources[$0] == nil } }

    // MARK: - Leitura

    /// Lê com o Gemini se houver chave; sem chave, sem internet ou sem quota, lê no iPhone.
    static func read(photos: [UIImage]) async -> PackageReading {
        var label = PartialFacts()
        var rows: [[String]] = []
        var barcodes: [String] = []
        var reader = Reader.gemini
        var gemini: GeminiReader.Result?

        do {
            gemini = try await GeminiReader.read(photos: photos)
        } catch {
            let reason = (error as? GeminiReader.ReadError)?.message ?? error.localizedDescription
            reader = .device(reason: reason)
        }

        if let gemini {
            label = gemini.facts
            if let barcode = gemini.barcode { barcodes.append(barcode) }
            for photo in photos where barcodes.isEmpty {
                barcodes += await PackageReader.barcodes(in: photo)
            }
        } else {
            for photo in photos {
                guard let result = try? await PackageReader.read(photo) else { continue }
                barcodes += result.barcodes
                let parsed = LabelParser.parse(rows: result.rows)
                // Se houver várias fotografias da tabela, fica a primeira leitura de cada nutriente.
                for (nutrient, value) in parsed.values where label[nutrient] == nil {
                    label[nutrient] = value
                    if parsed.lessThan.contains(nutrient) { label.lessThan.insert(nutrient) }
                }
                if label.base == nil { label.base = parsed.base }
                rows += result.rows
            }
        }

        var product: OpenFoodFacts.Product?
        var status = DatabaseStatus.noBarcode
        if let barcode = barcodes.first {
            do {
                let found = try await OpenFoodFacts.product(barcode: barcode)
                product = found
                status = .found(name: found.name)
            } catch OpenFoodFacts.LookupError.unavailable {
                status = .unavailable
            } catch {
                status = .notFound
            }
        }

        var reading = merge(label: label, product: product, gemini: gemini)
        reading.databaseStatus = status
        reading.reader = reader
        reading.photoCount = photos.count
        reading.recognizedRows = rows
        return reading
    }

    /// Junta o rótulo, o Open Food Facts e os dados extra do Gemini (separado da leitura para poder ser testado).
    static func merge(label: PartialFacts, product: OpenFoodFacts.Product?, gemini: GeminiReader.Result? = nil) -> PackageReading {
        var draft = FoodDraft()
        var sources: [Nutrient: Source] = [:]
        var conflicts: [Conflict] = []

        for nutrient in Nutrient.allCases {
            let fromLabel = label[nutrient]
            let fromDatabase = product?.facts[nutrient]
            if let fromLabel {
                draft.facts[keyPath: nutrient.keyPath] = fromLabel
                sources[nutrient] = .label
                if let fromDatabase, differs(fromLabel, fromDatabase, nutrient: nutrient) {
                    conflicts.append(Conflict(nutrient: nutrient, labelValue: fromLabel, databaseValue: fromDatabase))
                }
            } else if let fromDatabase {
                draft.facts[keyPath: nutrient.keyPath] = fromDatabase
                sources[nutrient] = .openFoodFacts
            }
        }
        // Nome e marca: os da frente da embalagem (Gemini) ou, se faltarem, os do Open Food Facts.
        draft.name = [gemini?.name, product?.name].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        draft.brand = [gemini?.brand, product?.brand].compactMap { $0 }.first { !$0.isEmpty } ?? ""
        draft.base = label.base ?? product?.facts.base ?? .grams

        // A porção do rótulo ("1 dose = 30 g") entra logo nas porções do alimento; revê-se no editor.
        var labelPortion: FoodPortion?
        if let grams = gemini?.servingGrams {
            let name = gemini?.servingName.map { $0.lowercased() } ?? "porção"
            let portion = FoodPortion(name: name, grams: grams)
            labelPortion = portion
            draft.portions = [portion]
        }

        return PackageReading(
            draft: draft,
            sources: sources,
            conflicts: conflicts,
            databaseStatus: product.map { .found(name: $0.name) } ?? .noBarcode,
            lessThan: label.lessThan.filter { sources[$0] == .label },
            labelPortion: labelPortion,
            notes: gemini?.notes ?? "",
            photoCount: 0,
            recognizedRows: []
        )
    }

    /// Diferença que merece atenção: mais de 5 % na energia, ou mais de 10 % e 0,3 g nos restantes.
    private static func differs(_ a: Double, _ b: Double, nutrient: Nutrient) -> Bool {
        let difference = abs(a - b)
        let reference = max(abs(a), abs(b), 0.001)
        if nutrient == .calories { return difference / reference > 0.05 && difference >= 3 }
        return difference / reference > 0.10 && difference >= 0.3
    }
}
