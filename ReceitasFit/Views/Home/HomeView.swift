import SwiftUI
import SwiftData

struct HomeView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @AppStorage("homeSort") private var sort: RecipeSort = .newest
    @State private var selectedCategory: RecipeCategory?
    @State private var path = NavigationPath()
    @State private var showingNewRecipe = false
    @State private var screenshotEditRecipe: Recipe?
    @State private var showingSettings = false
    @Namespace private var namespace

    private var filtered: [Recipe] {
        sort.sorted(recipes.filter { selectedCategory == nil || $0.category == selectedCategory })
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Receitas")
            .toolbar { toolbarContent }
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
            VStack(alignment: .leading, spacing: 26) {
                if selectedCategory == nil && recipes.count >= 4 {
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

                CategoryChips(selection: $selectedCategory)

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: selectedCategory?.title ?? "Todas as receitas", trailing: Format.recipes(filtered.count))
                    if filtered.isEmpty {
                        ContentUnavailableView {
                            Label {
                                Text("Nada por aqui")
                            } icon: {
                                (selectedCategory?.glyph ?? Image(systemName: "fork.knife"))
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 44, height: 44)
                            }
                        } description: {
                            Text("Ainda não tens receitas nesta categoria.")
                        }
                        .padding(.top, 20)
                    } else {
                        RecipeGrid(recipes: filtered, namespace: namespace)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ainda sem receitas", systemImage: "fork.knife")
        } description: {
            Text("Guarda aqui as receitas que crias ou encontras nas redes sociais.")
        } actions: {
            Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
                .buttonStyle(.glassProminent)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Definições", systemImage: "gearshape") { showingSettings = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Ordenar por", selection: $sort) {
                    ForEach(RecipeSort.allCases) { option in
                        Label(option.title, systemImage: option.symbol).tag(option)
                    }
                }
            } label: {
                Label("Ordenar", systemImage: "arrow.up.arrow.down")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Nova receita", systemImage: "plus") { showingNewRecipe = true }
        }
    }

    private func handleScreenshotArguments() {
        if ScreenshotMode.flag("screenshotOpenFirst"), path.isEmpty, let first = filtered.first {
            path.append(RecipeRoute(recipe: first))
        }
        if ScreenshotMode.flag("screenshotEditFirst"), screenshotEditRecipe == nil, let first = filtered.first {
            screenshotEditRecipe = first
        }
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
