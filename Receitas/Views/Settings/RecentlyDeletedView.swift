import SwiftUI
import SwiftData

/// Receitas e alimentos apagados nos últimos 30 dias: recuperar ou apagar de vez.
struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Recipe> { $0.deletedAt != nil }, sort: \Recipe.deletedAt, order: .reverse)
    private var recipes: [Recipe]
    @Query(filter: #Predicate<Food> { $0.deletedAt != nil }, sort: \Food.deletedAt, order: .reverse)
    private var foods: [Food]

    @State private var confirmEmpty = false

    private var isEmpty: Bool { recipes.isEmpty && foods.isEmpty }

    var body: some View {
        List {
            if !recipes.isEmpty {
                Section("Receitas") {
                    ForEach(recipes) { recipe in
                        row(title: recipe.title, deletedAt: recipe.deletedAt, feminine: true) {
                            Color.clear
                                .frame(width: 44, height: 44)
                                .overlay { RecipePhoto(recipe: recipe, symbolSize: 18) }
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .swipeActions(edge: .leading) {
                            Button("Recuperar", systemImage: "arrow.uturn.backward") { restore(recipe) }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Apagar", systemImage: "trash", role: .destructive) { erase(recipe) }
                        }
                        .contextMenu {
                            Button("Recuperar", systemImage: "arrow.uturn.backward") { restore(recipe) }
                            Button("Apagar de vez", systemImage: "trash", role: .destructive) { erase(recipe) }
                        }
                    }
                }
            }
            if !foods.isEmpty {
                Section("Alimentos") {
                    ForEach(foods) { food in
                        row(title: food.name, deletedAt: food.deletedAt, feminine: false) {
                            FoodIcon(food: food, size: 44)
                        }
                        .swipeActions(edge: .leading) {
                            Button("Recuperar", systemImage: "arrow.uturn.backward") { restore(food) }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Apagar", systemImage: "trash", role: .destructive) { erase(food) }
                        }
                        .contextMenu {
                            Button("Recuperar", systemImage: "arrow.uturn.backward") { restore(food) }
                            Button("Apagar de vez", systemImage: "trash", role: .destructive) { erase(food) }
                        }
                    }
                }
            }
            if !isEmpty {
                Section {
                } footer: {
                    Text("Desliza para a direita para recuperar. Ficam aqui \(RecentlyDeleted.days) dias e depois saem de vez.")
                }
            }
        }
        .overlay {
            if isEmpty {
                ContentUnavailableView(
                    "Nada apagado",
                    systemImage: "trash",
                    description: Text("O que apagares fica aqui \(RecentlyDeleted.days) dias, para poderes recuperar.")
                )
            }
        }
        .navigationTitle("Apagadas recentemente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Recuperar tudo", systemImage: "arrow.uturn.backward") { restoreAll() }
                        Button("Apagar tudo", systemImage: "trash", role: .destructive) { confirmEmpty = true }
                    } label: {
                        Label("Mais", systemImage: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog("Apagar tudo de vez?", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("Apagar \(recipes.count + foods.count) itens", role: .destructive, action: eraseAll)
        } message: {
            Text("Não é possível recuperar depois.")
        }
        .animation(.snappy, value: recipes.map(\.id))
        .animation(.snappy, value: foods.map(\.id))
    }

    private func row(title: String, deletedAt: Date?, feminine: Bool, @ViewBuilder icon: () -> some View) -> some View {
        HStack(spacing: 12) {
            icon()
            VStack(alignment: .leading, spacing: 2) {
                Text(title).lineLimit(2)
                if let deletedAt {
                    let left = RecentlyDeleted.daysLeft(since: deletedAt)
                    Text("\(feminine ? "Apagada" : "Apagado") \(Format.relativeDay(deletedAt)) · \(left == 1 ? "falta 1 dia" : "faltam \(left) dias")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func restore(_ recipe: Recipe) {
        Haptics.success()
        recipe.restoreFromTrash()
        try? context.save()
    }

    private func restore(_ food: Food) {
        Haptics.success()
        food.restoreFromTrash()
        try? context.save()
    }

    private func erase(_ recipe: Recipe) {
        context.delete(recipe)
        try? context.save()
    }

    private func erase(_ food: Food) {
        context.delete(food)
        try? context.save()
    }

    private func restoreAll() {
        recipes.forEach { $0.restoreFromTrash() }
        foods.forEach { $0.restoreFromTrash() }
        try? context.save()
        Haptics.success()
    }

    private func eraseAll() {
        recipes.forEach { context.delete($0) }
        foods.forEach { context.delete($0) }
        try? context.save()
        Haptics.warning()
    }
}
