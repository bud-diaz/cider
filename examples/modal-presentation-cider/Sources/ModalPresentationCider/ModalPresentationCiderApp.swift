//  A narrow reference application for Modal alone, standalone from
//  examples/ui-showcase (which wraps a NavigationView inside a Modal). No
//  navigation stack here -- just the top-level base/presented pair -- so
//  UI-MODAL-001's dim-overlay and tap-blocking behavior is exercised without
//  anything else in the way.

import CiderUI

@main
struct ModalPresentationCiderApp: CiderApp {
    @CiderState private var isPresented = false

    var body: some CiderView {
        Modal($isPresented) {
            VStack(spacing: 24) {
                Text("Base Screen").font(size: 28, weight: .bold)
                Button("Show") { isPresented = true }
            }
        } presenting: {
            VStack(spacing: 16) {
                Text("Presented Sheet").font(size: 24, weight: .bold)
                Button("Close") { isPresented = false }
            }
        }
    }
}
