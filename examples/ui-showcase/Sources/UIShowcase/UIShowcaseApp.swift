//  A reference application exercising Stage 2's UI primitives together.
//
//  docs/02-product-requirements.md section 5 lists "navigation/list app",
//  "form/text-input app", "image-loading app" and "modal/presentation
//  example" among the MVP reference applications; this app is all four at
//  once rather than four separate projects, since Stage 2's exit criterion
//  ("UI reference apps pass deterministic conformance and visual regression
//  tests") is about the primitives working *together*, and each primitive
//  already has its own isolated conformance coverage
//  (UI-LIST-001/UI-TEXTFIELD-001/UI-IMAGE-001/UI-MODAL-001/NAV-PUSH-001/
//  NAV-POP-001 in tests/conformance/ConformanceTests.swift).

import CiderUI

@main
struct UIShowcaseApp: CiderApp {
    @CiderState private var path: [any CiderView] = []
    @CiderState private var note = ""
    @CiderState private var isShowingAbout = false

    var body: some CiderView {
        Modal($isShowingAbout) {
            NavigationView($path) {
                ItemListScreen(path: $path, note: $note, isShowingAbout: $isShowingAbout)
            }
        } presenting: {
            AboutScreen(isShowingAbout: $isShowingAbout)
        }
    }
}

/// The root screen: a scrollable list of items, each pushing a detail
/// screen, and a button that presents the "About" modal over the whole
/// navigation stack -- not just this one screen.
struct ItemListScreen: CiderView {
    let path: CiderState<[any CiderView]>
    let note: CiderState<String>
    let isShowingAbout: CiderState<Bool>

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Items").font(size: 28, weight: .bold)

            List(width: 320, height: 360, spacing: 8) {
                for index in 0..<8 {
                    Button("Item \(index)") {
                        path.wrappedValue.append(
                            ItemDetailScreen(index: index, path: path, note: note)
                        )
                    }
                }
            }

            Button("About") { isShowingAbout.wrappedValue = true }
        }
    }
}

/// A pushed detail screen: an image, a text field bound to shared state
/// (there is no per-item storage yet -- that is Stage 3's job), and a way
/// back.
struct ItemDetailScreen: CiderView {
    let index: Int
    let path: CiderState<[any CiderView]>
    let note: CiderState<String>

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Item \(index)").font(size: 24, weight: .bold)
            Image(.solid(Color(hex: 0x1F6FEB), width: 96, height: 96))
            TextField(note, width: 240)
            Button("Back") { path.wrappedValue.removeLast() }
        }
    }
}

/// The "About" modal, presented over whichever screen the navigation stack
/// is currently showing.
struct AboutScreen: CiderView {
    let isShowingAbout: CiderState<Bool>

    var body: some CiderView {
        VStack(spacing: 16) {
            Text("About").font(size: 24, weight: .bold)
            Text("A showcase of Stage 2's UI primitives.")
            Button("Close") { isShowingAbout.wrappedValue = false }
        }
    }
}
