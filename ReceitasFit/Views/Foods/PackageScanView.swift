import PhotosUI
import SwiftUI

/// Criar um alimento a partir de fotografias da embalagem.
///
/// O utilizador junta as fotografias (tabela nutricional, código de barras, frente…), a app lê-as no
/// iPhone e abre o editor já preenchido para rever. Nada fica guardado sem tocar em "Guardar".
struct PackageScanView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Photo: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    static let maxPhotos = 8

    @State private var photos: [Photo] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var isReading = false
    @State private var reading: PackageReading? = Self.screenshotReading()

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var remaining: Int { Self.maxPhotos - photos.count }

    var body: some View {
        if let reading {
            FoodEditorView(reading: reading)
        } else {
            scanner
        }
    }

    private var scanner: some View {
        NavigationStack {
            Form {
                Section {
                    if photos.isEmpty {
                        ContentUnavailableView {
                            Label("Fotografa a embalagem", systemImage: "camera.viewfinder")
                        } description: {
                            Text("A tabela nutricional de frente e com boa luz. Se a embalagem tiver código de barras, inclui-o também.")
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photos) { photo in
                                thumbnail(photo)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } footer: {
                    if !photos.isEmpty {
                        Text("\(photos.count) de \(Self.maxPhotos) fotografias. Podes juntar várias partes da tabela.")
                    }
                }

                Section {
                    if cameraAvailable {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Tirar fotografia", systemImage: "camera")
                        }
                        .disabled(remaining == 0)
                    }
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: max(1, remaining), matching: .images) {
                        Label("Escolher da galeria", systemImage: "photo.on.rectangle")
                    }
                    .disabled(remaining == 0)
                } footer: {
                    Text(GeminiReader.apiKey != nil
                         ? "As fotografias são enviadas ao Gemini para ler a tabela e não são guardadas na app. O código de barras é usado no Open Food Facts para completar o que faltar. No fim revês tudo antes de guardar."
                         : "Sem chave do Gemini nas Definições, as fotografias são lidas neste iPhone, com menos precisão. O código de barras é usado no Open Food Facts para completar o que faltar. No fim revês tudo antes de guardar.")
                }
            }
            .navigationTitle("Ler embalagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ler", systemImage: "text.viewfinder", action: read)
                        .disabled(photos.isEmpty || isReading)
                }
            }
            .overlay {
                if isReading {
                    ProgressView("A ler a embalagem…")
                        .padding(24)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items where photos.count < Self.maxPhotos {
                        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                            withAnimation { photos.append(Photo(image: image)) }
                        }
                    }
                    pickerItems = []
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    withAnimation { photos.append(Photo(image: image)) }
                }
                .ignoresSafeArea()
            }
            .interactiveDismissDisabled(!photos.isEmpty)
        }
    }

    private func thumbnail(_ photo: Photo) -> some View {
        Image(uiImage: photo.image)
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation { photos.removeAll { $0.id == photo.id } }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .padding(6)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .padding(4)
                .accessibilityLabel("Remover fotografia")
            }
    }

    /// Usado apenas nas capturas automáticas do CI: uma leitura de exemplo para mostrar o ecrã de revisão.
    private static func screenshotReading() -> PackageReading? {
        guard ScreenshotMode.flag("screenshotScannerReview") else { return nil }
        var label = PartialFacts()
        label.base = .grams
        for (nutrient, value) in [(Nutrient.calories, 383.0), (.fat, 5.6), (.saturatedFat, 3.4), (.carbs, 6.2),
                                  (.sugars, 4.1), (.fiber, 0.5), (.protein, 76), (.salt, 0.48)] {
            label[nutrient] = value
        }
        label.lessThan = [.fiber]
        var database = PartialFacts()
        database[.calories] = 405
        database[.protein] = 76
        let gemini = GeminiReader.Result(name: "Whey Protein Baunilha", brand: "Marca", facts: label,
                                         servingName: "dose", servingGrams: 30, barcode: nil, notes: "")
        var reading = PackageReading.merge(
            label: label,
            product: OpenFoodFacts.Product(name: "Whey Protein", brand: "Marca", facts: database),
            gemini: gemini
        )
        reading.reader = .gemini
        return reading
    }

    private func read() {
        isReading = true
        let images = photos.map(\.image)
        Task {
            let result = await PackageReading.read(photos: images)
            isReading = false
            if result.sources.isEmpty && result.draft.name.isEmpty {
                Haptics.warning()
            } else {
                Haptics.success()
            }
            withAnimation { reading = result }
        }
    }
}

/// Câmara do sistema para tirar uma fotografia.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
