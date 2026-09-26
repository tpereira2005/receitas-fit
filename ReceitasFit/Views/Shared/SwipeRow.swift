import SwiftUI
import SwiftData

/// Linha com ações ao deslizar, para listas que não são `List` (dentro de um ScrollView):
/// para a direita marca como favorita, para a esquerda apaga. Deslizar até ao fim faz logo a ação.
struct SwipeRow<Content: View>: View {
    var leading: SwipeAction?
    var trailing: SwipeAction?
    @ViewBuilder let content: Content

    struct SwipeAction {
        let title: String
        let symbol: String
        let color: Color
        let action: () -> Void
    }

    @State private var offset: CGFloat = 0
    @State private var start: CGFloat?
    /// Só reage a gestos claramente horizontais, para não atrapalhar o scroll.
    @State private var isHorizontal: Bool?

    private let buttonWidth: CGFloat = 76
    private let fullSwipe: CGFloat = 170

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                if let leading, offset > 0 {
                    actionButton(leading, width: offset)
                }
                Spacer(minLength: 0)
                if let trailing, offset < 0 {
                    actionButton(trailing, width: -offset)
                }
            }
            content
                .background(Color(.systemBackground))
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(drag)
        .sensoryFeedback(.impact(weight: .medium), trigger: abs(offset) >= fullSwipe)
        .accessibilityActions {
            if let leading { Button(leading.title, action: leading.action) }
            if let trailing { Button(trailing.title, action: trailing.action) }
        }
    }

    private func actionButton(_ action: SwipeAction, width: CGFloat) -> some View {
        Button {
            close()
            action.action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.symbol).font(.title3)
                Text(action.title).font(.caption2.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(width: max(width, 0))
            .frame(maxHeight: .infinity)
            .background(action.color)
        }
        .buttonStyle(.plain)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                if isHorizontal == nil {
                    isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.4
                }
                guard isHorizontal == true else { return }
                let base = start ?? offset
                if start == nil { start = offset }
                var next = base + value.translation.width
                if leading == nil { next = min(0, next) }
                if trailing == nil { next = max(0, next) }
                offset = next
            }
            .onEnded { _ in
                defer { start = nil; isHorizontal = nil }
                guard isHorizontal == true else { return }
                if offset >= fullSwipe, let leading {
                    close()
                    leading.action()
                } else if offset <= -fullSwipe, let trailing {
                    close()
                    trailing.action()
                } else if offset > buttonWidth / 2, leading != nil {
                    withAnimation(.snappy) { offset = buttonWidth }
                } else if offset < -buttonWidth / 2, trailing != nil {
                    withAnimation(.snappy) { offset = -buttonWidth }
                } else {
                    close()
                }
            }
    }

    private func close() {
        withAnimation(.snappy) { offset = 0 }
    }
}

/// Receita numa lista: toque abre, deslizar favorita ou apaga (com confirmação).
struct RecipeListItem: View {
    let recipe: Recipe
    var source = "list"

    @Environment(\.modelContext) private var context
    @State private var confirmDelete = false

    var body: some View {
        SwipeRow(
            leading: .init(
                title: recipe.isFavorite ? "Tirar" : "Favorita",
                symbol: recipe.isFavorite ? "heart.slash.fill" : "heart.fill",
                color: .pink
            ) {
                Haptics.tap()
                withAnimation { recipe.isFavorite.toggle() }
                try? context.save()
            },
            trailing: .init(title: "Apagar", symbol: "trash.fill", color: .red) {
                confirmDelete = true
            }
        ) {
            NavigationLink(value: RecipeRoute(recipe: recipe, source: source)) {
                RecipeRow(recipe: recipe)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .alert("Apagar receita?", isPresented: $confirmDelete) {
            Button("Apagar", role: .destructive) {
                Haptics.warning()
                withAnimation { context.delete(recipe) }
                try? context.save()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("“\(recipe.title)” será apagada deste iPhone.")
        }
    }
}
