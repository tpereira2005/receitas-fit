import SwiftUI

/// Cartão de estado das Definições (cópias automáticas, leitura de embalagens…):
/// ícone colorido, título e uma linha de detalhe.
///
/// Fica numa secção própria, com as ações numa segunda secção logo abaixo
/// (`.listSectionSpacing(.compact)`): com uma linha a seguir na mesma secção, a lista deixava
/// 1 píxel do fundo à vista por baixo do separador.
struct SettingsStatusCard<Subtitle: View>: View {
    let symbol: String
    let color: Color
    let title: String
    var isAnimating = false
    @ViewBuilder let subtitle: Subtitle

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.rotate, options: .repeating, isActive: isAnimating)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .contentTransition(.opacity)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

extension SettingsStatusCard where Subtitle == Text {
    init(symbol: String, color: Color, title: String, subtitle: String, isAnimating: Bool = false) {
        self.init(symbol: symbol, color: color, title: title, isAnimating: isAnimating) { Text(subtitle) }
    }
}

/// Linha da página principal das Definições, como nos Ajustes do iPhone:
/// ícone num quadrado colorido, título e o estado atual à direita.
struct SettingsRow: View {
    let title: String
    let symbol: String
    let color: Color
    var value: String?
    var valueColor: Color = .secondary

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(symbol: symbol, color: color)
            Text(title)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Ícone branco num quadrado de cantos arredondados, com o gradiente de uma cor.
struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
            .accessibilityHidden(true)
    }
}
