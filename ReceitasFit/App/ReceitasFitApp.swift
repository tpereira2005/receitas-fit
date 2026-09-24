import SwiftUI
import SwiftData

@main
struct ReceitasFitApp: App {
    private let container: Result<ModelContainer, Error>

    init() {
        container = Result { try DataStore.makeContainer() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .modelContainer(container)
            case .failure(let error):
                DataErrorView(error: error)
            }
        }
    }
}

enum AppTab: String, Hashable {
    case home, favorites, foods, explore, search
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("didSeedSamples") private var didSeedSamples = false
    @AppStorage("dataVersion") private var dataVersion = 0

    @State private var selectedTab = AppTab(rawValue: ScreenshotMode.string("tab") ?? "") ?? .home
    @State private var searchText = ScreenshotMode.string("screenshotSearch") ?? ""

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
        .task {
            prepareData()
            await AutoBackup.shared.runIfDue(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                Task { await AutoBackup.shared.runIfDue(context: context) }
            }
        }
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

/// Mostrado se a base de dados não abrir (por exemplo, uma migração falhada).
/// Os dados anteriores continuam guardados na cópia de proteção.
struct DataErrorView: View {
    let error: Error

    var body: some View {
        ContentUnavailableView {
            Label("Não foi possível abrir as receitas", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Os teus dados não foram apagados: existe uma cópia de proteção feita antes desta atualização. Instala a versão anterior no SideStore ou contacta o suporte da app.\n\n\(error.localizedDescription)")
        }
    }
}

/// Opções usadas apenas pelas capturas de ecrã automáticas do CI (builds de desenvolvimento).
/// Na versão instalada pelo SideStore não têm qualquer efeito.
enum ScreenshotMode {
    static func flag(_ key: String) -> Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: key)
        #else
        false
        #endif
    }

    static func string(_ key: String) -> String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: key)
        #else
        nil
        #endif
    }
}
