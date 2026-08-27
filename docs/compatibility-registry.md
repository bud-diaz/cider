# Cider Compatibility Registry

Generated from `CompatibilityRegistry`.

| Symbol | Domain | Level | Summary | Guidance |
| --- | --- | --- | --- | --- |
| `CiderApp` | Application lifecycle | A | Cider application entry point | Use CiderApp for Stage 0-3 reference applications. |
| `Button` | Declarative UI | A | button view | Cider Button runs an action and redraws after state changes. |
| `CiderView` | Declarative UI | A | Cider view protocol | Use CiderView with the Stage 2 CiderUI primitives. |
| `Text` | Declarative UI | A | single-line text view | Cider Text supports one-line left-to-right text. |
| `VStack` | Declarative UI | A | vertical stack view | Use VStack for simple vertical layout. |
| `Image` | Declarative UI | B | raw-pixel image view | Cider Image uses already-decoded ImageSource pixels; PNG/JPEG decoding is not implemented. |
| `List` | Declarative UI | B | non-virtualized list | Cider List preserves row order and scrolls, but has no virtualization or keyed identity. |
| `ScrollView` | Declarative UI | B | explicit-size scroll view | Cider ScrollView requires explicit width and height and has no automatic fill layout. |
| `TextField` | Declarative UI | B | ASCII text field | Cider TextField edits printable ASCII via keysyms; composed/IME input is not implemented on X11. |
| `SwiftUI` | Declarative UI | D | SwiftUI is not implemented by Cider | Use CiderUI primitives for the supported Stage 2 surface. |
| `UIKit` | Declarative UI | D | UIKit is not implemented by Cider | Use CiderUI primitives for the supported Stage 2 surface. |
| `View` | Declarative UI | D | SwiftUI View is not implemented by Cider | Use CiderView and import CiderUI instead of SwiftUI. |
| `Camera` | Device services | D | camera access is unsupported | Use an app-owned fixture or mock image source when running under Cider. |
| `CiderHTTP` | HTTP networking | B | permission-checked blocking HTTP helper | Use CiderHTTP for Stage 3 REST calls; async task integration is not implemented yet. |
| `URLSession` | HTTP networking | D | URLSession is not implemented by Cider | Use CiderHTTP for the current permission-checked HTTP subset. |
| `CiderStorage` | Local files | B | sandboxed UTF-8 text storage | Use CiderStorage for Documents, Cache and tmp text files. |
| `NavigationView` | Navigation | B | Cider navigation stack | Use CiderState-backed NavigationView push/pop for the supported navigation subset. |
| `CoreData` | Persistence | D | Core Data is unsupported | Use CiderStorage or an app-owned persistence abstraction for Cider runs. |
| `CiderPreferences` | Preferences | A | sandboxed string preferences | Use CiderPreferences for small string values scoped to the app sandbox. |
| `Modal` | Presentation | B | full-screen modal presenter | Cider Modal presents full-screen only; partial sheets are not implemented. |
| `Product` | Purchases | D | StoreKit Product purchases are unsupported | Cider does not simulate purchases; replace this path with a development stub owned by the app. |
| `StoreKit` | Purchases | D | StoreKit purchases are unsupported | Remove purchase flows or guard them out while running under Cider. |
