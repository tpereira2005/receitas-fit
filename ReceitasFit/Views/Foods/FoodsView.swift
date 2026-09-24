import SwiftUI
import SwiftData

/// Biblioteca de alimentos: os ingredientes e os respetivos valores nutricionais.
struct FoodsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @Query private var recipes: [Recipe]
    @State private var searchText = ""
    @State private var path = NavigationPath()
    @State private var showingEditor = false
    @State private var showingScanner = ScreenshotMode.flag("screenshotScanner")
    @State private var pendingDeletion: Food?
    @Namespace private var namespace

    private var filtered: [Food] {
        let query = searchText.trimmed.searchNormalized
        guard !query.isEmpty else { return foods }
        return foods.filter { "\($0.name) \($0.brand) \($0.category.title)".searchNormalized.contains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if foods.isEmpty {
                    ContentUnavailableView {
                        Label("Ainda sem alimentos", systemImage: "basket")
                    } description: {
                        Text("Cria os alimentos que usas, com os valores do rótulo, e a app calcula os macros das receitas.")
                    } actions: {
                        Button("Novo alimento", systemImage: "plus") { showingEditor = true }
                            .buttonStyle(.glassProminent)
                        Button("Ler embalagem", systemImage: "barcode.viewfinder") { showingScanner = true }
                            .buttonStyle(.glass)
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Alimentos")
            .searchable(text: $searchText, prompt: "Procurar alimento")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Ler embalagem", systemImage: "barcode.viewfinder") { showingScanner = true }
                    Button("Novo alimento", systemImage: "plus") { showingEditor = true }
                }
            }
            .sheet(isPresented: $showingScanner) {
                PackageScanView()
            }
            .navigationDestination(for: Food.self) { food in
                FoodDetailView(food: food, namespace: namespace)
            }
            .recipeDestinations(namespace)
            .sheet(isPresented: $showingEditor) {
                FoodEditorView(food: nil)
            }
            .alert(
                "Apagar alimento?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                presenting: pendingDeletion
            ) { food in
                Button("Apagar", role: .destructive) { delete(food) }
                Button("Cancelar", role: .cancel) {}
            } message: { food in
                Text(deletionMessage(for: food))
            }
            .onAppear(perform: handleScreenshotArguments)
        }
    }

    private var list: some View {
        List {
            ForEach(FoodCategory.allCases) { category in
                let items = filtered.filter { $0.category == category }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { food in
                            NavigationLink(value: food) {
                                FoodRow(food: food)
                            }
                            .swipeActions {
                                Button("Apagar", systemImage: "trash", role: .destructive) {
                                    pendingDeletion = food
                                }
                            }
                        }
                    } header: {
                        FoodCategoryLabel(category: category)
                    }
                }
            }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func deletionMessage(for food: Food) -> String {
        let count = recipes.filter { $0.ingredients.contains { $0.foodID == food.id } }.count
        guard count > 0 else { return "“\(food.name)” será apagado da biblioteca." }
        let recipesText = count == 1 ? "1 receita" : "\(count) receitas"
        return "“\(food.name)” é usado em \(recipesText). Essas receitas mantêm os valores atuais deste ingrediente."
    }

    private func delete(_ food: Food) {
        Haptics.warning()
        context.delete(food)
        try? context.save()
    }

    private func handleScreenshotArguments() {
        if ScreenshotMode.flag("screenshotOpenFood"), path.isEmpty,
           let food = foods.first(where: { $0.name == "Peito de frango" }) ?? foods.first {
            path.append(food)
        }
    }
}
