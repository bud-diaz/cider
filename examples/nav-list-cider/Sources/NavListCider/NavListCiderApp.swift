//  A narrow reference application for NavigationView + List together,
//  standalone from examples/ui-showcase (which combines nav/list/form/image/
//  modal into one app). Push replaces the screen; List's rows are ordinary
//  buttons, reusing UI-LIST-001/NAV-PUSH-001/NAV-POP-001 conformance
//  coverage rather than adding new node kinds.

import CiderUI

@main
struct NavListCiderApp: CiderApp {
    @CiderState private var path: [any CiderView] = []

    var body: some CiderView {
        NavigationView($path) {
            RootListScreen(path: $path)
        }
    }
}

struct RootListScreen: CiderView {
    let path: CiderState<[any CiderView]>

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Rooms").font(size: 28, weight: .bold)

            List(width: 280, height: 320, spacing: 8) {
                for index in 0..<8 {
                    Button("Room \(index)") {
                        path.wrappedValue.append(RoomDetailScreen(index: index, path: path))
                    }
                }
            }
        }
    }
}

struct RoomDetailScreen: CiderView {
    let index: Int
    let path: CiderState<[any CiderView]>

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Room \(index)").font(size: 24, weight: .bold)
            Button("Back") { path.wrappedValue.removeLast() }
        }
    }
}
