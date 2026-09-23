import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Int
    @State private var checkedIngredients: Set<UUID> = []
    @State private var completedSteps: Set<UUID> = []
    @State private var showingEditor = false
    @State private var confirmDelete = false

    private let heroHeight: CGFloat = 400

    init(recipe: Recipe) {
        self.recipe = recipe
        _servings = State(initialValue: max(1, recipe.servings))
    }

    private var scale: Double { Double(servings) / Double(max(1, recipe.servings)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                header
                    .padding(.horizontal)
                    .padding(.top, -36)
                NutritionCard(recipe: recipe)
                    .padding(.horizontal)
                ingredientsSection
                    .padding(.horizontal)
                stepsSection
                    .padding(.horizontal)
                extrasSection
                    .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEditor) {
            RecipeEditorView(recipe: recipe)
        }
        .confirmationDialog("Apagar esta receita?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Apagar receita", role: .destructive, action: deleteRecipe)
        } message: {
            Text("Esta ação não pode ser anulada.")
        }
        .onChange(of: recipe.servings) { _, newValue in
            servings = max(1, newValue)
        }
    }

    // MARK: - Secções

    private var hero: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            let stretch = max(0, minY)
            RecipePhoto(recipe: recipe, variant: .full, symbolSize: 90)
                .frame(width: geo.size.width, height: heroHeight + stretch)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 110)
                }
                .offset(y: -stretch)
        }
        .frame(height: heroHeight)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(recipe.category.title, systemImage: recipe.category.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(recipe.category.color)
            Text(recipe.title)
                .font(.largeTitle.bold())
                .fontDesign(.rounded)
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
                    ForEach(recipe.tags, id: \.self) { tag in
                        InfoPill(symbol: "tag", text: tag)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

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
                ingredientText(ingredient)
                    .strikethrough(checked)
                    .foregroundStyle(checked ? Color.secondary : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func ingredientText(_ ingredient: Ingredient) -> Text {
        if let amount = ingredient.amountText(scale: scale) {
            return Text("\(Text(amount).fontWeight(.semibold))  \(ingredient.name)")
        }
        if ingredient.unit.isEmpty {
            return Text(ingredient.name)
        }
        return Text("\(ingredient.name)  \(Text(ingredient.unit).foregroundStyle(.secondary))")
    }

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

    @ViewBuilder
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
            Text("Adicionada a \(recipe.createdAt.formatted(date: .long, time: .omitted))")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
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
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                withAnimation(.snappy) { recipe.isFavorite.toggle() }
            } label: {
                Label(recipe.isFavorite ? "Remover das favoritas" : "Favorita", systemImage: recipe.isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(recipe.isFavorite ? Color.pink : Color.primary)
                    .symbolEffect(.bounce, value: recipe.isFavorite)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Editar", systemImage: "pencil") { showingEditor = true }
                ShareLink(item: recipe.shareText) {
                    Label("Partilhar", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button("Apagar", systemImage: "trash", role: .destructive) { confirmDelete = true }
            } label: {
                Label("Mais", systemImage: "ellipsis")
            }
        }
    }

    private func deleteRecipe() {
        let recipe = recipe
        let context = context
        dismiss()
        // Apaga depois da animação de saída, para a vista não ler um modelo já removido.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.delete(recipe)
            try? context.save()
        }
    }
}
