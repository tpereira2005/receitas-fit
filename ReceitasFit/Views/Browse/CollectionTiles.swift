import SwiftUI

struct CategoryTile: View {
    let category: RecipeCategory
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlyphImage(image: category.glyph, isAsset: category.assetName != nil, size: 26)
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

struct SmartCollectionRow: View {
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
