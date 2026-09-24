import SwiftUI
import SwiftData

/// Secção "Cópias automáticas" das Definições.
///
/// Um cartão de estado no topo resume tudo (ativas, a copiar, com erro ou desativadas);
/// por baixo ficam só as ações que fazem sentido nesse estado.
struct AutoBackupSection: View {
    @Environment(\.modelContext) private var context
    let onChooseFolder: () -> Void
    let onDisable: () -> Void

    private let backup = AutoBackup.shared
    /// Mostra "Cópia guardada" no botão durante uns segundos depois de uma cópia manual.
    @State private var justSaved = false

    private enum Status {
        case off, ready, running, failed(String)
    }

    private var status: Status {
        guard backup.folderName != nil, backup.isEnabled else { return .off }
        if backup.isRunning { return .running }
        if let error = backup.lastError { return .failed(error) }
        return .ready
    }

    var body: some View {
        Section {
            statusCard
            switch status {
            case .off:
                Button(action: onChooseFolder) {
                    Label("Escolher pasta", systemImage: "folder.badge.plus")
                }
            case .ready, .running, .failed:
                if let folder = backup.folderName {
                    LabeledContent("Pasta", value: folder)
                }
                backupNowButton
                Button(action: onChooseFolder) {
                    Label("Mudar de pasta", systemImage: "folder")
                }
                Button(role: .destructive, action: onDisable) {
                    Label("Desativar cópias automáticas", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Cópias automáticas")
        } footer: {
            footer
        }
        .animation(.snappy, value: backup.folderName)
        .animation(.snappy, value: backup.isRunning)
        .animation(.snappy, value: backup.lastError)
        .animation(.snappy, value: justSaved)
    }

    // MARK: - Cartão de estado

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.rotate, options: .repeating, isActive: isRunning)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .modifier(WholePointHeight())
    }

    private var isRunning: Bool {
        if case .running = status { return true }
        return false
    }

    private var symbol: String {
        switch status {
        case .off: "icloud.slash"
        case .ready: "checkmark.icloud"
        case .running: "arrow.triangle.2.circlepath"
        case .failed: "exclamationmark.icloud"
        }
    }

    private var color: Color {
        switch status {
        case .off: .gray
        case .ready, .running: .green
        case .failed: .orange
        }
    }

    private var title: String {
        switch status {
        case .off: "Desativadas"
        case .ready: "Ativas"
        case .running: "A guardar cópia…"
        case .failed: "A última cópia falhou"
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        switch status {
        case .off:
            Text("Escolhe uma pasta e a app guarda lá uma cópia por dia.")
        case .running:
            Text("Receitas, alimentos e fotografias.")
        case .failed(let message):
            Text(message)
        case .ready:
            if let date = backup.lastDate {
                // Atualiza o "há x minutos" enquanto as Definições estão abertas.
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    Text("Última cópia \(Self.relative(date, now: timeline.date))")
                }
            } else {
                Text("Ainda sem cópias.")
            }
        }
    }

    private static func relative(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 { return "agora mesmo" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: now)
    }

    // MARK: - Ações

    private var backupNowButton: some View {
        Button {
            Task {
                if await backup.run(context: context, force: true) {
                    Haptics.success()
                    justSaved = true
                    try? await Task.sleep(for: .seconds(2.5))
                    justSaved = false
                } else {
                    Haptics.warning()
                }
            }
        } label: {
            if justSaved {
                Label("Cópia guardada", systemImage: "checkmark")
            } else if case .failed = status {
                Label("Tentar outra vez", systemImage: "arrow.clockwise")
            } else {
                Label("Fazer cópia agora", systemImage: "arrow.clockwise.icloud")
            }
        }
        .contentTransition(.symbolEffect(.replace))
        .disabled(isRunning || justSaved)
    }

    private var footer: some View {
        Text("Uma cópia por dia, quando abres ou sais da app, e só se algo mudou. Ficam as \(AutoBackup.keepCount) mais recentes, com as fotografias; os outros ficheiros da pasta nunca são tocados. Uma pasta no iCloud Drive mantém-nas fora do iPhone.")
    }
}

/// Arredonda a altura da linha para pontos inteiros.
///
/// Com texto e ícone, a altura natural desta linha é fracionária; a lista arredonda a posição
/// da linha seguinte e fica uma fresta de 1 píxel com a cor do fundo por baixo do separador.
private struct WholePointHeight: ViewModifier {
    func body(content: Content) -> some View {
        WholePointLayout { content }
    }
}

private struct WholePointLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let size = subview.sizeThatFits(proposal)
        return CGSize(width: size.width, height: size.height.rounded(.up))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        subview.place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(bounds.size))
    }
}
