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

    var draft: FoodDraft
    var sources: [Nutrient: Source]
    var conflicts: [Conflict]
    var databaseStatus: DatabaseStatus
    var photosWithTable: Int
    var photoCount: Int
    /// Texto reconhecido, fila a fila (para o utilizador perceber o que foi lido).
    var recognizedRows: [[String]]

    var missing: [Nutrient] { Nutrient.allCases.filter { sources[$0] == nil } }

    // MARK: - Leitura

    static func read(photos: [UIImage]) async -> PackageReading {
        var label = PartialFacts()
        var rows: [[String]] = []
        var barcodes: [String] = []
        var photosWithTable = 0

        for photo in photos {
            guard let result = try? await PackageReader.read(photo) else { continue }
            barcodes += result.barcodes
            let parsed = LabelParser.parse(rows: result.rows)
            if parsed.values.count >= 3 { photosWithTable += 1 }
            // Se houver várias fotografias da tabela, fica a leitura mais completa de cada nutriente.
            for (nutrient, value) in parsed.values where label[nutrient] == nil {
                label[nutrient] = value
            }
            if label.base == nil { label.base = parsed.base }
            rows += result.rows
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

        var reading = merge(label: label, product: product)
        reading.databaseStatus = status
        reading.photosWithTable = photosWithTable
        reading.photoCount = photos.count
        reading.recognizedRows = rows
        return reading
    }

    /// Junta o rótulo e o Open Food Facts (separado da leitura para poder ser testado).
    static func merge(label: PartialFacts, product: OpenFoodFacts.Product?) -> PackageReading {
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
        if let product {
            draft.name = product.name
            draft.brand = product.brand
        }
        draft.base = label.base ?? product?.facts.base ?? .grams

        return PackageReading(
            draft: draft,
            sources: sources,
            conflicts: conflicts,
            databaseStatus: product.map { .found(name: $0.name) } ?? .noBarcode,
            photosWithTable: 0,
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
