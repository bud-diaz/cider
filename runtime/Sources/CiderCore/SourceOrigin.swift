//  Where a value in the running application was written.
//
//  The developer console's editor changes a property by rewriting the Swift
//  that produced it, which means something has to connect a node in a running
//  process back to a call in a file. Nothing else in Cider needs this, and the
//  UI tree deliberately cannot carry it -- `UINode` is pure, comparable data,
//  and a file path is neither stable across machines nor meaningful to compare.
//
//  So origins travel beside the tree, in `ApplicationScene`, exactly as button
//  actions and text-input handlers already do.

/// A source position, as the compiler reported it at a call site.
///
/// Captured through defaulted `#filePath`/`#line`/`#column` parameters rather
/// than a macro or a build-time index: those default arguments are evaluated at
/// the *caller*, which is the only place that knows where a view was written,
/// and they cost no dependency.
public struct SourceOrigin: Codable, Equatable, Sendable {
    /// `#filePath` -- absolute, as the compiler saw it. `#fileID` was rejected:
    /// it is `Module/File.swift`, so two files with the same name in different
    /// directories are indistinguishable, and there is no index to resolve it
    /// back to a path.
    public var file: String

    /// 1-based, as `#line` reports it.
    public var line: Int

    /// 1-based, as `#column` reports it.
    ///
    /// For a chained call this is the position of the *whole* expression, not
    /// the individual member -- `Text("x").font(size: 28)` reports the same
    /// column for both. A consumer must therefore treat this as an anchor to
    /// find the expression, not as a locator for one modifier within it.
    public var column: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}

/// Where one node, and each value on it, was written.
public struct NodeOrigins: Codable, Equatable, Sendable {
    /// The name of the view type that produced this node -- `Text`, `List`.
    ///
    /// Recorded rather than derived from the node's kind, because the two do
    /// not always match: a `List` lowers to a `ScrollViewNode`, so a consumer
    /// reading the kind alone would look for the wrong expression in the
    /// source and find nothing.
    public var view: String

    /// The call that constructed the view.
    public var construction: SourceOrigin

    /// Keyed by the property name the inspector snapshot uses, so that a
    /// console holding a snapshot can go straight from a property row to the
    /// call that set it.
    ///
    /// A property missing from this table was never written: it came from
    /// `Theme` or from an initializer's default. That distinction is the whole
    /// point of the table -- writing a value that is present means rewriting an
    /// argument, and writing one that is absent means inserting a call.
    public var properties: [String: SourceOrigin]

    public init(view: String, construction: SourceOrigin, properties: [String: SourceOrigin] = [:]) {
        self.view = view
        self.construction = construction
        self.properties = properties
    }
}
