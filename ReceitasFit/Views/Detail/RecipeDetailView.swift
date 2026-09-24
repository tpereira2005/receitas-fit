import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query private var foods: [Food]
    @State private var servings: Int
    @State private var checkedIngredients: Set<UUID> = []
    @State private var completedSteps: Set<UUID> = []
    @State private var showingEditor = false
    @State private var showingDuplicate = false
    @State private var showingShare = ScreenshotMode.flag("screenshotShare")
    @State private var confirmDelete = false
    @State private var showsCompactTitle = false

    /// Altura da fotografia.
    private let heroHeight: CGFloat = 440
    /// Quanto o brilho desfocado da foto se prolonga por baixo do título.
    private let glowExtent: CGFloat = 300
    /// Quanto o título sobe para dentro da zona onde a foto se dissolve.
    private let headerOverlap: CGFloat = 96

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: max(1, recipe.servings))
    }

    private var scale: Double { Double(servings) / Double(max(1, recipe.servings)) }
    private var foodIndex: [UUID: Food] { NutritionCalculator.index(foods) }

    var body: some View {
        // Depois de apagar, a vista ainda é desenhada durante a animação de saída:
        // não pode ler propriedades de uma receita que já não existe.
        if recipe.isDeleted || recipe.modelContext == nil {
            Color(.systemBackground)
        } else {
            content
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    header
                        .padding(.horizontal)
                        .padding(.top, -headerOverlap)
                    nutritionCard
                        .padding(.horizontal)
                        .id("nutrition")
                    ingredientsSection
                        .padding(.horizontal)
                    stepsSection
                        .padding(.horizontal)
                    CookedSection(recipe: recipe)
                        .padding(.horizontal)
                        .id("cooked")
                    extrasSection
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > heroHeight - headerOverlap + 10
            } action: { _, isPastHeader in
                withAnimation(.easeInOut(duration: 0.25)) { showsCompactTitle = isPastHeader }
            }
            .scrollEdgeEffectHidden(!showsCompactTitle, for: .top)
            .ignoresSafeArea(edges: .top)
            .task {
                // Usado apenas nas capturas automáticas do CI.
                let showsCooked = ScreenshotMode.flag("screenshotDetailCooked")
                guard ScreenshotMode.flag("screenshotDetailScroll") || showsCooked else { return }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation { proxy.scrollTo(showsCooked ? "cooked" : "nutrition", anchor: showsCooked ? .center : .top) }
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingDuplicate) {
            RecipeEditorView(duplicating: recipe)
        }
        .sheet(isPresented: $showingShare) {
            RecipeShareView(recipe: recipe)
        }
        .sheet(isPresented: $showingEditor) {
            RecipeEditorView(recipe: recipe)
        }
        .alert("Apagar receita?", isPresented: $confirmDelete) {
            Button("Apagar", role: .destructive, action: deleteRecipe)
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("“\(recipe.title)” será apagada deste iPhone. Esta ação não pode ser anulada.")
        }
        .onChange(of: recipe.servings) { _, newValue in
            servings = max(1, newValue)
        }
        .sensoryFeedback(.selection, trigger: servings)
        .sensoryFeedback(.impact(weight: .light), trigger: checkedIngredients)
        .sensoryFeedback(.impact(weight: .light), trigger: completedSteps)
        .sensoryFeedback(trigger: recipe.isFavorite) { _, isFavorite in
            isFavorite ? .success : .impact(weight: .light)
        }
    }

    // MARK: - Fotografia

    /// A fotografia dissolve-se num brilho desfocado com as suas próprias cores, que continua por baixo
    /// do título e desaparece suavemente no fundo — em vez de terminar num bloco de cor sólida.
    private var hero: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            let pull = max(0, minY)
            let scrolled = max(0, -minY)
            let width = geo.size.width

            ZStack(alignment: .top) {
                // 1. Brilho ambiente
                RecipePhoto(recipe: recipe, variant: .thumbnail, symbolSize: 60)
                    .frame(width: width, height: heroHeight + glowExtent + pull)
                    .clipped()
                    .blur(radius: 70, opaque: true)
                    .saturation(1.35)
                    .opacity(colorScheme == .dark ? 0.55 : 0.42)
                    .mask {
                        LinearGradient(stops: EasedGradient.fadeOut(from: 0.35, to: 1), startPoint: .top, endPoint: .bottom)
                    }

                // 2. Fotografia nítida, com paralaxe suave ao fazer scroll
                RecipePhoto(recipe: recipe, variant: .full, symbolSize: 96)
                    .frame(width: width, height: heroHeight + pull)
                    .clipped()
                    .mask {
                        LinearGradient(stops: EasedGradient.fadeOut(from: 0.42, to: 0.93), startPoint: .top, endPoint: .bottom)
                    }
                    .offset(y: scrolled * 0.35)

                // 3. Véu discreto no topo para a barra de estado e os botões
                LinearGradient(
                    stops: EasedGradient.fadeOut(color: Color(.systemBackground), from: 0, to: 1),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .opacity(0.45)
            }
            .offset(y: -pull)
            .allowsHitTesting(false)
        }
        .frame(height: heroHeight)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipeCategoryLabel(category: recipe.category)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(recipe.category.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(recipe.category.color.opacity(0.16), in: .capsule)
            Text(recipe.title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            if !recipe.summary.isEmpty {
                Text(recipe.summary)
                    .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if recipe.prepMinutes > 0 {
                        InfoPill(symbol: "timer", text: "Prep. \(Format.minutes(recipe.prepMinutes))")
                    }
                    if recipe.cookMinutes > 0 {
                        InfoPill(symbol: "frying.pan", text: "Confeção \(Format.minutes(recipe.cookMinutes))")
                    }
                    InfoPill(symbol: "person.2", text: Format.servings(recipe.servings))
                    if recipe.timesCooked > 0 {
                        InfoPill(symbol: "checkmark.circle", text: recipe.timesCooked == 1 ? "Feita 1 vez" : "Feita \(recipe.timesCooked) vezes")
                    }
                    ForEach(recipe.tags, id: \.self) { tag in
                        InfoPill(symbol: "tag", text: tag)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Nutrição

    private var nutritionCard: some View {
        let summary = NutritionCalculator.summarize(recipe.ingredients, foods: foodIndex)
        let perServing: NutritionFacts
        var note: String?
        if summary.linked > 0 || recipe.nutritionIsComputed {
            perServing = summary.total.scaled(by: 1 / Double(max(1, recipe.servings)))
            if summary.unresolved == 1 {
                note = "1 ingrediente não conta para estes valores."
            } else if summary.unresolved > 1 {
                note = "\(summary.unresolved) ingredientes não contam para estes valores."
            }
        } else {
            perServing = recipe.perServing
            if !perServing.isEmpty {
                note = "Valores introduzidos à mão. Edita a receita e escolhe os ingredientes da biblioteca para passarem a ser calculados."
            }
        }
        return NutritionCard(perServing: perServing, servings: servings, originalServings: recipe.servings, note: note)
    }

    // MARK: - Ingredientes

    private var ingredientsSection: some View {
        let ingredients = recipe.ingredients
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Ingredientes").font(.title2.bold())
                Spacer()
                servingsStepper
            }
            if ingredients.isEmpty {
                Text("Sem ingredientes registados.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(ingredients) { ingredient in
                        ingredientRow(ingredient)
                        if ingredient.id != ingredients.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    private var servingsStepper: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.snappy) { servings = max(1, servings - 1) }
            } label: {
                Image(systemName: "minus").frame(width: 34, height: 34)
            }
            .disabled(servings <= 1)
            Text(Format.servings(servings))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 78)
            Button {
                withAnimation(.snappy) { servings = min(99, servings + 1) }
            } label: {
                Image(systemName: "plus").frame(width: 34, height: 34)
            }
        }
        .font(.subheadline.weight(.bold))
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        let checked = checkedIngredients.contains(ingredient.id)
        let food = ingredient.foodID.flatMap { foodIndex[$0] }
        let calories = NutritionCalculator.facts(for: ingredient, food: food).map { $0.calories * scale }
        return Button {
            withAnimation(.snappy) {
                if checked { checkedIngredients.remove(ingredient.id) } else { checkedIngredients.insert(ingredient.id) }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                ingredientText(ingredient, name: ingredient.name)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                if let calories, calories >= 1 {
                    Text("\(Int(calories.rounded())) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func ingredientText(_ ingredient: Ingredient, name: String) -> Text {
        if let amount = ingredient.amountText(scale: scale) {
            return Text("\(Text(amount).fontWeight(.semibold))  \(name)")
        }
        if ingredient.unit.isEmpty {
            return Text(name)
        }
        return Text("\(name)  \(Text(ingredient.unit).foregroundStyle(.secondary))")
    }

    // MARK: - Preparação

    private var stepsSection: some View {
        let steps = recipe.steps
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Preparação").font(.title2.bold())
                Spacer()
                if !steps.isEmpty {
                    Text("\(completedSteps.count)/\(steps.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            if steps.isEmpty {
                Text("Sem passos registados.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                stepRow(number: index + 1, step: step)
            }
        }
    }

    private func stepRow(number: Int, step: RecipeStep) -> some View {
        let done = completedSteps.contains(step.id)
        return Button {
            withAnimation(.snappy) {
                if done { completedSteps.remove(step.id) } else { completedSteps.insert(step.id) }
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(done ? Color.accentColor : Color.accentColor.opacity(0.15))
                    if done {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 30, height: 30)
                Text(step.text)
                    .foregroundStyle(done ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notas e origem

    private var extrasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !recipe.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notas", systemImage: "note.text")
                        .font(.headline)
                    Text(recipe.notes)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            if let link = recipe.sourceLink {
                Link(destination: link) {
                    Label(sourceTitle(for: link), systemImage: "arrow.up.right.square")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
            }
            Text(datesText)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
    }

    private var datesText: String {
        let added = "Adicionada a \(recipe.createdAt.formatted(date: .long, time: .omitted))"
        guard !Calendar.current.isDate(recipe.updatedAt, inSameDayAs: recipe.createdAt) else { return added }
        return added + " · editada a \(recipe.updatedAt.formatted(date: .long, time: .omitted))"
    }

    private func sourceTitle(for url: URL) -> String {
        let host = url.host()?.lowercased() ?? ""
        if host.contains("instagram") { return "Ver no Instagram" }
        if host.contains("tiktok") { return "Ver no TikTok" }
        if host.contains("youtube") || host.contains("youtu.be") { return "Ver no YouTube" }
        if host.contains("pinterest") { return "Ver no Pinterest" }
        return "Abrir receita original"
    }

    // MARK: - Barra superior

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(recipe.title)
                .font(.headline)
                .lineLimit(1)
                .opacity(showsCompactTitle ? 1 : 0)
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.snappy) { recipe.isFavorite.toggle() }
            } label: {
                Label(recipe.isFavorite ? "Remover das favoritas" : "Favorita", systemImage: recipe.isFavorite ? "heart.fill" : "heart")
                    .symbolEffect(.bounce, value: recipe.isFavorite)
            }
            .tint(recipe.isFavorite ? Color.pink : Color.primary)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Editar", systemImage: "pencil") { showingEditor = true }
                Button("Duplicar", systemImage: "plus.square.on.square") { showingDuplicate = true }
                Button("Partilhar", systemImage: "square.and.arrow.up") { showingShare = true }
                Divider()
                Button("Apagar", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Label("Mais", systemImage: "ellipsis")
            }
        }
    }

    private func deleteRecipe() {
        Haptics.warning()
        context.delete(recipe)
        try? context.save()
        dismiss()
    }
}

/// Gradientes com curva suave (smootherstep), para as transições não terem um início ou fim visível.
enum EasedGradient {
    static func fadeOut(color: Color = .black, from start: Double, to end: Double, steps: Int = 24) -> [Gradient.Stop] {
        var stops = [Gradient.Stop(color: color, location: 0)]
        for step in 0...steps {
            let t = Double(step) / Double(steps)
            let eased = t * t * t * (t * (t * 6 - 15) + 10)
            stops.append(Gradient.Stop(color: color.opacity(1 - eased), location: start + (end - start) * t))
        }
        stops.append(Gradient.Stop(color: color.opacity(0), location: 1))
        return stops
    }
}
