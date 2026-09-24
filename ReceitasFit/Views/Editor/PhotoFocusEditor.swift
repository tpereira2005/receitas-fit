import SwiftUI

/// Escolher o ponto da fotografia que fica sempre à vista nos recortes da app.
///
/// A fotografia aparece inteira; arrasta-se (ou toca-se) no ponto importante e as pré-visualizações
/// mostram logo como fica o cartão da grelha, o destaque de "Recentes" e o topo da receita.
struct PhotoFocusEditor: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    @Binding var focusX: Double
    @Binding var focusY: Double

    @State private var focus: UnitPoint

    init(image: UIImage, focusX: Binding<Double>, focusY: Binding<Double>) {
        self.image = image
        _focusX = focusX
        _focusY = focusY
        _focus = State(initialValue: UnitPoint(x: focusX.wrappedValue, y: focusY.wrappedValue))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    picker
                    previews
                }
                .padding()
            }
            .navigationTitle("Enquadramento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") {
                        focusX = focus.x
                        focusY = focus.y
                        dismiss()
                    }
                }
            }
        }
    }

    /// Fotografia inteira com o ponto de foco arrastável.
    private var picker: some View {
        VStack(spacing: 10) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay {
                    GeometryReader { geo in
                        let size = geo.size
                        ZStack {
                            Color.black.opacity(0.001)
                            focusMarker
                                .position(x: focus.x * size.width, y: focus.y * size.height)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    focus = UnitPoint(
                                        x: min(1, max(0, value.location.x / max(size.width, 1))),
                                        y: min(1, max(0, value.location.y / max(size.height, 1)))
                                    )
                                }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxHeight: 400)

            HStack(alignment: .firstTextBaseline) {
                Text("Arrasta o círculo para a parte mais importante da fotografia.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("Centrar", systemImage: "scope") {
                    withAnimation(.snappy) { focus = .center }
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.glass)
                .disabled(focus == .center)
            }
        }
    }

    private var focusMarker: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: 3)
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.35), radius: 6)
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .shadow(color: .black.opacity(0.35), radius: 3)
        }
        .accessibilityHidden(true)
    }

    /// Os mesmos recortes usados na app.
    private var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Como fica na app")
                .font(.headline)
            // Recortes com as proporções reais, em tamanho pequeno e à mesma altura.
            HStack(alignment: .top, spacing: 10) {
                preview("Cartão", aspect: 0.82, radius: 14)
                preview("Recentes", aspect: 1.45, radius: 14)
                preview("Receita", aspect: 1.9, radius: 12)
            }
            .frame(height: 98)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func preview(_ title: String, aspect: CGFloat, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Color.clear
                .frame(width: 76 * aspect, height: 76)
                .overlay { FocusedImage(image: image, focus: focus) }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .animation(.snappy, value: focus)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
