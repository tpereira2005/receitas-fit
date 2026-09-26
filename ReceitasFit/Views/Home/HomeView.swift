import SwiftUI
import SwiftData

/// Separador Início: um resumo para chegar depressa ao que interessa.
/// Recentes, à espera (congelador…), favoritas, feitas recentemente e etiquetas.
/// As categorias e as coleções ficam no separador Receitas.
struct HomeView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    @State private var showingNewRecipe = false
    @State private var screenshotEditRecipe: Recipe?
    @State private var showingSettings = false
    @Namespace private var namespace
    private let router = AppRouter.shared

    private var recentlyCooked: [Recipe] {
        let cooked = recipes.filter { $0.lastCookedAt != nil }
        return Array(RecipeSort.recentlyCooked.sorted(cooked).prefix(10))
    }

    private var favorites: [Recipe] {
        recipes.filter(\.isFavorite).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var tags: [(tag: String, count: Int)] { TagLibrary.counts(in: recipes) }

    /// Receitas dos cartões grandes de "Recentes".
    private var recent: [Recipe] { Array(recipes.prefix(6)) }

    /// "Favoritas" não aparece se só repetir receitas que já estão em "Recentes".
    private var showsFavorites: Bool {
        let shown = Set(recent.map(\.id))
        return favorites.contains { !shown.contains($0.id) }
    }

    /// Receitas à espera (no congelador, frigorífico…), as que ficam prontas primeiro à frente.
    private var waiting: [Recipe] {
        recipes
            .filter { $0.frozenAt != nil && $0.waitKind != nil }
            .sorted { (WaitReminder.readyDate(of: $0) ?? .distantFuture) < (WaitReminder.readyDate(of: $1) ?? .distantFuture) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("Ainda sem receitas", systemImage: "fork.knife")
                    } description: {
                        Text("Guarda aqui as receitas que crias ou encontras nas redes sociais.")
                    } actions: {
                        Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    content
                }
            }
            .navigationTitle("Início")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Definições", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
                }
            }
            .navigationDestination(for: RecipeFilter.self) { filter in
                FilteredRecipesView(filter: filter, namespace: namespace)
            }
            .recipeDestinations(namespace)
            .sheet(isPresented: $showingNewRecipe) {
                RecipeEditorView()
            }
            .sheet(item: $screenshotEditRecipe) { recipe in
                RecipeEditorView(recipe: recipe)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onAppear(perform: handleScreenshotArguments)
            // Receita pedida pelo Spotlight, pelos Atalhos ou pela Siri.
            .onChange(of: router.pendingRecipeID, initial: true) { _, id in
                guard let id, let recipe = recipes.first(where: { $0.id == id }) else { return }
                path = NavigationPath()
                path.append(RecipeRoute(recipe: recipe, source: "external"))
                router.pendingRecipeID = nil
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if AppSigning.isExpiringSoon {
                    expiryBanner
                }

                recentSection

                if !waiting.isEmpty {
                    waitingSection
                }

                if showsFavorites {
                    carousel(title: "Favoritas", recipes: favorites, source: "favorites", seeAll: .quick(.favorites))
                }

                if !recentlyCooked.isEmpty {
                    carousel(title: "Feitas recentemente", recipes: recentlyCooked, source: "cooked", showsCookedDate: true)
                }

                if !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Etiquetas")
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.tag) { item in
                                NavigationLink(value: RecipeFilter.tag(item.tag)) {
                                    HStack(spacing: 6) {
                                        Text(item.tag)
                                        Text("\(item.count)").foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    /// Aviso nos últimos dias antes de a assinatura do SideStore expirar.
    private var expiryBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("A app expira \(AppSigning.expiryText)")
                        .font(.headline)
                    Text("Renova-a no SideStore para continuares a usá-la. As receitas ficam guardadas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            Button {
                AppSigning.openSideStore()
            } label: {
                Label("Abrir SideStore", systemImage: "arrow.up.forward.app")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
        }
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal)
    }

    /// As receitas acrescentadas mais recentemente, em cartões grandes.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recentes")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(recent) { recipe in
                        let route = RecipeRoute(recipe: recipe, source: "featured")
                        NavigationLink(value: route) {
                            FeaturedRecipeCard(recipe: recipe, transitionID: route.transitionID, namespace: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    /// Gelados no congelador (e outras esperas): quanto falta ou "Pronto".
    private var waitingSection: some View {
        let kinds = Set(waiting.compactMap(\.waitKind))
        let title = kinds.count == 1 ? kinds.first!.waitingTitle : "À espera"
        return VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold())
                .padding(.horizontal)
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(waiting) { recipe in
                            let route = RecipeRoute(recipe: recipe, source: "waiting")
                            let ready = WaitReminder.isReady(recipe, now: timeline.date)
                            NavigationLink(value: route) {
                                CompactRecipeCard(
                                    recipe: recipe,
                                    caption: waitCaption(recipe, now: timeline.date),
                                    captionSymbol: ready ? "bell.fill" : (recipe.waitKind?.symbol ?? "hourglass"),
                                    captionColor: ready ? .green : .secondary,
                                    captionPrefix: "",
                                    transitionID: route.transitionID,
                                    namespace: namespace
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }

    private func waitCaption(_ recipe: Recipe, now: Date) -> String {
        guard let ready = WaitReminder.readyDate(of: recipe) else { return "" }
        if ready <= now { return recipe.waitKind?.readyTitle ?? "Pronta" }
        return Format.remaining(Int(ready.timeIntervalSince(now) / 60) + 1)
    }

    /// Fila horizontal de cartões pequenos, com "Ver todas" opcional.
    private func carousel(title: String, recipes: [Recipe], source: String,
                          seeAll: RecipeFilter? = nil, showsCookedDate: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.bold())
                Spacer()
                if let seeAll {
                    NavigationLink(value: seeAll) {
                        Text("Ver todas").font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(recipes) { recipe in
                        let route = RecipeRoute(recipe: recipe, source: source)
                        NavigationLink(value: route) {
                            CompactRecipeCard(
                                recipe: recipe,
                                caption: showsCookedDate ? recipe.lastCookedAt.map { Format.relativeDay($0) } : nil,
                                transitionID: route.transitionID,
                                namespace: namespace
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
        }
    }

    private func handleScreenshotArguments() {
        // Capturas do CI: algumas receitas já feitas, para mostrar "Feitas recentemente".
        if ScreenshotMode.flag("screenshotCooked"), !recipes.contains(where: { $0.timesCooked > 0 }) {
            for (offset, recipe) in recipes.prefix(3).enumerated() {
                recipe.cookedDates = [Date.now.addingTimeInterval(Double(-(offset * 2 + 1)) * 86_400), .now.addingTimeInterval(-9 * 86_400)]
            }
            try? context.save()
        }
        // Capturas do CI: um gelado no congelador há 20 horas e outro já pronto.
        if ScreenshotMode.flag("screenshotWaiting"), !recipes.contains(where: { $0.frozenAt != nil }) {
            let frozen = recipes.filter { $0.waitKind == .freezer }
            frozen.first?.frozenAt = .now.addingTimeInterval(-20 * 3600)
            frozen.dropFirst().first?.frozenAt = .now.addingTimeInterval(-26 * 3600)
            try? context.save()
        }
        if ScreenshotMode.flag("screenshotOpenFirst"), path.isEmpty, let first = recipes.first {
            path.append(RecipeRoute(recipe: first))
        }
        if ScreenshotMode.flag("screenshotEditFirst"), screenshotEditRecipe == nil, let first = recipes.first {
            screenshotEditRecipe = first
        }
        if ScreenshotMode.flag("screenshotSettings") {
            showingSettings = true
        }
    }
}

/// Cartão pequeno das filas do Início: fotografia quadrada e título (e, opcionalmente, quando foi feita).
struct CompactRecipeCard: View {
    let recipe: Recipe
    var caption: String?
    var captionSymbol = "checkmark.circle.fill"
    var captionColor: Color = .secondary
    /// Leitura do VoiceOver para a legenda ("última vez ontem").
    var captionPrefix = "última vez"
    let transitionID: String
    let namespace: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .frame(width: 132, height: 132)
                .overlay { RecipePhoto(recipe: recipe, symbolSize: 30) }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .matchedTransitionSource(id: transitionID, in: namespace)
            Text(recipe.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let caption {
                Label(caption, systemImage: captionSymbol)
                    .font(.caption)
                    .foregroundStyle(captionColor)
            } else if recipe.calories > 0 {
                Text("\(Int(recipe.calories.rounded())) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(caption.map { "\(recipe.accessibilitySummary), \(captionPrefix) \($0)" } ?? recipe.accessibilitySummary)
    }
}

/// Cápsulas das categorias (Receitas e Pesquisa). Só aparecem as categorias com receitas.
struct CategoryChips: View {
    @Binding var selection: RecipeCategory?
    let recipes: [Recipe]

    private var categories: [RecipeCategory] {
        let used = Set(recipes.map(\.category))
        return RecipeCategory.allCases.filter { used.contains($0) || $0 == selection }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(title: "Todas", icon: GlyphImage(image: Image(systemName: "square.stack.fill"), isAsset: false), value: nil)
                    ForEach(categories) { category in
                        chip(title: category.title, icon: GlyphImage(image: category.glyph, isAsset: category.assetName != nil), value: category)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollClipDisabled()
    }

    private func chip(title: String, icon: GlyphImage, value: RecipeCategory?) -> some View {
        let isSelected = selection == value
        return Button {
            withAnimation(.snappy) { selection = value }
        } label: {
            Label { Text(title) } icon: { icon }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected ? .regular.tint(value?.color ?? Color.accentColor).interactive() : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
