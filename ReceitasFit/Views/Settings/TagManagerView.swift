import SwiftUI
import SwiftData

/// Gerir as etiquetas: criar, mudar o nome, juntar duas numa e apagar.
/// Mostra as usadas nas receitas e as da lista (as de origem e as criadas aqui), mesmo sem receitas.
struct TagManagerView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]
    @AppStorage(TagLibrary.catalogKey) private var catalogRaw = ""

    @State private var creating = false
    @State private var renaming: String?
    @State private var newName = ""
    @State private var deleting: String?
    @State private var message: String?

    private var tags: [(tag: String, count: Int)] {
        TagLibrary.all(in: recipes, catalog: TagLibrary.decodeCatalog(catalogRaw))
    }

    var body: some View {
        List {
            Section {
                ForEach(tags, id: \.tag) { item in
                    Button {
                        newName = item.tag
                        renaming = item.tag
                    } label: {
                        LabeledContent {
                            Text(item.count == 0 ? "Sem receitas" : Format.recipes(item.count))
                        } label: {
                            Label(item.tag, systemImage: "tag")
                                .foregroundStyle(.primary)
                        }
                    }
                    .swipeActions {
                        Button("Apagar", systemImage: "trash", role: .destructive) { deleting = item.tag }
                        Button("Mudar nome", systemImage: "pencil") {
                            newName = item.tag
                            renaming = item.tag
                        }
                        .tint(.orange)
                    }
                }
            } footer: {
                if !tags.isEmpty {
                    Text("Toca numa etiqueta para lhe mudar o nome. Se escreveres o nome de outra que já existe, as duas juntam-se numa só. Apagar tira a etiqueta das receitas, mas não apaga as receitas.")
                }
            }
        }
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label("Sem etiquetas", systemImage: "tag")
                } description: {
                    Text("Cria etiquetas como “Meal prep” ou “Pós-treino” para organizar as receitas.")
                } actions: {
                    Button("Nova etiqueta") { startCreating() }
                        .buttonStyle(.glassProminent)
                }
            }
        }
        .navigationTitle("Etiquetas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Nova etiqueta", systemImage: "plus") { startCreating() }
            }
        }
        .animation(.snappy, value: tags.map(\.tag))
        .alert("Nova etiqueta", isPresented: $creating) {
            TextField("Nome da etiqueta", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Criar") { create() }
        } message: {
            Text("Fica disponível no editor de receitas.")
        }
        .alert("Mudar nome", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nome da etiqueta", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { rename() }
        } message: {
            if let renaming {
                let count = tags.first { $0.tag == renaming }?.count ?? 0
                Text(count == 0 ? "“\(renaming)” ainda não está em nenhuma receita." : "“\(renaming)” está em \(Format.recipes(count)).")
            }
        }
        .confirmationDialog(
            "Apagar a etiqueta?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { tag in
            Button("Apagar “\(tag)”", role: .destructive) {
                let count = TagLibrary.delete(tag, in: recipes)
                try? context.save()
                Haptics.warning()
                if count > 0 { message = "Etiqueta tirada de \(Format.recipes(count))." }
            }
        } message: { tag in
            let count = tags.first { $0.tag == tag }?.count ?? 0
            Text(count == 0 ? "“\(tag)” deixa de aparecer nas sugestões do editor." : "As receitas com “\(tag)” ficam sem esta etiqueta.")
        }
        .alert("Etiquetas", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func startCreating() {
        newName = ""
        creating = true
    }

    private func create() {
        let name = newName.trimmed
        guard !name.isEmpty else { return }
        if TagLibrary.create(name, in: recipes) {
            Haptics.success()
        } else {
            message = "Já existe a etiqueta “\(name)”."
        }
    }

    private func rename() {
        guard let old = renaming else { return }
        let name = newName.trimmed
        guard !name.isEmpty, name != old else { return }
        let merging = tags.contains { $0.tag == name }
        TagLibrary.rename(old, to: name, in: recipes)
        try? context.save()
        Haptics.success()
        if merging { message = "“\(old)” juntou-se a “\(name)”." }
    }
}
