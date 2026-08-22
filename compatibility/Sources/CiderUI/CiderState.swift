//  Application state that invalidates the frame when it changes.

/// Storage the runtime can attach an invalidation callback to, without knowing
/// what type is inside.
protocol CiderStateStorage: AnyObject {
    /// Called by the adapter at launch. The closure is retained for the life of
    /// the application.
    func attach(invalidate: @escaping () -> Void)
}

/// A piece of application state.
///
///     struct DemoApp: CiderApp {
///         @CiderState private var count = 0
///         ...
///     }
///
/// Writing to the property marks the current frame stale; the runtime rebuilds
/// the view tree and redraws before the next frame.
///
/// The wrapper is a class, for two reasons. A view is a value that Cider copies
/// freely -- into closures, out of `body` -- and every copy has to see the same
/// state. And a button's action closure captures the app by value, so a value
/// wrapper would have the action incrementing a copy that is thrown away.
@propertyWrapper
public final class CiderState<Value>: CiderStateStorage {
    private var value: Value
    private var invalidate: (() -> Void)?

    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }

    public var wrappedValue: Value {
        get { value }
        set {
            value = newValue
            invalidate?()
        }
    }

    /// `$count` yields a binding-like accessor. Kept minimal: there is nothing
    /// in the MVP node set that takes a two-way binding yet.
    public var projectedValue: CiderState<Value> { self }

    func attach(invalidate: @escaping () -> Void) {
        self.invalidate = invalidate
    }
}
