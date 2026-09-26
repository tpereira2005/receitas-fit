import SwiftUI
import SwiftData

/// Modo cozinhar: um passo de cada vez em letra grande, com os ingredientes desse passo,
/// temporizadores tirados do texto e o ecrã sempre aceso.
struct CookingModeView: View {
    @Bindable var recipe: Recipe
    /// Escala das quantidades (porções escolhidas na receita ÷ porções da receita).
    let scale: Double
    @Binding var completedSteps: Set<UUID>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var index: Int
    @State private var showingIngredients = false
    @State private var finished = false
    private let timers = CookingTimers.shared

    init(recipe: Recipe, scale: Double, completedSteps: Binding<Set<UUID>>, startAt: Int? = nil) {
        self.recipe = recipe
        self.scale = scale
        _completedSteps = completedSteps
        let steps = recipe.steps
        // Começa no primeiro passo por fazer.
        let first = steps.firstIndex { !completedSteps.wrappedValue.contains($0.id) } ?? 0
        _index = State(initialValue: min(startAt ?? first, max(0, steps.count - 1)))
    }

    private var steps: [RecipeStep] { recipe.steps }
    private var isLast: Bool { index >= steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal)
                    .padding(.top, 8)
                TabView(selection: $index) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                        stepPage(step, number: offset + 1)
                            .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: index)
                ActiveTimersBar()
                    .animation(.snappy, value: timers.timers)
                controls
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Ingredientes", systemImage: "list.bullet") { showingIngredients = true }
                }
            }
            .sheet(isPresented: $showingIngredients) {
                CookingIngredientsSheet(recipe: recipe, scale: scale)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $finished) {
                CookingFinishedSheet(recipe: recipe) { dismiss() }
                    .presentationDetents([.medium])
            }
        }
        .onAppear { ScreenAwake.set("cooking", true) }
        .onDisappear { ScreenAwake.set("cooking", false) }
        .sensoryFeedback(.selection, trigger: index)
    }

    // MARK: - Progresso

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { offset, step in
                Capsule()
                    .fill(offset == index ? Color.accentColor
                          : completedSteps.contains(step.id) ? Color.accentColor.opacity(0.45) : Color(.tertiarySystemFill))
                    .frame(height: 5)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel("Passo \(index + 1) de \(steps.count)")
    }

    // MARK: - Passo

    private func stepPage(_ step: RecipeStep, number: Int) -> some View {
        let ingredients = StepAnalysis.ingredients(in: step.text, from: recipe.ingredients)
        let durations = StepAnalysis.durations(in: step.text)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Passo \(number) de \(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(step.text)
                    .font(.system(.title, design: .rounded, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                if !durations.isEmpty {
                    FlowLayout(spacing: 10) {
                        ForEach(durations, id: \.self) { duration in
                            StepTimerButton(duration: duration, stepID: step.id, stepNumber: number, recipe: recipe, large: true)
                        }
                    }
                }

                if !ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Neste passo")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(ingredients) { ingredient in
                            CookingIngredientRow(ingredient: ingredient, scale: scale)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Anterior e seguinte

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { index = max(0, index - 1) }
            } label: {
                Label("Anterior", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .disabled(index == 0)

            Button {
                guard steps.indices.contains(index) else { return }
                withAnimation(.snappy) {
                    completedSteps.insert(steps[index].id)
                    if isLast { finished = true } else { index += 1 }
                }
            } label: {
                Label(isLast ? "Terminar" : "Seguinte", systemImage: isLast ? "checkmark" : "chevron.right")
                    .labelStyle(TrailingIconLabelStyle(trailing: !isLast))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

/// Ícone à direita do texto ("Seguinte ›").
private struct TrailingIconLabelStyle: LabelStyle {
    var trailing = true

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if !trailing { configuration.icon }
            configuration.title
            if trailing { configuration.icon }
        }
    }
}

/// Um ingrediente no modo cozinhar: quantidade em destaque e o peso quando a medida não é em gramas.
struct CookingIngredientRow: View {
    let ingredient: Ingredient
    let scale: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let amount = ingredient.amountText(scale: scale) {
                Text(amount).fontWeight(.semibold)
            } else if !ingredient.unit.isEmpty {
                Text(ingredient.unit).foregroundStyle(.secondary)
            }
            Text(ingredient.name)
            if let weight = ingredient.weightText(scale: scale) {
                Text("(\(weight))").foregroundStyle(.secondary)
            }
        }
        .font(.title3)
    }
}

/// Todos os ingredientes, para consultar a meio de um passo.
private struct CookingIngredientsSheet: View {
    let recipe: Recipe
    let scale: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(recipe.ingredients) { ingredient in
                CookingIngredientRow(ingredient: ingredient, scale: scale)
                    .font(.body)
            }
            .navigationTitle("Ingredientes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}

/// Fim do modo cozinhar: registar "Fiz esta receita" ou, se a receita tiver espera, começá-la.
private struct CookingFinishedSheet: View {
    @Bindable var recipe: Recipe
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
                .padding(.top, 28)
            Text("Receita terminada")
                .font(.title2.bold())
            if let kind = recipe.waitKind, recipe.frozenAt == nil {
                Text("Falta a espera: \(kind.phrase(recipe.waitMinutes)). Avisamos-te quando estiver pronta.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    WaitReminder.start(recipe)
                    close()
                } label: {
                    Label(kind.startTitle, systemImage: kind.symbol)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                Button("Fechar") { close() }
                    .buttonStyle(.glass)
            } else {
                Text("Regista que a fizeste para a veres em “Feitas recentemente”.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button {
                    if recipe.frozenAt != nil {
                        WaitReminder.finish(recipe)
                    } else {
                        recipe.cookedDates.append(.now)
                        CookingProgress.clear(for: recipe.id)
                    }
                    Haptics.success()
                    close()
                } label: {
                    Label("Fiz esta receita", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                Button("Agora não") { close() }
                    .buttonStyle(.glass)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
    }

    private func close() {
        try? context.save()
        // Fecha o modo cozinhar (e esta folha com ele).
        onClose()
    }
}
