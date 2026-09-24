import SwiftUI
import SwiftData

/// Cartão da grelha: fotografia, calorias em Liquid Glass, título e dados rápidos.
struct RecipeCard: View {
    let recipe: Recipe
    let transitionID: String
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(0.82, contentMode: .fit)
                .overlay { RecipePhoto(recipe: recipe, symbolSize: 38) }
                .overlay(alignment: .bottomLeading) {
                    if recipe.calories > 0 {
                        Label("\(Int(recipe.calories.rounded())) kcal", systemImage: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .glassEffect(.regular, in: .capsule)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if recipe.isSample {
                        Text("Exemplo")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect(.regular, in: .capsule)
                            .padding(8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.pink)
                            .padding(7)
                            .glassEffect(.regular, in: .circle)
                            .padding(8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .matchedTransitionSource(id: transitionID, in: namespace)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(recipe.cardFacts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.accessibilitySummary)
    }
}

/// Cartão largo do carrossel "Recentes".
struct FeaturedRecipeCard: View {
    let recipe: Recipe
    let transitionID: String
    let namespace: Namespace.ID

    var body: some View {
        Color.clear
            .frame(width: 290, height: 200)
            .overlay { RecipePhoto(recipe: recipe, variant: .full, symbolSize: 56) }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.category.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .opacity(0.85)
                    Text(recipe.title)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .foregroundStyle(.white)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(alignment: .topTrailing) {
                if recipe.calories > 0 {
                    Text("\(Int(recipe.calories.rounded())) kcal")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                        .padding(10)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .matchedTransitionSource(id: transitionID, in: namespace)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(recipe.accessibilitySummary)
    }
}

/// Linha compacta usada nas listas da pesquisa.
struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 60, height: 60)
                .overlay { RecipePhoto(recipe: recipe, symbolSize: 22) }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(recipe.quickFacts)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(recipe.accessibilitySummary)
    }
}

struct RecipeGrid: View {
    let recipes: [Recipe]
    let namespace: Namespace.ID
    var source = "grid"

    @Environment(\.modelContext) private var context
    @State private var pendingDeletion: Recipe?
    @State private var duplicating: Recipe?
    @State private var sharing: Recipe?

    // Alinhados pelo topo: os títulos têm uma ou duas linhas e as fotografias devem ficar à mesma altura.
    private let columns = [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), spacing: 14, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
            ForEach(recipes) { recipe in
                let route = RecipeRoute(recipe: recipe, source: source)
                NavigationLink(value: route) {
                    RecipeCard(recipe: recipe, transitionID: route.transitionID, namespace: namespace)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(
                        recipe.isFavorite ? "Remover das favoritas" : "Adicionar às favoritas",
                        systemImage: recipe.isFavorite ? "heart.slash" : "heart"
                    ) {
                        Haptics.tap()
                        withAnimation { recipe.isFavorite.toggle() }
                    }
                    Button("Duplicar", systemImage: "plus.square.on.square") { duplicating = recipe }
                    Button("Partilhar", systemImage: "square.and.arrow.up") { sharing = recipe }
                    Divider()
                    Button("Apagar", systemImage: "trash", role: .destructive) {
                        pendingDeletion = recipe
                    }
                }
            }
        }
        .padding(.horizontal)
        .sheet(item: $duplicating) { recipe in
            RecipeEditorView(duplicating: recipe)
        }
        .sheet(item: $sharing) { recipe in
            RecipeShareView(recipe: recipe)
        }
        .alert(
            "Apagar receita?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { recipe in
            Button("Apagar", role: .destructive) {
                Haptics.warning()
                withAnimation { context.delete(recipe) }
                try? context.save()
            }
            Button("Cancelar", role: .cancel) {}
        } message: { recipe in
            Text("“\(recipe.title)” será apagada deste iPhone. Esta ação não pode ser anulada.")
        }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
}

struct InfoPill: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(.tertiarySystemFill), in: .capsule)
    }
}

/// Disposição em "fluxo": os elementos passam para a linha seguinte quando não cabem.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    /// Regista o destino de navegação das receitas com a transição de zoom do iOS.
    func recipeDestinations(_ namespace: Namespace.ID) -> some View {
        navigationDestination(for: RecipeRoute.self) { route in
            RecipeDetailView(recipe: route.recipe)
                .navigationTransition(.zoom(sourceID: route.transitionID, in: namespace))
        }
    }
}

extension Recipe {
    /// Frase lida pelo VoiceOver nos cartões: nome, categoria, energia, proteína, tempo e estado.
    var accessibilitySummary: String {
        var parts = [title, category.title]
        if calories > 0 { parts.append("\(Int(calories.rounded())) calorias por porção") }
        if protein > 0 { parts.append("\(protein.cleanString) gramas de proteína") }
        if totalMinutes > 0 { parts.append(Format.minutes(totalMinutes)) }
        if isFavorite { parts.append("favorita") }
        if timesCooked > 0 { parts.append(timesCooked == 1 ? "feita 1 vez" : "feita \(timesCooked) vezes") }
        if isSample { parts.append("receita de exemplo") }
        return parts.joined(separator: ", ")
    }
}
