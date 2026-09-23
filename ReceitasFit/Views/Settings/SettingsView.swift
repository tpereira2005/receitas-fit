import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]

    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
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
                    LabeledContent("Com fotografia", value: "\(recipes.filter { $0.thumbnailData != nil }.count)")
                }

                Section {
                    Button("Exportar cópia de segurança", systemImage: "square.and.arrow.up", action: export)
                        .disabled(recipes.isEmpty)
                    Button("Importar cópia de segurança", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                } header: {
                    Text("Cópia de segurança")
                } footer: {
                    Text("As receitas ficam guardadas apenas neste iPhone. Exporta regularmente um ficheiro para a app Ficheiros ou para o iCloud Drive para nunca perderes nada.")
                }

                Section {
                    Button("Adicionar receitas de exemplo", systemImage: "sparkles") {
                        SampleData.insert(into: context)
                        message = "Foram adicionadas 6 receitas de exemplo."
                    }
                } footer: {
                    Text("Podes apagá-las a qualquer momento com um toque longo no cartão.")
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

    private func export() {
        do {
            exportDocument = BackupDocument(data: try RecipeBackup.encode(recipes))
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
                let added = try RecipeBackup.restore(from: data, into: context, existing: recipes)
                switch added {
                case 0: message = "Todas as receitas deste ficheiro já existem na app."
                case 1: message = "1 receita importada."
                default: message = "\(added) receitas importadas."
                }
            } catch {
                message = "Este ficheiro não parece ser uma cópia de segurança válida."
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}
