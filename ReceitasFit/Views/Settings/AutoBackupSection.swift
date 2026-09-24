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
        // O estado fica num cartão próprio e as ações num segundo cartão logo abaixo.
        // Com o estado e as ações na mesma secção, a lista deixava 1 píxel do fundo à vista
        // por baixo do separador da linha de estado.
        Section {
            statusCard
        } header: {
            Text("Cópias automáticas")
        }
        .listSectionSpacing(.compact)

        Section {
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
        .animation(.snappy, value: backup.folderName)
        .animation(.snappy, value: backup.isRunning)
        .animation(.snappy, value: backup.lastError)
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
