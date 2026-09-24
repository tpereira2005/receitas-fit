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
        /// Blocos de texto com posição (para diagnóstico e testes).
        var boxes: [TextBox] = []
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

        return PhotoResult(rows: rows(from: boxes), barcodes: barcodes, boxes: boxes)
    }

    /// Junta os blocos de texto em filas da tabela, da esquerda para a direita.
    /// Endireita primeiro a fotografia com a inclinação estimada a partir da própria tabela.
    nonisolated static func rows(from boxes: [TextBox]) -> [[String]] {
        guard !boxes.isEmpty else { return [] }
        let heights = boxes.map(\.height).sorted()
        let lineHeight = max(heights[heights.count / 2], 0.005)
        let slope = estimatedSlope(boxes, lineHeight: lineHeight)

        struct Placed { let box: TextBox; let y: Double }
        // Com a fotografia inclinada, a mesma fila desce (ou sobe) para a direita: corrige-se pela inclinação.
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

    /// Inclinação das filas (variação de y por unidade de x).
    ///
    /// O Vision devolve os blocos quase sempre com ângulo 0, mesmo em fotografias tortas, por isso a
    /// inclinação é medida na tabela: para cada par de blocos lado a lado e a alturas parecidas calcula-se
    /// o declive entre eles. Os pares da mesma fila dão todos o mesmo declive (o da fotografia); os pares
    /// de filas diferentes dão valores espalhados. Fica o declive mais frequente.
    nonisolated static func estimatedSlope(_ boxes: [TextBox], lineHeight: Double) -> Double {
        let maxSlope = 0.08  // cerca de 4,5°
        let binWidth = 0.004
        var bins: [Int: [Double]] = [:]
        for a in boxes {
            for b in boxes where b.minX > a.maxX {
                let dx = (b.minX + b.maxX) / 2 - (a.minX + a.maxX) / 2
                let dy = b.midY - a.midY
                guard dx > lineHeight * 2, abs(dy) < lineHeight * 1.3 else { continue }
                let slope = dy / dx
                guard abs(slope) <= maxSlope else { continue }
                bins[Int((slope / binWidth).rounded()), default: []].append(slope)
            }
        }
        // O grupo mais povoado, somado aos vizinhos (um declive pode cair na fronteira entre dois).
        let best = bins.keys.max { a, b in
            let countA = (bins[a - 1]?.count ?? 0) + (bins[a]?.count ?? 0) + (bins[a + 1]?.count ?? 0)
            let countB = (bins[b - 1]?.count ?? 0) + (bins[b]?.count ?? 0) + (bins[b + 1]?.count ?? 0)
            return countA < countB
        }
        guard let best else { return 0 }
        let members = (bins[best - 1] ?? []) + (bins[best] ?? []) + (bins[best + 1] ?? [])
        return members.reduce(0, +) / Double(members.count)
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
