//  The canonical first Cider application.
//
//  Everything the first milestone set out to prove is in these twenty lines: a
//  Swift-defined application, a declarative view, state, a button, and an action
//  that changes what is on screen.

import CiderUI

@main
struct HelloCiderApp: CiderApp {

    /// Writing to this property marks the frame stale. The runtime rebuilds the
    /// view tree and redraws before the next frame; nothing else has to be told.
    @CiderState private var count = 0

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Cider Demo")
                .font(size: 28, weight: .bold)

            Button("Press Me") {
                count += 1
            }

            Text("Count: \(count)")
        }
    }
}
