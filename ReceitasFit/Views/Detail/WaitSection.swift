import SwiftUI
import SwiftData

/// Espera da receita (congelador, frigorífico, repouso): "Congelei agora", o tempo que falta
/// e, quando está pronta, "Processei" (que conta como "Fiz esta receita").
struct WaitSection: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context

    var body: some View {
        if let kind = recipe.waitKind {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                content(kind: kind, now: timeline.date)
            }
            .padding(18)
            .background(kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .animation(.snappy, value: recipe.frozenAt)
        }
    }

    @ViewBuilder
    private func content(kind: WaitKind, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: kind.symbol)
                    .font(.title2)
                    .foregroundStyle(kind.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(kind: kind, now: now))
                        .font(.headline)
                    Text(subtitle(kind: kind, now: now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            if let ready = WaitReminder.readyDate(of: recipe), let start = recipe.frozenAt, ready > now {
                ProgressView(value: now.timeIntervalSince(start), total: ready.timeIntervalSince(start))
                    .tint(kind.tint)
            }
            HStack(spacing: 10) {
                if recipe.frozenAt == nil {
                    Button {
                        WaitReminder.start(recipe)
                        save()
                    } label: {
                        Label(kind.startTitle, systemImage: kind.symbol)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(kind.tint)
                } else {
                    Button {
                        WaitReminder.finish(recipe)
                        Haptics.success()
                        save()
                    } label: {
                        Label(kind.finishTitle, systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(WaitReminder.isReady(recipe, now: now) ? Color.accentColor : kind.tint)
                    Button("Cancelar", systemImage: "xmark") {
                        WaitReminder.cancel(recipe)
                        save()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel("Cancelar a espera")
                }
            }
        }
    }

    private func title(kind: WaitKind, now: Date) -> String {
        guard recipe.frozenAt != nil else { return kind.phrase(recipe.waitMinutes).capitalizedFirst }
        return WaitReminder.isReady(recipe, now: now) ? kind.readyTitle : kind.waitingTitle
    }

    private func subtitle(kind: WaitKind, now: Date) -> String {
        guard let ready = WaitReminder.readyDate(of: recipe) else {
            return "Toca quando começares e avisamos-te quando estiver pronta."
        }
        if ready <= now { return "Desde \(Self.moment(ready, now: now))." }
        let left = Int(ready.timeIntervalSince(now) / 60) + 1
        return "\(Format.remaining(left)) · pronta \(Self.moment(ready, now: now))."
    }

    /// "hoje às 22:30", "amanhã às 09:00", "sábado às 10:00".
    static func moment(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return "hoje às \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "amanhã às \(time)"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "ontem às \(time)"
        }
        return "\(date.formatted(.dateTime.weekday(.wide))) às \(time)"
    }

    private func save() {
        try? context.save()
    }
}

extension WaitKind {
    var tint: Color {
        switch self {
        case .freezer: .cyan
        case .fridge: .blue
        case .rest: .orange
        }
    }

    /// Título quando já passou o tempo de espera.
    var readyTitle: String {
        switch self {
        case .freezer: "Pronto a processar"
        case .fridge, .rest: "Pronta a comer"
        }
    }
}
