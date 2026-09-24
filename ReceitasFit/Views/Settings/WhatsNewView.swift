import SwiftUI

/// "O que há de novo": aparece uma vez depois de uma atualização com novidades
/// e pode ser aberto de novo nas Definições.
struct WhatsNewView: View {
    /// Aumentar quando houver novidades para mostrar.
    static let edition = 13
    static let title = "Novidades da versão 1.3"
    static let seenKey = "whatsNewSeenEdition"

    @Environment(\.dismiss) private var dismiss

    private struct Item: Identifiable {
        let symbol: String
        let color: Color
        let title: String
        let detail: String
        var id: String { title }
    }

    private let items: [Item] = [
        Item(symbol: "house.fill", color: .green, title: "Novo Início",
             detail: "Recentes, feitas recentemente, favoritas, categorias e coleções num só sítio."),
        Item(symbol: "line.3.horizontal.decrease.circle.fill", color: .blue, title: "Filtros combinados",
             detail: "No separador Receitas, junta categorias, coleções, etiquetas e o que já fizeste."),
        Item(symbol: "magnifyingglass", color: .indigo, title: "Pesquisa melhor",
             detail: "Encontra receitas e alimentos, com as pesquisas recentes à mão."),
        Item(symbol: "checkmark.circle.fill", color: .orange, title: "Fiz esta receita",
             detail: "Regista quando fazes uma receita e vê o histórico."),
        Item(symbol: "barcode.viewfinder", color: .purple, title: "Ler embalagens",
             detail: "Fotografa o rótulo e os valores ficam preenchidos para rever antes de guardar."),
        Item(symbol: "scalemass.fill", color: .teal, title: "Porções e colheres",
             detail: "\u{201C}1 scoop = 30 g\u{201D} e o peso das colheres de cada alimento."),
        Item(symbol: "camera.fill", color: .pink, title: "Fotografias e partilha",
             detail: "Câmara, Ficheiros, enquadramento, duplicar e imagens para partilhar ou Stories."),
        Item(symbol: "icloud.fill", color: .cyan, title: "Cópias automáticas",
             detail: "Uma cópia por dia numa pasta à tua escolha, com as fotografias."),
        Item(symbol: "sparkle.magnifyingglass", color: .gray, title: "Spotlight e Siri",
             detail: "As receitas aparecem na pesquisa do iPhone e há atalhos para as abrir ou registar."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("O que há de novo")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(Self.title)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(items) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.symbol)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text("Continuar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
    }
}
