import SwiftUI

/// Secção das Definições para a chave do Gemini usada na leitura de embalagens.
struct GeminiKeySection: View {
    private enum Status: Equatable {
        case none, checking, valid, failed(String)
    }

    @State private var hasKey = GeminiReader.apiKey != nil
    @State private var draftKey = ""
    @State private var status = Status.none
    @State private var confirmRemove = false

    var body: some View {
        Section {
            if hasKey {
                LabeledContent("Chave do Gemini") {
                    Label("Guardada", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
                statusRow
                Button("Verificar chave", systemImage: "checkmark.circle") {
                    if let key = GeminiReader.apiKey { check(key, saveIfValid: false) }
                }
                .disabled(status == .checking)
                Button("Remover chave", systemImage: "trash", role: .destructive) { confirmRemove = true }
            } else {
                SecureField("Colar chave da API", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(save)
                statusRow
                Button("Guardar chave", systemImage: "key.fill", action: save)
                    .disabled(draftKey.trimmed.isEmpty || status == .checking)
                Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                    Label("Criar chave no Google AI Studio", systemImage: "arrow.up.right.square")
                }
            }
        } header: {
            Text("Leitura de embalagens")
        } footer: {
            Text("Com a chave, as fotografias da embalagem são enviadas ao Gemini (Google) quando tocas em “Ler”. No nível gratuito, a Google pode usar o que é enviado para melhorar os seus produtos. Sem chave, sem internet ou sem quota, a leitura é feita neste iPhone, com menos precisão. A chave fica no Porta-chaves do iPhone.")
        }
        .confirmationDialog("Remover a chave do Gemini?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remover", role: .destructive) {
                Keychain.set(nil, for: GeminiReader.keychainAccount)
                withAnimation {
                    hasKey = false
                    status = .none
                }
            }
        } message: {
            Text("A leitura de embalagens passa a ser feita só no iPhone.")
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch status {
        case .none:
            EmptyView()
        case .checking:
            HStack(spacing: 10) {
                ProgressView()
                Text("A verificar…").foregroundStyle(.secondary)
            }
        case .valid:
            Label("A chave funciona", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func save() {
        let key = draftKey.trimmed
        guard !key.isEmpty else { return }
        check(key, saveIfValid: true)
    }

    /// Testa a chave; ao guardar, só fica guardada se funcionar (ou se o problema for só a quota).
    private func check(_ key: String, saveIfValid: Bool) {
        withAnimation { status = .checking }
        Task {
            let error = await GeminiReader.test(key: key)
            if saveIfValid, error == nil || error == .quota {
                Keychain.set(key, for: GeminiReader.keychainAccount)
                draftKey = ""
                hasKey = true
            }
            withAnimation {
                if let error {
                    status = .failed(error == .quota ? "Chave guardada, mas o limite gratuito está esgotado por agora." : error.message)
                } else {
                    status = .valid
                }
            }
            if error == nil { Haptics.success() } else { Haptics.warning() }
        }
    }
}
