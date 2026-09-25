import SwiftUI

/// Secção das Definições para a chave do Gemini usada na leitura de embalagens.
///
/// Segue o mesmo desenho das cópias automáticas: um cartão de estado e, por baixo,
/// só as ações que fazem sentido nesse estado.
struct GeminiKeySection: View {
    private enum Check: Equatable {
        case idle, checking, verified, failed(GeminiReader.ReadError)
    }

    @State private var savedKey = Self.currentKey()
    @State private var draftKey = ""
    @State private var check = Check.idle
    @State private var confirmRemove = false
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        Section {
            statusCard
        }
        .listSectionSpacing(.compact)

        Section {
            if let savedKey {
                LabeledContent("Chave", value: Self.masked(savedKey))
                    .monospacedDigit()
                Button {
                    verify(savedKey, save: false)
                } label: {
                    Label("Verificar chave", systemImage: "arrow.clockwise")
                }
                .disabled(check == .checking)
                Button(role: .destructive) {
                    confirmRemove = true
                } label: {
                    Label("Remover chave", systemImage: "trash")
                        .foregroundStyle(.red)
                }
                // No próprio botão (e não na secção): numa secção de um Form, cada linha recebia uma cópia.
                .confirmationDialog("Remover a chave do Gemini?", isPresented: $confirmRemove, titleVisibility: .visible) {
                    Button("Remover", role: .destructive) {
                        Keychain.set(nil, for: GeminiReader.keychainAccount)
                        self.savedKey = nil  // `self.`: aqui dentro, `savedKey` é a constante do `if let`
                        check = .idle
                    }
                } message: {
                    Text("As embalagens passam a ser lidas só neste iPhone, com menos precisão.")
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    SecureField("Colar a chave da API", text: $draftKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($keyFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                }
                // Só aparece depois de colar a chave (um botão inativo à espera parecia avariado).
                if !draftKey.trimmed.isEmpty {
                    Button(action: save) {
                        Label("Guardar chave", systemImage: "checkmark.circle")
                    }
                    .disabled(check == .checking)
                }
                Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                    Label("Criar chave no Google AI Studio", systemImage: "arrow.up.right.square")
                }
            }
        } footer: {
            Text("As fotografias só vão para o Gemini (Google) quando tocas em “Ler”. No nível gratuito, a Google pode usá-las para melhorar os seus produtos.")
        }
        .animation(.snappy, value: savedKey)
        .animation(.snappy, value: check)
        .animation(.snappy, value: draftKey.trimmed.isEmpty)
    }

    // MARK: - Estado

    private var statusCard: some View {
        let state = cardState
        return SettingsStatusCard(
            symbol: state.symbol,
            color: state.color,
            title: state.title,
            subtitle: state.subtitle,
            isAnimating: check == .checking
        )
    }

    private var cardState: (symbol: String, color: Color, title: String, subtitle: String) {
        switch check {
        case .checking:
            return ("arrow.triangle.2.circlepath", .gray, "A verificar a chave…", "Um pedido curto ao Gemini, sem fotografias.")
        case .failed(.quota):
            return ("hourglass", .orange, "Limite gratuito atingido",
                    "A chave está guardada. Até o limite renovar, as embalagens são lidas no iPhone.")
        case .failed(.offline):
            return ("wifi.slash", .orange, "Sem ligação ao Gemini", "Verifica a internet e tenta outra vez.")
        case .failed(let error):
            return ("exclamationmark.triangle.fill", .orange, "A chave não funciona",
                    savedKey == nil ? "\(error.message). Confirma que copiaste a chave toda." : error.message)
        case .verified:
            return ("sparkles", .green, "Gemini ativo", "Chave verificada agora mesmo.")
        case .idle:
            return savedKey == nil
                ? ("sparkles", .gray, "Gemini desativado", "Sem chave, as embalagens são lidas neste iPhone, com menos precisão.")
                : ("sparkles", .green, "Gemini ativo", "As embalagens são lidas com o Gemini, que percebe melhor tabelas difíceis.")
        }
    }

    /// Chave guardada no Porta-chaves (ou a simulada nas capturas do CI).
    static func currentKey() -> String? {
        // Capturas automáticas do CI: simula uma chave guardada.
        if ScreenshotMode.string("screenshotGeminiState") == "on" { return "AIzaSyExemploDeChave0x7Qk" }
        if ScreenshotMode.string("screenshotGeminiState") == "off" { return nil }
        return GeminiReader.apiKey
    }

    /// "AIza••••x7Qk": o suficiente para reconhecer a chave sem a mostrar.
    private static func masked(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }

    // MARK: - Ações

    private func save() {
        let key = draftKey.trimmed
        guard !key.isEmpty else { return }
        keyFieldFocused = false
        verify(key, save: true)
    }

    /// Testa a chave; ao guardar, só fica guardada se funcionar (ou se o problema for só a quota).
    private func verify(_ key: String, save: Bool) {
        check = .checking
        Task {
            let error = await GeminiReader.test(key: key)
            if save, error == nil || error == .quota {
                Keychain.set(key, for: GeminiReader.keychainAccount)
                draftKey = ""
                savedKey = key
            }
            check = error.map { .failed($0) } ?? .verified
            if error == nil { Haptics.success() } else { Haptics.warning() }
        }
    }
}
