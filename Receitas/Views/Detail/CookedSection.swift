import SwiftUI
import SwiftData

/// "Fiz esta receita": regista cada vez que a receita é feita, com contador e histórico de datas.
struct CookedSection: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context

    /// Data acabada de registar, para permitir anular durante uns segundos.
    @State private var justAdded: Date?
    @State private var showingHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: recipe.timesCooked > 0 ? "checkmark.circle.fill" : "frying.pan.fill")
                    .font(.title2)
                    .foregroundStyle(recipe.timesCooked > 0 ? Color.green : recipe.category.color)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .contentTransition(.numericText())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if let justAdded {
                    Button {
                        withAnimation(.snappy) {
                            if let index = recipe.cookedDates.lastIndex(of: justAdded) {
                                recipe.cookedDates.remove(at: index)
                            }
                            self.justAdded = nil
                        }
                        try? context.save()
                    } label: {
                        Label("Anular", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                } else {
                    Button(action: markCooked) {
                        Label("Fiz esta receita", systemImage: "checkmark")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                }
                if recipe.timesCooked > 0 {
                    Button {
                        showingHistory = true
                    } label: {
                        Label("Histórico", systemImage: "calendar")
                            .labelStyle(.iconOnly)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Histórico")
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(.snappy, value: recipe.timesCooked)
        .sensoryFeedback(.success, trigger: recipe.timesCooked) { old, new in new > old }
        .sheet(isPresented: $showingHistory) {
            CookedHistoryView(recipe: recipe)
                .presentationDetents([.medium, .large])
        }
    }

    private var title: String {
        switch recipe.timesCooked {
        case 0: "Ainda não fizeste esta receita"
        case 1: "Feita 1 vez"
        default: "Feita \(recipe.timesCooked) vezes"
        }
    }

    private var subtitle: String {
        if justAdded != nil { return "Registado hoje." }
        guard let last = recipe.lastCookedAt else { return "Toca no botão quando a fizeres." }
        return "Última: \(Format.relativeDay(last))"
    }

    private func markCooked() {
        let now = Date.now
        withAnimation(.snappy) {
            recipe.cookedDates.append(now)
            justAdded = now
        }
        try? context.save()
        Task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.snappy) { if justAdded == now { justAdded = nil } }
        }
    }
}

/// Lista das vezes que a receita foi feita; desliza para apagar uma data.
struct CookedHistoryView: View {
    @Bindable var recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private var dates: [Date] { recipe.cookedDates.sorted(by: >) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(dates, id: \.self) { date in
                        LabeledContent {
                            Text(Format.relativeDay(date))
                        } label: {
                            Text(date.formatted(date: .complete, time: .omitted).capitalizedFirst)
                        }
                    }
                    .onDelete { offsets in
                        let removed = offsets.map { dates[$0] }
                        recipe.cookedDates.removeAll { removed.contains($0) }
                        try? context.save()
                    }
                } footer: {
                    Text("Desliza para a esquerda para apagar um registo feito por engano.")
                }
            }
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") { dismiss() }
                }
            }
            .overlay {
                if dates.isEmpty {
                    ContentUnavailableView("Sem registos", systemImage: "calendar")
                }
            }
        }
    }
}
