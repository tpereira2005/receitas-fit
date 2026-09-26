import SwiftUI

/// "O que há de novo": aparece uma vez depois de uma atualização com novidades
/// e pode ser aberto de novo nas Definições.
struct WhatsNewView: View {
    /// Aumentar quando houver novidades para mostrar.
    static let edition = 14
    static let title = "Novidades da versão 1.4"
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
        Item(symbol: "play.circle.fill", color: .green, title: "Modo cozinhar",
             detail: "Um passo de cada vez, em letra grande, com os ingredientes do passo e temporizadores."),
        Item(symbol: "snowflake", color: .cyan, title: "Congelador e esperas",
             detail: "“Congelei agora” avisa quando o gelado está pronto a processar."),
        Item(symbol: "scalemass.fill", color: .teal, title: "Pesos e doses",
             detail: "O peso ao lado das medidas, o peso de cada dose e o nome das porções (doses, fatias…)."),
        Item(symbol: "sun.max.fill", color: .yellow, title: "Ecrã aceso",
             detail: "Enquanto cozinhas o ecrã não se apaga, e o que marcaste fica guardado 12 horas."),
        Item(symbol: "viewfinder", color: .pink, title: "Enquadramento com zoom",
             detail: "Arrasta e aproxima a fotografia, com as pré-visualizações certas."),
        Item(symbol: "line.3.horizontal.decrease.circle.fill", color: .blue, title: "Filtros iguais em todo o lado",
             detail: "Receitas e Pesquisa com as mesmas categorias e o mesmo painel."),
        Item(symbol: "trash.fill", color: .red, title: "Apagadas recentemente",
             detail: "O que apagas fica 30 dias nas Definições, para poderes recuperar."),
        Item(symbol: "clock.arrow.circlepath", color: .indigo, title: "Restaurar cópias automáticas",
             detail: "Escolhe uma das cópias da pasta e a app acrescenta o que falta."),
        Item(symbol: "gearshape.fill", color: .gray, title: "Definições arrumadas",
             detail: "Uma página curta, com o estado de cada área, e etiquetas que podes criar."),
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
