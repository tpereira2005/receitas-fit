import SwiftUI
import SwiftData

struct ExploreView: View {
    @Query private var recipes: [Recipe]
    @Namespace private var namespace

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var tags: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for recipe in recipes {
            for tag in recipe.tags { counts[tag, default: 0] += 1 }
        }
        return counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.tag < $1.tag : $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Categorias")
                        LazyVGrid(columns: columns, spacing: 14) {
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
            .navigationTitle("Explorar")
            .navigationDestination(for: RecipeFilter.self) { filter in
                FilteredRecipesView(filter: filter, namespace: namespace)
            }
            .recipeDestinations(namespace)
        }
    }
}

private struct CategoryTile: View {
    let category: RecipeCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlyphImage(image: category.glyph, isAsset: category.assetName != nil)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(category.color.gradient, in: .circle)
            Spacer(minLength: 0)
            Text(category.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(Format.recipes(count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
        .padding(16)
        .background(category.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SmartCollectionRow: View {
    let filter: QuickFilter
    let count: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: filter.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(filter.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.title).font(.body.weight(.medium))
                Text(filter.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
