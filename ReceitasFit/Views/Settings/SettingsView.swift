import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]
    @Query private var foods: [Food]

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isChoosingFolder = false
    @State private var confirmDisableAuto = false
    private let autoBackup = AutoBackup.shared
    @State private var message: String?

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var backupFilename: String {
        "Receitas-\(Date.now.formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Resumo") {
                    LabeledContent("Receitas", value: "\(recipes.count)")
                    LabeledContent("Favoritas", value: "\(recipes.filter(\.isFavorite).count)")
                    LabeledContent("Alimentos na biblioteca", value: "\(foods.count)")
                    LabeledContent("Com fotografia", value: "\(recipes.filter { $0.thumbnailData != nil }.count)")
                }

                AutoBackupSection(
                    onChooseFolder: { isChoosingFolder = true },
                    onDisable: { confirmDisableAuto = true }
                )

                Section {
                    Button("Exportar cópia de segurança", systemImage: "square.and.arrow.up", action: export)
                        .disabled(recipes.isEmpty && foods.isEmpty)
                    Button("Importar cópia de segurança", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                } header: {
                    Text("Cópia de segurança")
                } footer: {
                    Text("Exporta um ficheiro quando quiseres, por exemplo antes de mudar de iPhone. A importação só acrescenta o que ainda não existe na app.")
                }

                Section {
                    Button("Adicionar receitas de exemplo", systemImage: "sparkles") {
                        let count = SampleData.insert(into: context)
                        message = "Foram adicionadas \(count) receitas de exemplo."
                    }
                    Button("Repor alimentos de origem", systemImage: "basket") {
                        let before = foods.count
                        FoodLibrary.insertMissingDefaults(in: context)
                        let added = ((try? context.fetchCount(FetchDescriptor<Food>())) ?? before) - before
                        message = added == 0
                            ? "A biblioteca já tem todos os alimentos de origem."
                            : "Foram adicionados \(added) alimentos à biblioteca."
                    }
                } footer: {
                    Text("Os alimentos de origem têm valores médios. Podes editá-los com os valores do rótulo das marcas que usas.")
                }

                Section("Sobre") {
                    LabeledContent("Versão", value: appVersion)
                    LabeledContent("Feita com", value: "SwiftUI · SwiftData")
                }
            }
            .navigationTitle("Definições")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") { dismiss() }
                }
            }
            .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .json, defaultFilename: backupFilename) { result in
                if case .success = result {
                    message = "Cópia de segurança exportada."
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .background {
                // Um segundo seletor no mesmo modificador não abre; fica numa vista à parte.
                Color.clear.fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                    handleFolder(result)
                }
            }
            .confirmationDialog("Desativar as cópias automáticas?", isPresented: $confirmDisableAuto, titleVisibility: .visible) {
                Button("Desativar", role: .destructive) {
                    withAnimation(.snappy) { autoBackup.disable() }
                }
            } message: {
                Text("As cópias que já estão na pasta não são apagadas.")
            }
            .alert(
                "Receitas",
                isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: - Cópias automáticas

    private func handleFolder(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try autoBackup.setFolder(url)
                // O cartão de estado mostra o resultado da primeira cópia; não é preciso um alerta.
                Task {
                    if await autoBackup.run(context: context, force: true) {
                        Haptics.success()
                    } else {
                        Haptics.warning()
                    }
                }
            } catch {
                message = "Não foi possível usar esta pasta: \(error.localizedDescription)"
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }

    private func export() {
        do {
            exportDocument = BackupDocument(data: try RecipeBackup.encode(recipes: recipes, foods: foods))
            isExporting = true
        } catch {
            message = "Não foi possível exportar: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let restored = try RecipeBackup.restore(from: data, into: context)
                if restored.recipes == 0 && restored.foods == 0 {
                    message = "Tudo o que está neste ficheiro já existe na app."
                } else {
                    let recipesText = restored.recipes == 1 ? "1 receita" : "\(restored.recipes) receitas"
                    let foodsText = restored.foods == 1 ? "1 alimento" : "\(restored.foods) alimentos"
                    message = "Importados: \(recipesText) e \(foodsText)."
                }
            } catch {
                message = "Este ficheiro não parece ser uma cópia de segurança válida."
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}
