//  A narrow reference application for bound, editable TextField state,
//  standalone from persistence. Contrast with examples/notes-cider, which
//  pairs TextField with CiderStorage/CiderPreferences -- this app is just
//  the binding and the submit round-trip, reusing UI-TEXTFIELD-001
//  conformance coverage.

import CiderUI

@main
struct FormInputCiderApp: CiderApp {
    @CiderState private var draft = ""
    @CiderState private var submitted = ""

    var body: some CiderView {
        VStack(spacing: 18) {
            Text("Form Input").font(size: 28, weight: .bold)
            TextField($draft, width: 280)
            Button("Submit") { submitted = draft }
            Text("Submitted: \(submitted)").font(size: 14)
        }
    }
}
