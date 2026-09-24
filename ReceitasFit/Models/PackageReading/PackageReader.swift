import Foundation
import UIKit
import Vision

/// Lê fotografias de embalagens no próprio iPhone (Vision): texto da tabela nutricional e código de barras.
/// Nada sai do iPhone nesta fase; só o código de barras é usado depois para procurar no Open Food Facts.
enum PackageReader {
    /// Um bloco de texto reconhecido, em coordenadas proporcionais à imagem (origem no canto superior esquerdo).
    nonisolated struct TextBox: Sendable {
        var text: String
        var minX: Double
        var maxX: Double
        var midY: Double
        var height: Double
        /// Inclinação da linha de texto (radianos), para endireitar fotografias tortas.
        var angle: Double
    }

    struct PhotoResult {
        var rows: [[String]]
        var barcodes: [String]
    }

    static func read(_ image: UIImage) async throws -> PhotoResult {
        guard let cgImage = prepared(image) else { return PhotoResult(rows: [], barcodes: []) }
        let aspect = Double(cgImage.width) / Double(max(1, cgImage.height))

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = [Locale.Language(identifier: "pt-PT"), Locale.Language(identifier: "en-US")]
        textRequest.usesLanguageCorrection = true
        let observations = try await textRequest.perform(on: cgImage)

        var boxes: [TextBox] = []
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { continue }
            // Vision usa a origem em baixo; a largura é multiplicada pela proporção para o ângulo ser real.
            let tl = observation.topLeft, tr = observation.topRight
            let bl = observation.bottomLeft, br = observation.bottomRight
            let xs = [tl.x, tr.x, bl.x, br.x].map { Double($0) * aspect }
            let ys = [tl.y, tr.y, bl.y, br.y].map { 1 - Double($0) }
            let angle = atan2(Double(tl.y - tr.y), Double(tr.x - tl.x) * aspect)
            boxes.append(TextBox(
                text: text,
                minX: xs.min() ?? 0,
                maxX: xs.max() ?? 0,
                midY: ys.reduce(0, +) / 4,
                height: abs(Double(tl.y - bl.y)),
                angle: angle
            ))
        }

        var barcodeRequest = DetectBarcodesRequest()
        barcodeRequest.symbologies = [.ean13, .ean8, .upce]
        let barcodes = (try? await barcodeRequest.perform(on: cgImage))?.compactMap(\.payloadString) ?? []

        return PhotoResult(rows: rows(from: boxes), barcodes: barcodes)
    }

    /// Junta os blocos de texto em filas da tabela, da esquerda para a direita.
    /// Endireita primeiro a fotografia com a inclinação mediana das linhas de texto.
    nonisolated static func rows(from boxes: [TextBox]) -> [[String]] {
        guard !boxes.isEmpty else { return [] }
        let angles = boxes.filter { $0.maxX - $0.minX > $0.height * 2 }.map(\.angle).sorted()
        let skew = angles.isEmpty ? 0 : angles[angles.count / 2]
        let slope = tan(skew)
        let heights = boxes.map(\.height).sorted()
        let lineHeight = max(heights[heights.count / 2], 0.005)

        struct Placed { let box: TextBox; let y: Double }
        // Com a fotografia inclinada, a mesma fila desce (ou sobe) para a direita: corrige-se pela inclinação.
        // (Ângulo positivo = a linha desce para a direita, porque o y aqui cresce para baixo.)
        let placed = boxes
            .map { Placed(box: $0, y: $0.midY - slope * ($0.minX + $0.maxX) / 2) }
            .sorted { $0.y < $1.y }

        var rows: [[Placed]] = []
        for item in placed {
            if let last = rows.last, let anchor = last.first, abs(item.y - anchor.y) < lineHeight * 0.6 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
            }
        }
        return rows.map { row in row.sorted { $0.box.minX < $1.box.minX }.map(\.box.text) }
    }

    /// Imagem direita (orientação .up) e com no máximo 2400 px no lado maior.
    private static func prepared(_ image: UIImage) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, 2400 / max(longest, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
