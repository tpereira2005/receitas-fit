import SwiftUI

/// Partilhar uma receita como imagem (quadrada ou para Stories) ou como texto.
/// Mostra a imagem antes de partilhar; na folha de partilha há "Guardar imagem" para a galeria.
struct RecipeShareView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe

    @State private var format = RecipeShareCard.ShareFormat(rawValue: ScreenshotMode.string("screenshotShareFormat") ?? "") ?? .square
    @State private var images: [RecipeShareCard.ShareFormat: UIImage] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Formato", selection: $format.animation(.snappy)) {
                    ForEach(RecipeShareCard.ShareFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    if let image = images[format] {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(recipe.title, image: Image(uiImage: image))
                        ) {
                            Label("Partilhar imagem", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    ShareLink(item: recipe.shareText) {
                        Label("Partilhar como texto", systemImage: "text.alignleft")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .navigationTitle("Partilhar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                }
            }
            .task {
                // As duas imagens são desenhadas logo, para a troca de formato ser instantânea.
                let content = RecipeShareCard.Content(recipe: recipe)
                for format in RecipeShareCard.ShareFormat.allCases {
                    images[format] = RecipeShareCard.render(content, format: format)
                }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let image = images[format] {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .id(format)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            ProgressView()
        }
    }
}
