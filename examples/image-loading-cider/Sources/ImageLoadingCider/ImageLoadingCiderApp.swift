//  A narrow reference application for Image/ImageSource, standalone from
//  examples/ui-showcase's combined demo. Cider has no image decoder yet
//  (B1's ImageSource is deliberately raw-RGBA8 / .solid(...) only), so this
//  cycles through solid-color sources of different sizes rather than
//  "loading" a file -- that is the honest whole story for Image today.

import CiderUI

@main
struct ImageLoadingCiderApp: CiderApp {
    private static let swatches: [ImageSource] = [
        .solid(Color(hex: 0xE89A2F), width: 96, height: 96),
        .solid(Color(hex: 0x34342F), width: 64, height: 128),
        .solid(Color(hex: 0xF5F1E8), width: 128, height: 64),
    ]

    @CiderState private var index = 0

    var body: some CiderView {
        VStack(spacing: 24) {
            Text("Image Loading").font(size: 28, weight: .bold)
            Image(Self.swatches[index])
            Button("Next") { index = (index + 1) % Self.swatches.count }
            Text("Swatch \(index + 1) of \(Self.swatches.count)").font(size: 14)
        }
    }
}
