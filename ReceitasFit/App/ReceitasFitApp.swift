import SwiftUI
import SwiftData

@main
struct ReceitasFitApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Recipe.self, Food.self])
    }
}

enum AppTab: String, Hashable {
    case home, favorites, foods, explore, search
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("didSeedSamples") private var didSeedSamples = false
    @AppStorage("dataVersion") private var dataVersion = 0

    // Os argumentos "-tab" e "-screenshotSearch" são usados apenas para as capturas automáticas no CI.
    @State private var selectedTab = AppTab(rawValue: UserDefaults.standard.string(forKey: "tab") ?? "") ?? .home
    @State private var searchText = UserDefaults.standard.string(forKey: "screenshotSearch") ?? ""

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Receitas", systemImage: "fork.knife", value: AppTab.home) {
                HomeView()
            }
            Tab("Favoritas", systemImage: "heart", value: AppTab.favorites) {
                FavoritesView()
            }
            Tab("Alimentos", systemImage: "basket", value: AppTab.foods) {
                FoodsView()
            }
            Tab("Explorar", systemImage: "square.grid.2x2", value: AppTab.explore) {
                ExploreView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView(searchText: $searchText)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { prepareData() }
    }

    private func prepareData() {
        if !didSeedSamples {
            didSeedSamples = true
            let count = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
            if count == 0 {
                SampleData.insert(into: context)
            }
        }
        if dataVersion < DataMigration.currentVersion {
            DataMigration.migrate(context, from: dataVersion)
            dataVersion = DataMigration.currentVersion
        }
    }
}
