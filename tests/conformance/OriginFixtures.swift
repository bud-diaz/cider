//  Views whose source positions the origin tests assert against.
//
//  Each fixture keeps its expected line number on the *same physical line* as
//  the view it describes, captured with `#line`. That is deliberate: an
//  assertion written as a literal line number in the test file goes stale the
//  first time anyone adds an import, and a stale assertion about source
//  positions is worse than none. Keeping the two together means they cannot
//  drift apart.
//
//  Do not reformat the one-line fixtures onto several lines. The test that
//  proves two views on one line get distinct columns depends on them sharing
//  one.

import CiderCore
import CiderUI

enum OriginFixtures {

    static let singleTextLine = #line; static var singleText: some CiderView { Text("origin") }

    static let chainedLine = #line; static var chained: some CiderView { Text("chained").font(size: 28, weight: .bold) }

    static let pairLine = #line; static var pair: some CiderView { VStack { Text("left"); Text("right") } }

    /// Two loose children, so `ScrollView` builds its synthetic `/wrap` node.
    static var scrollWithLooseChildren: some CiderView {
        ScrollView(width: 120, height: 120) {
            Text("one")
            Text("two")
        }
    }

    /// A list, so `List` builds its synthetic `/rows` node.
    static var listWithRows: some CiderView {
        List(width: 120, height: 120, spacing: 4) {
            Text("row")
        }
    }

    static var stackWithWrittenSpacing: some CiderView { VStack(spacing: 24) { Text("x") } }

    static var stackWithDefaultSpacing: some CiderView { VStack { Text("x") } }
}

/// Every view kind in its ordinary call form, including the trailing-closure
/// forms. Adding defaulted location parameters to an initializer changes how
/// Swift matches a trailing closure; if that ever goes wrong, this stops
/// compiling, which is the point.
struct EveryViewFormApp: CiderApp {
    @CiderState var text = ""
    @CiderState var isPresented = false
    @CiderState var path: [any CiderView] = []

    var body: some CiderView {
        VStack(spacing: 8, alignment: .leading) {
            Text("text").font(size: 12, weight: .bold).foregroundColor(.white)
            Button("button") {}
                .font(size: 12)
                .disabled(false)
                .foregroundColor(.white)
                .background(.black, pressed: .white)
                .cornerRadius(4)
                .padding(horizontal: 8, vertical: 4)
            Image(ImageSource.solid(.white, width: 4, height: 4))
            TextField($text, width: 60)
                .font(size: 12)
                .foregroundColor(.white)
                .background(.black)
                .cornerRadius(4)
                .padding(horizontal: 8, vertical: 4)
            ScrollView(width: 60, height: 60) { Text("scroll") }
            List(width: 60, height: 60) { Text("row") }
            NavigationView($path) { Text("root") }
            Modal($isPresented) { Text("base") } presenting: { Text("sheet") }
        }
    }
}
