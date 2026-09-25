import SwiftUI
import SwiftData

/// Páginas das Definições.
enum SettingsPage: String, Hashable {
    case backups = "copias"
    case packageReading = "gemini"
    case tags = "etiquetas"
    case sideStore = "sidestore"
}

/// Página principal das Definições: um resumo da app e uma linha por área, com o estado à direita.
/// O detalhe de cada área fica numa página própria.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var recipes: [Recipe]
    @Query private var foods: [Food]
    @AppStorage(TagLibrary.catalogKey) private var tagCatalog = ""

    /// Capturas do CI: abre logo numa das páginas.
    @State private var path: [SettingsPage] = ScreenshotMode.string("screenshotSettingsPage")
        .flatMap(SettingsPage.init(rawValue:)).map { [$0] } ?? []
    @State private var geminiActive = GeminiKeySection.currentKey() != nil
    @State private var showingWhatsNew = false
    private let backup = AutoBackup.shared

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    header
                }

                if AppSigning.isExpiringSoon {
                    Section {
                        expiryBanner
                    }
                }

                Section("Dados") {
                    NavigationLink(value: SettingsPage.backups) {
                        SettingsRow(title: "Cópias de segurança", symbol: "externaldrive.fill", color: .blue,
                                    value: backupValue.text, valueColor: backupValue.color)
                    }
                    NavigationLink(value: SettingsPage.packageReading) {
                        SettingsRow(title: "Leitura de embalagens", symbol: "sparkles", color: .purple,
                                    value: geminiActive ? "Gemini" : "No iPhone")
                    }
                }

                Section("Biblioteca") {
                    NavigationLink(value: SettingsPage.tags) {
                        SettingsRow(title: "Etiquetas", symbol: "tag.fill", color: .orange,
                                    value: "\(TagLibrary.all(in: recipes, catalog: TagLibrary.decodeCatalog(tagCatalog)).count)")
                    }
                }

                Section("App") {
                    NavigationLink(value: SettingsPage.sideStore) {
                        SettingsRow(title: "SideStore", symbol: "clock.arrow.circlepath", color: .gray,
                                    value: sideStoreValue,
                                    valueColor: AppSigning.isExpiringSoon ? .orange : .secondary)
                    }
                    Button {
                        showingWhatsNew = true
                    } label: {
                        SettingsRow(title: "O que há de novo", symbol: "gift.fill", color: .pink)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Definições")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark") { dismiss() }
                }
            }
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .backups: BackupSettingsView()
                case .packageReading: PackageReadingSettingsView()
                case .tags: TagManagerView()
                case .sideStore: SideStoreSettingsView()
                }
            }
            // Ao voltar da página da leitura de embalagens, a chave pode ter mudado.
            .onAppear { geminiActive = GeminiKeySection.currentKey() != nil }
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView()
            }
        }
    }

    // MARK: - Cabeçalho

    private var header: some View {
        HStack(spacing: 16) {
            Image("app.mark")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08))
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Receitas")
                    .font(.title2.weight(.bold))
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Versão \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var summary: String {
        let favorites = recipes.filter(\.isFavorite).count
        var parts = [Format.recipes(recipes.count)]
        if favorites > 0 { parts.append(favorites == 1 ? "1 favorita" : "\(favorites) favoritas") }
        parts.append(foods.count == 1 ? "1 alimento" : "\(foods.count) alimentos")
        return parts.joined(separator: " · ")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // MARK: - Aviso do SideStore

    private var expiryBanner: some View {
        HStack(spacing: 14) {
            SettingsIcon(symbol: "exclamationmark.triangle.fill", color: .orange, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Renova a app no SideStore")
                    .font(.headline)
                Text("A assinatura expira \(AppSigning.expiryText).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Abrir") { AppSigning.openSideStore() }
                .buttonStyle(.glassProminent)
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Estados

    private var backupValue: (text: String, color: Color) {
        guard backup.isEnabled, backup.folderName != nil else { return ("Desativadas", .secondary) }
        if backup.isRunning { return ("A copiar…", .secondary) }
        if backup.lastError != nil { return ("Com erro", .orange) }
        return ("Ativas", .secondary)
    }

    private var sideStoreValue: String {
        switch AppSigning.daysLeft {
        case nil: "Sem data"
        case 0?: "Expira hoje"
        case 1?: "Expira amanhã"
        case let days?: "Faltam \(days) dias"
        }
    }
}
