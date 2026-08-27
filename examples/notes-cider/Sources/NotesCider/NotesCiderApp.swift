import CiderUI

@main
struct NotesCiderApp: CiderApp {
    @CiderState private var draft = ""
    @CiderState private var status = "Ready"

    var body: some CiderView {
        VStack(spacing: 18) {
            Text("Notes").font(size: 28, weight: .bold)
            TextField($draft, width: 280)
            Button("Save") { saveDraft() }
            Button("Load") { loadDraft() }
            Button("Copy") { CiderClipboard.copy(draft) }
            Text(status).font(size: 14)
            Text("App: \(CiderEnvironment.appID ?? "unknown")").font(size: 12)
        }
    }

    private func saveDraft() {
        do {
            try CiderStorage.documents.writeText(draft, named: "note.txt")
            try CiderPreferences.standard.set("note.txt", forKey: "lastNote")
            status = "Saved note.txt"
        } catch {
            status = "Save failed"
        }
    }

    private func loadDraft() {
        do {
            let name = try CiderPreferences.standard.string(forKey: "lastNote") ?? "note.txt"
            draft = try CiderStorage.documents.readText(named: name)
            status = "Loaded \(name)"
        } catch {
            status = "Load failed"
        }
    }
}
