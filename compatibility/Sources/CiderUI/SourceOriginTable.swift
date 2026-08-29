//  Bookkeeping for where a view's values were written.
//
//  Every primitive view needs the same two things: the call that built it, and
//  the call that set each value the developer actually wrote. This is that,
//  once, rather than the same four lines in nine files.
//
//  It is not part of the public API. An application never sees a `SourceOrigin`
//  and never passes one -- the location parameters that produce them are
//  defaulted `#filePath`/`#line`/`#column`, which is the whole point.

import CiderCore

struct SourceOriginTable {
    private let construction: SourceOrigin
    private var properties: [String: SourceOrigin]

    /// - Parameter initializerProperties: names of properties this view's
    ///   initializer always writes. They take the construction site, because
    ///   there is no separate call to point at: `Text("x")` writes its text
    ///   wherever the `Text` itself is written.
    init(
        file: String,
        line: Int,
        column: Int,
        initializerProperties: [String] = []
    ) {
        construction = SourceOrigin(file: file, line: line, column: column)
        properties = [:]
        for name in initializerProperties { properties[name] = construction }
    }

    /// Records that `names` were set by a call at this position.
    ///
    /// One call can set several properties -- `.font(size:weight:)` sets both
    /// -- and they all point at the same expression, because that is the one an
    /// edit has to rewrite.
    mutating func record(file: String, line: Int, column: Int, for names: [String]) {
        let origin = SourceOrigin(file: file, line: line, column: column)
        for name in names { properties[name] = origin }
    }

    /// Records an initializer argument that the caller may or may not have
    /// passed. Nothing is recorded when it was omitted, which is how a consumer
    /// tells "written, rewrite it" from "defaulted, insert it".
    mutating func recordIfWritten(_ name: String, _ wasWritten: Bool) {
        if wasWritten { properties[name] = construction }
    }

    var nodeOrigins: NodeOrigins {
        NodeOrigins(construction: construction, properties: properties)
    }
}
