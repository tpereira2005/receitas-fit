import SwiftUI
import SwiftData

/// Separador Início: um resumo para chegar depressa ao que interessa.
/// Recentes, feitas recentemente, favoritas, categorias, coleções e etiquetas.
struct HomeView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    @State private var showingNewRecipe = false
    @State private var screenshotEditRecipe: Recipe?
    @State private var showingSettings = false
    @Namespace private var namespace

    private let tileColumns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var recentlyCooked: [Recipe] {
        let cooked = recipes.filter { $0.lastCookedAt != nil }
        return Array(RecipeSort.recentlyCooked.sorted(cooked).prefix(10))
    }

    private var favorites: [Recipe] {
        recipes.filter(\.isFavorite).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var tags: [(tag: String, count: Int)] { TagLibrary.counts(in: recipes) }

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
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                recentSection

                if !recentlyCooked.isEmpty {
                    carousel(title: "Feitas recentemente", recipes: recentlyCooked, source: "cooked", showsCookedDate: true)
                }

                if !favorites.isEmpty {
                    carousel(title: "Favoritas", recipes: favorites, source: "favorites", seeAll: .quick(.favorites))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Categorias")
                    LazyVGrid(columns: tileColumns, spacing: 14) {
                        ForEach(RecipeCategory.allCases) { category in
                            NavigationLink(value: RecipeFilter.category(category)) {
                                CategoryTile(category: category, count: recipes.filter { $0.category == category }.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Coleções inteligentes")
                    VStack(spacing: 0) {
                        ForEach(QuickFilter.allCases) { filter in
                            NavigationLink(value: RecipeFilter.quick(filter)) {
                                SmartCollectionRow(filter: filter, count: recipes.filter { filter.matches($0) }.count)
                            }
                            .buttonStyle(.plain)
                            if filter != QuickFilter.allCases.last {
                                Divider().padding(.leading, 62)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal)
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

    /// As receitas acrescentadas mais recentemente, em cartões grandes.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recentes")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(recipes.prefix(6)) { recipe in
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
                Label(caption, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recipe.calories > 0 {
                Text("\(Int(recipe.calories.rounded())) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct CategoryChips: View {
    @Binding var selection: RecipeCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(title: "Todas", icon: GlyphImage(image: Image(systemName: "square.stack.fill"), isAsset: false), value: nil)
                    ForEach(RecipeCategory.allCases) { category in
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
    }
}
