import SwiftUI
import UIKit

/// Campo numérico que atualiza o valor a cada tecla.
///
/// O `TextField(value:format:)` do SwiftUI só grava o valor quando o campo perde o foco, por isso
/// tocar em "Guardar" com um campo ainda a ser editado podia perder o último número.
/// Aceita vírgula ou ponto como separador decimal.
struct NumberField: View {
    let placeholder: String
    @Binding var value: Double?
    var maxFractionDigits = 2
    /// Abre o teclado assim que o campo aparece.
    var focusOnAppear = false

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(maxFractionDigits == 0 ? .numberPad : .decimalPad)
            .focused($focused)
            .onAppear {
                text = Self.format(value, maxFractionDigits)
                if focusOnAppear { focused = true }
            }
            .onChange(of: text) { _, newText in
                let parsed = Self.parse(newText)
                if parsed != value { value = parsed }
            }
            .onChange(of: value) { _, newValue in
                // Valor alterado por fora (por exemplo "Usar este valor"): atualiza o texto.
                if !focused, Self.parse(text) != newValue {
                    text = Self.format(newValue, maxFractionDigits)
                }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = Self.format(value, maxFractionDigits) }
            }
    }

    nonisolated static func parse(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.hasSuffix(".") { return Double(cleaned.dropLast()) }
        return Double(cleaned)
    }

    nonisolated static func format(_ value: Double?, _ digits: Int) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...digits)).grouping(.never))
    }
}

extension NumberField {
    /// Campo para um `Double` obrigatório (vazio conta como 0).
    init(_ placeholder: String, value: Binding<Double>, maxFractionDigits: Int = 2) {
        self.init(
            placeholder: placeholder,
            value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0 ?? 0 }),
            maxFractionDigits: maxFractionDigits
        )
    }

    /// Campo para um `Int` (minutos, porções…).
    init(_ placeholder: String, integer: Binding<Int>) {
        self.init(
            placeholder: placeholder,
            value: Binding(
                get: { Double(integer.wrappedValue) },
                set: { integer.wrappedValue = Int(($0 ?? 0).rounded()) }
            ),
            maxFractionDigits: 0
        )
    }
}

extension View {
    /// Botão "OK" por cima do teclado, para o fechar (o teclado numérico não tem tecla de retorno).
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

/// Respostas táteis para ações que não dependem de uma mudança de estado visível.
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
