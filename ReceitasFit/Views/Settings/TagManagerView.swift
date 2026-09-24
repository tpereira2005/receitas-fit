import SwiftUI
import SwiftData

/// Gerir as etiquetas de todas as receitas: mudar o nome, juntar duas numa e apagar.
struct TagManagerView: View {
    @Environment(\.modelContext) private var context
    @Query private var recipes: [Recipe]

    @State private var renaming: String?
    @State private var newName = ""
    @State private var deleting: String?
    @State private var message: String?

    private var tags: [(tag: String, count: Int)] { TagLibrary.counts(in: recipes) }

    var body: some View {
        List {
            Section {
                ForEach(tags, id: \.tag) { item in
                    Button {
                        newName = item.tag
                        renaming = item.tag
                    } label: {
                        LabeledContent {
                            Text(Format.recipes(item.count))
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
                ContentUnavailableView(
                    "Sem etiquetas",
                    systemImage: "tag",
                    description: Text("Acrescenta etiquetas no editor de receitas, como “Meal prep” ou “Pós-treino”.")
                )
            }
        }
        .navigationTitle("Etiquetas")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.snappy, value: tags.map(\.tag))
        .alert("Mudar nome", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nome da etiqueta", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { rename() }
        } message: {
            if let renaming {
                Text("“\(renaming)” está em \(Format.recipes(tags.first { $0.tag == renaming }?.count ?? 0)).")
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
                message = "Etiqueta tirada de \(Format.recipes(count))."
            }
        } message: { tag in
            Text("As receitas com “\(tag)” ficam sem esta etiqueta.")
        }
        .alert("Etiquetas", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
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
