import SwiftUI

/// Ajustar o enquadramento da fotografia: arrastar para escolher o que fica à vista e apertar
/// (ou usar o controlo) para aproximar. As pré-visualizações têm as proporções reais da app.
struct PhotoFocusEditor: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let title: String
    @Binding var focusX: Double
    @Binding var focusY: Double
    @Binding var zoom: Double

    @State private var focus: UnitPoint
    @State private var scale: Double
    /// Valores no início de cada gesto.
    @State private var dragStart: UnitPoint?
    @State private var pinchStart: Double?

    /// Proporções (largura ÷ altura) dos recortes da app.
    private enum Crop {
        /// Topo da página da receita (440 pt de altura num ecrã de 402 pt).
        static let recipeTop = 402.0 / 440.0
        static let card = 0.82
        static let recents = 1.45
        static let share = 1.0
        static let all = [recipeTop, card, recents, share]
    }

    init(image: UIImage, title: String, focusX: Binding<Double>, focusY: Binding<Double>, zoom: Binding<Double>) {
        self.image = image
        self.title = title
        _focusX = focusX
        _focusY = focusY
        _zoom = zoom
        _focus = State(initialValue: UnitPoint(x: focusX.wrappedValue, y: focusY.wrappedValue))
        _scale = State(initialValue: max(1, zoom.wrappedValue))
    }

    private var isDefault: Bool { focus == .center && scale == 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    recipeTopPreview
                    zoomControl
                    previews
                }
                .padding()
            }
            .navigationTitle("Enquadramento")
            .navigationBarTitleDisplayMode(.inline)
            // Arrastar a fotografia para baixo não pode fechar a janela sem querer.
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") {
                        focusX = focus.x
                        focusY = focus.y
                        zoom = scale
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Topo da receita (interativo)

    /// O recorte maior da app, com o título por cima como na página da receita.
    private var recipeTopPreview: some View {
        GeometryReader { geo in
            let size = geo.size
            FocusedImage(image: image, focus: focus, zoom: scale)
                .overlay(alignment: .bottomLeading) { titleOverlay }
                .contentShape(Rectangle())
                // Prioridade sobre o scroll: arrastar a fotografia não mexe na página.
                .highPriorityGesture(dragGesture(in: size))
                .simultaneousGesture(pinchGesture)
        }
        .aspectRatio(Crop.recipeTop, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text("Topo da receita")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
                .padding(10)
        }
        .accessibilityElement()
        .accessibilityLabel("Fotografia da receita")
        .accessibilityHint("Arrasta para escolher a parte que fica à vista; aperta para aproximar.")
    }

    /// A parte de baixo fica por trás do título na página da receita.
    private var titleOverlay: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground).opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 130)
            Text(title.isEmpty ? "Título da receita" : title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .lineLimit(2)
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private func dragGesture(in container: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let start = dragStart ?? focus
                if dragStart == nil { dragStart = focus }
                let frame = FocusedImage.frame(for: image.size, in: container, focus: start, zoom: scale)
                // Arrastar a fotografia para a direita mostra o que está à esquerda: o foco anda ao contrário.
                let x = start.x - value.translation.width / max(frame.width, 1)
                let y = start.y - value.translation.height / max(frame.height, 1)
                focus = clamped(UnitPoint(x: x, y: y))
            }
            .onEnded { _ in dragStart = nil }
    }

    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? scale
                if pinchStart == nil { pinchStart = scale }
                scale = min(FocusedImage.maxZoom, max(1, start * value.magnification))
                focus = clamped(focus)
            }
            .onEnded { _ in pinchStart = nil }
    }

    /// Limita o foco ao intervalo em que ainda muda algum dos recortes da app (fora dele, arrastar não faria nada).
    private func clamped(_ point: UnitPoint) -> UnitPoint {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return point }
        var minX = 0.5, maxX = 0.5, minY = 0.5, maxY = 0.5
        for aspect in Crop.all {
            let container = CGSize(width: aspect * 100, height: 100)
            let frame = FocusedImage.frame(for: size, in: container, focus: .center, zoom: scale)
            let halfX = container.width / 2 / frame.width
            let halfY = container.height / 2 / frame.height
            minX = min(minX, halfX); maxX = max(maxX, 1 - halfX)
            minY = min(minY, halfY); maxY = max(maxY, 1 - halfY)
        }
        return UnitPoint(x: min(maxX, max(minX, point.x)), y: min(maxY, max(minY, point.y)))
    }

    // MARK: - Zoom

    private var zoomControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value: Binding(get: { scale }, set: { scale = $0; focus = clamped(focus) }),
                       in: 1...FocusedImage.maxZoom)
                    .accessibilityLabel("Aproximar")
                    .accessibilityValue("\(Int((scale * 100).rounded())) por cento")
                Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Arrasta a fotografia para escolher o que fica à vista. Aperta com dois dedos para aproximar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Repor", systemImage: "arrow.counterclockwise") {
                    withAnimation(.snappy) {
                        focus = .center
                        scale = 1
                    }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.glass)
                .disabled(isDefault)
            }
        }
    }

    // MARK: - Outros recortes

    private var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Noutros sítios da app")
                .font(.headline)
            HStack(alignment: .top, spacing: 12) {
                preview("Cartão", aspect: Crop.card, radius: 14)
                preview("Recentes", aspect: Crop.recents, radius: 14)
                preview("Partilha", aspect: Crop.share, radius: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preview(_ title: String, aspect: CGFloat, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear
                .frame(width: 96 * aspect, height: 96)
                .overlay { FocusedImage(image: image, focus: focus, zoom: scale) }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .animation(.snappy, value: focus)
                .animation(.snappy, value: scale)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Imagem de demonstração para as capturas automáticas do CI (um prato fora do centro).
    static func demoImage() -> UIImage {
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor(red: 0.86, green: 0.78, blue: 0.66, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 60, y: 520, width: 420, height: 420))
            UIColor(red: 0.93, green: 0.55, blue: 0.2, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 150, y: 610, width: 240, height: 240))
            UIColor(red: 0.35, green: 0.6, blue: 0.3, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 600, y: 140, width: 180, height: 180))
        }
    }
}
