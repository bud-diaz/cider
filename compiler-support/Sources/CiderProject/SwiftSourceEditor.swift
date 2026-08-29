//  Writing a property change back into Swift source.
//
//  The governing rule is that this only ever does one of two things: replace a
//  span it has *proved* is a single literal token, or append a fully-formed
//  modifier at a chain end it has *proved* is well-formed. It never deletes,
//  never reflows, never reorders, and never touches a span containing a
//  comment. Anything it cannot prove, it declines with a `Diagnostic`.
//
//  That asymmetry is deliberate. A refused edit costs a developer one manual
//  change; a wrong one costs them their file, and the fact that `cider dev`
//  rebuilds and runs whatever lands on disk makes a wrong one much worse than
//  an inconvenience.

import Foundation

import CiderCore

/// How one editable property is written in Swift.
struct SwiftPropertySetter {
    enum Call {
        /// An argument of the view's own initializer.
        case initializer
        /// A modifier applied to the view, by selector name.
        case modifier(String)
    }

    /// What the written value is allowed to look like.
    enum Shape {
        /// One literal token: a number, a plain string, `true`/`false`, or a
        /// leading-dot enum case.
        case literal
        /// A `Color(hex:)` call whose arguments are themselves literals. A
        /// colour is the property an editor is most often asked to change and
        /// it is never a bare literal, so it gets its own proof rather than
        /// being permanently unwritable.
        case colorCall
    }

    var call: Call

    /// The argument's label, or nil when it is positional.
    var label: String?

    var shape: Shape = .literal

    /// Index among the positional arguments, when `label` is nil.
    var positionalIndex: Int = 0

    /// The other arguments of the same call, in declaration order. Needed only
    /// when the call has to be written from scratch, because a modifier is
    /// inserted whole or not at all.
    var siblings: [String] = []

    /// `Button.disabled(_:)` is the inverse of the `isEnabled` the panel shows.
    var invertsBool: Bool = false

    /// Declaration order of the initializer's labelled arguments, for the one
    /// case where an argument has to be inserted into an existing list.
    var initializerOrder: [String] = []
}

enum SwiftSourceEditor {

    /// One requested change. Addressed by source position, never by `NodeID`:
    /// a structural path can be re-keyed by a state change between the snapshot
    /// and the click, and a file position cannot.
    struct Edit {
        var head: String
        var line: Int
        var column: Int
        var property: String

        /// Already formatted as a Swift literal by the caller.
        var newValue: String

        /// What the panel displayed. Compared against what is actually in the
        /// source, so a stale snapshot is refused rather than acted on -- a
        /// compare-and-swap on the exact token, with no hash to compute and no
        /// window between reading and writing.
        var expectedCurrentValue: String?

        /// Current values of the call's other arguments, as Swift literals, for
        /// when the call has to be inserted whole.
        var siblingValues: [String: String] = [:]
    }

    // MARK: - The editable set
    //
    // One selector per property, and no overloads anywhere in it. The locator
    // finds a modifier by name with no type information, so two `padding`
    // overloads would make "which argument list is this" unanswerable.

    static let setters: [String: [String: SwiftPropertySetter]] = [
        "Text": [
            "text": SwiftPropertySetter(call: .initializer, label: nil),
            "fontSize": SwiftPropertySetter(call: .modifier("font"), label: "size", siblings: ["weight"]),
            "fontWeight": SwiftPropertySetter(call: .modifier("font"), label: "weight", siblings: ["size"]),
            "color": SwiftPropertySetter(call: .modifier("foregroundColor"), label: nil, shape: .colorCall),
        ],
        "Button": [
            "title": SwiftPropertySetter(call: .initializer, label: nil),
            "fontSize": SwiftPropertySetter(call: .modifier("font"), label: "size", siblings: ["weight"]),
            "fontWeight": SwiftPropertySetter(call: .modifier("font"), label: "weight", siblings: ["size"]),
            "isEnabled": SwiftPropertySetter(call: .modifier("disabled"), label: nil, invertsBool: true),
            "titleColor": SwiftPropertySetter(call: .modifier("foregroundColor"), label: nil, shape: .colorCall),
            "backgroundColor": SwiftPropertySetter(call: .modifier("background"), label: nil, shape: .colorCall, siblings: ["pressed"]),
            "pressedBackgroundColor": SwiftPropertySetter(call: .modifier("background"), label: "pressed", shape: .colorCall, siblings: ["_0"]),
            "cornerRadius": SwiftPropertySetter(call: .modifier("cornerRadius"), label: nil),
            "paddingHorizontal": SwiftPropertySetter(call: .modifier("padding"), label: "horizontal", siblings: ["vertical"]),
            "paddingVertical": SwiftPropertySetter(call: .modifier("padding"), label: "vertical", siblings: ["horizontal"]),
        ],
        "TextField": [
            "width": SwiftPropertySetter(call: .initializer, label: "width"),
            "fontSize": SwiftPropertySetter(call: .modifier("font"), label: "size", siblings: ["weight"]),
            "fontWeight": SwiftPropertySetter(call: .modifier("font"), label: "weight", siblings: ["size"]),
            "textColor": SwiftPropertySetter(call: .modifier("foregroundColor"), label: nil, shape: .colorCall),
            "backgroundColor": SwiftPropertySetter(call: .modifier("background"), label: nil, shape: .colorCall),
            "cornerRadius": SwiftPropertySetter(call: .modifier("cornerRadius"), label: nil),
            "paddingHorizontal": SwiftPropertySetter(call: .modifier("padding"), label: "horizontal", siblings: ["vertical"]),
            "paddingVertical": SwiftPropertySetter(call: .modifier("padding"), label: "vertical", siblings: ["horizontal"]),
        ],
        "VStack": [
            "spacing": SwiftPropertySetter(
                call: .initializer, label: "spacing", initializerOrder: ["spacing", "alignment"]
            ),
            "alignment": SwiftPropertySetter(
                call: .initializer, label: "alignment", initializerOrder: ["spacing", "alignment"]
            ),
        ],
        "ScrollView": [
            "viewportWidth": SwiftPropertySetter(call: .initializer, label: "width"),
            "viewportHeight": SwiftPropertySetter(call: .initializer, label: "height"),
        ],
        "List": [
            "viewportWidth": SwiftPropertySetter(call: .initializer, label: "width"),
            "viewportHeight": SwiftPropertySetter(call: .initializer, label: "height"),
            "spacing": SwiftPropertySetter(
                call: .initializer, label: "spacing", initializerOrder: ["width", "height", "spacing"]
            ),
        ],
    ]

    /// Whether the editor is willing to write this property at all.
    static func requireSetter(head: String, property: String) throws -> SwiftPropertySetter {
        guard let setter = setters[head]?[property] else {
            throw Diagnostic(
                code: "CID0640",
                summary: "'\(property)' is not editable on a \(head)",
                reason: "The editor writes only properties that have a form an application could have written.",
                remedy: "Change this value in the source by hand."
            )
        }
        return setter
    }

    // MARK: - Applying

    /// Returns `source` with `edit` applied, or throws explaining why not.
    static func apply(_ edit: Edit, to source: String) throws -> String {
        let setter = try requireSetter(head: edit.head, property: edit.property)
        let scanned = try SwiftSource(source)
        let chain = try SwiftExpressionLocator.locate(
            head: edit.head,
            line: edit.line,
            column: edit.column,
            in: scanned
        )

        let value = setter.invertsBool ? try invertedBool(edit.newValue) : edit.newValue

        switch setter.call {
        case .initializer:
            guard let arguments = chain.initializerArguments else {
                // `VStack { }` -- everything is the trailing closure, so there
                // is no list to write into and one has to be synthesised.
                return try insertingInitializerArgument(
                    setter, value: value, chain: chain, arguments: nil, in: scanned, edit: edit
                )
            }
            if let existing = existingArgument(setter, in: arguments) {
                return try replacing(existing, with: value, shape: setter.shape, in: scanned, edit: edit)
            }
            return try insertingInitializerArgument(
                setter, value: value, chain: chain, arguments: arguments, in: scanned, edit: edit
            )

        case .modifier(let name):
            if let segment = chain.lastSegment(named: name),
               let arguments = segment.arguments,
               let existing = existingArgument(setter, in: arguments) {
                return try replacing(existing, with: value, shape: setter.shape, in: scanned, edit: edit)
            }
            return try insertingModifier(name, setter, value: value, chain: chain, in: scanned, edit: edit)
        }
    }

    private static func existingArgument(
        _ setter: SwiftPropertySetter,
        in arguments: SwiftArgumentList
    ) -> SwiftArgument? {
        if let label = setter.label { return arguments.argument(labelled: label) }
        return arguments.positional(setter.positionalIndex)
    }

    // MARK: - Replacing a value that is already written

    private static func replacing(
        _ argument: SwiftArgument,
        with value: String,
        shape: SwiftPropertySetter.Shape,
        in source: SwiftSource,
        edit: Edit
    ) throws -> String {
        try proveReplaceable(argument, shape: shape, source: source, edit: edit)

        if let expected = edit.expectedCurrentValue {
            let actual = source.text(from: argument.valueStart, to: argument.valueEnd)
            guard matches(actual: actual, expected: expected) else {
                throw Diagnostic(
                    code: "CID0634",
                    summary: "the source changed since this value was read",
                    location: DiagnosticLocation(file: "<source>", line: edit.line),
                    reason: "The editor expected `\(expected)` here and found `\(actual)`.",
                    remedy: "Let `cider dev` rebuild, then select the view again."
                )
            }
        }

        var characters = source.characters
        characters.replaceSubrange(argument.valueStart..<argument.valueEnd, with: Array(value))
        return String(characters)
    }

    /// A value may be replaced only when it is one literal token -- optionally a
    /// leading `-`, or a leading `.` for an enum case. An expression, a named
    /// constant, or an interpolated string all mean the developer wrote
    /// something the editor would be destroying rather than editing.
    private static func proveReplaceable(
        _ argument: SwiftArgument,
        shape: SwiftPropertySetter.Shape,
        source: SwiftSource,
        edit: Edit
    ) throws {
        func refuse(_ reason: String) -> Diagnostic {
            Diagnostic(
                code: "CID0636",
                summary: "'\(edit.property)' is not a literal in the source",
                location: DiagnosticLocation(file: "<source>", line: edit.line),
                reason: reason,
                remedy: "Change this value in the source by hand; the editor will not rewrite an expression."
            )
        }

        // Comments are filtered out of the token stream the locator walks, so
        // they never appear in `valueTokens` -- but the span being replaced is
        // measured in characters, and a comment can still sit inside it. That
        // only happens for a multi-token shape like `Color(hex: /* x */ 0xFF)`;
        // a comment before a single literal falls outside the span and is
        // preserved, which is the right outcome.
        let spansAComment = source.tokens.contains { token in
            token.kind == .comment && token.start < argument.valueEnd && token.end > argument.valueStart
        }
        if spansAComment {
            throw refuse("There is a comment inside this value, and rewriting it would delete the comment.")
        }

        if case .colorCall = shape {
            try proveColorCall(argument, source: source, refuse: refuse)
            return
        }

        var tokens = argument.valueTokens
        if let first = tokens.first, source.text(of: first) == "-", first.kind == .operatorRun {
            tokens = Array(tokens.dropFirst())
        }

        // `.bold` and the like: a dot then a case name.
        if tokens.count == 2, source.text(of: tokens[0]) == ".", tokens[1].kind == .identifier {
            return
        }

        guard tokens.count == 1, let only = tokens.first else {
            throw refuse("The value here is an expression, not a single literal.")
        }

        switch only.kind {
        case .number:
            return
        case .string(let interpolated, let raw, let multiline):
            if interpolated {
                throw Diagnostic(
                    code: "CID0637",
                    summary: "'\(edit.property)' is computed at run time",
                    location: DiagnosticLocation(file: "<source>", line: edit.line),
                    reason: "This string interpolates a value, so there is no fixed text in the source to change.",
                    remedy: "Change the interpolated expression in the source by hand."
                )
            }
            if raw || multiline {
                throw Diagnostic(
                    code: "CID0637",
                    summary: "'\(edit.property)' is a raw or multiline string literal",
                    location: DiagnosticLocation(file: "<source>", line: edit.line),
                    reason: "Rewriting one means reproducing its delimiters exactly, which the editor does not attempt.",
                    remedy: "Change this value in the source by hand."
                )
            }
            return
        case .identifier:
            // `true`, `false`, `nil` are literals; anything else is a name that
            // stands for something, and replacing it would discard the meaning.
            let text = source.text(of: only)
            if text == "true" || text == "false" { return }
            throw refuse("`\(text)` is a name, not a literal. Replacing it would discard what it stands for.")
        default:
            throw refuse("The value here is not a literal.")
        }
    }

    /// A colour is written as `Color(hex: 0xRRGGBB)`, optionally with an
    /// `alpha:`. Replacing that whole call with another one of the same shape
    /// is as safe as replacing a literal, and it is the only way colours become
    /// editable at all -- a colour is never a bare token.
    ///
    /// A named colour (`Theme.ciderAmber`) is refused: overwriting it would
    /// silently discard the developer's reference to the theme.
    private static func proveColorCall(
        _ argument: SwiftArgument,
        source: SwiftSource,
        refuse: (String) -> Diagnostic
    ) throws {
        let tokens = argument.valueTokens
        guard tokens.count >= 3,
              tokens[0].kind == .identifier,
              source.text(of: tokens[0]) == "Color",
              source.text(of: tokens[1]) == "(",
              source.text(of: tokens[tokens.count - 1]) == ")" else {
            let written = source.text(from: argument.valueStart, to: argument.valueEnd)
            throw refuse("`\(written)` is not a `Color(hex:)` literal, so replacing it would discard what it refers to.")
        }
        // Everything between the parentheses must itself be inert: labels,
        // separators and numbers. A nested call or a name means the value is
        // computed somewhere this cannot see.
        for token in tokens[2..<(tokens.count - 1)] {
            switch token.kind {
            case .number, .punctuation:
                continue
            case .identifier where isColorArgumentLabel(source.text(of: token)):
                continue
            default:
                throw refuse("This colour is built from an expression rather than written out, so it is not rewritten.")
            }
        }
    }

    private static func isColorArgumentLabel(_ text: String) -> Bool {
        text == "hex" || text == "alpha" || text == "red" || text == "green" || text == "blue"
    }

    /// Compares what the panel showed with what is in the source.
    ///
    /// The snapshot formats a double as `28.0` and the source may say `28`, so
    /// numbers are compared numerically; everything else exactly, after
    /// stripping a string literal's quotes.
    private static func matches(actual: String, expected: String) -> Bool {
        if actual == expected { return true }
        if let a = Double(actual), let e = Double(expected) { return a == e }
        let unquoted = actual.hasPrefix("\"") && actual.hasSuffix("\"") && actual.count >= 2
            ? String(actual.dropFirst().dropLast())
            : actual
        if unquoted == expected { return true }
        if let a = Double(unquoted), let e = Double(expected) { return a == e }
        // `.bold` in source against `bold` from the snapshot.
        if actual.hasPrefix("."), String(actual.dropFirst()) == expected { return true }
        return false
    }

    // MARK: - Inserting a call that was never written

    private static func insertingModifier(
        _ name: String,
        _ setter: SwiftPropertySetter,
        value: String,
        chain: LocatedChain,
        in source: SwiftSource,
        edit: Edit
    ) throws -> String {
        // Nothing was written, so there is nothing to compare against. An
        // expectation that names a value here is itself a sign of a stale
        // snapshot.
        // Built as label/value pairs rather than strings, so ordering never has
        // to be recovered by looking for a colon -- `Color(hex: 0x...)` has one
        // and is positional.
        var arguments: [(label: String?, value: String)] = [(setter.label, value)]

        for sibling in setter.siblings {
            guard let siblingValue = edit.siblingValues[sibling] else {
                throw Diagnostic(
                    code: "CID0643",
                    summary: "not enough information to write .\(name)",
                    reason: "Writing `.\(name)` needs its `\(sibling)` argument as well, and none was supplied.",
                    remedy: "Reload the dashboard and try the edit again."
                )
            }
            let siblingLabel: String? = sibling == positionalSiblingKey ? nil : sibling
            arguments.append((siblingLabel, siblingValue))
        }

        // Swift wants the positional argument first; only
        // `.background(_:pressed:)` mixes the two today.
        let ordered = arguments.filter { $0.label == nil } + arguments.filter { $0.label != nil }
        let rendered = ordered.map { argument -> String in
            guard let label = argument.label else { return argument.value }
            return "\(label): \(argument.value)"
        }

        let call = ".\(name)(\(rendered.joined(separator: ", ")))"
        return splice(call, at: chain.end, chain: chain, in: source)
    }

    /// How a *positional* sibling is named in the setter table. A dictionary
    /// needs a key and a positional argument has no label, so it gets one that
    /// cannot collide with a real Swift label.
    static let positionalSiblingKey = "_0"

    private static func splice(
        _ call: String,
        at offset: Int,
        chain: LocatedChain,
        in source: SwiftSource
    ) -> String {
        var characters = source.characters
        let column = source.column(at: offset)
        let insertion: String

        if chain.isSingleLine && column + call.count <= 110 {
            // Short and already on one line: keep it there, so the diff is one
            // line changed rather than one line split into three.
            insertion = call
        } else {
            let unit = chain.indent.contains("\t") ? "\t" : "    "
            insertion = "\n" + chain.indent + unit + call
        }
        characters.insert(contentsOf: Array(insertion), at: offset)
        return String(characters)
    }

    private static func insertingInitializerArgument(
        _ setter: SwiftPropertySetter,
        value: String,
        chain: LocatedChain,
        arguments: SwiftArgumentList?,
        in source: SwiftSource,
        edit: Edit
    ) throws -> String {
        guard let label = setter.label, !setter.initializerOrder.isEmpty else {
            throw Diagnostic(
                code: "CID0639",
                summary: "'\(edit.property)' is not written here and cannot be inserted",
                location: DiagnosticLocation(file: "<source>", line: edit.line),
                reason: "The editor only inserts initializer arguments whose declaration order it knows.",
                remedy: "Add the argument in the source by hand."
            )
        }
        let text = "\(label): \(value)"
        var characters = source.characters

        guard let arguments else {
            // No argument list at all: `VStack { ... }` becomes
            // `VStack(spacing: 24) { ... }`.
            let headEnd = chain.headStart + chain.head.count
            characters.insert(contentsOf: Array("(\(text))"), at: headEnd)
            return String(characters)
        }

        guard arguments.isSingleLine else {
            throw Diagnostic(
                code: "CID0639",
                summary: "'\(edit.property)' cannot be inserted into a multi-line argument list",
                location: DiagnosticLocation(file: "<source>", line: edit.line),
                reason: "Reformatting a multi-line argument list risks more of the file than the edit is worth.",
                remedy: "Add `\(text)` to the call in the source by hand."
            )
        }

        // Swift requires declaration order, so the new argument goes before the
        // first existing one that is declared after it.
        guard let position = setter.initializerOrder.firstIndex(of: label) else {
            throw SwiftExpressionLocator.cannotDelimit(line: edit.line)
        }
        let successor = arguments.arguments.first { argument in
            guard let existing = argument.label,
                  let existingPosition = setter.initializerOrder.firstIndex(of: existing) else { return false }
            return existingPosition > position
        }

        if let successor {
            characters.insert(contentsOf: Array("\(text), "), at: successor.start)
        } else if arguments.arguments.isEmpty {
            characters.insert(contentsOf: Array(text), at: arguments.openParen + 1)
        } else {
            characters.insert(contentsOf: Array(", \(text)"), at: arguments.closeParen)
        }
        return String(characters)
    }

    private static func invertedBool(_ value: String) throws -> String {
        switch value {
        case "true": return "false"
        case "false": return "true"
        default:
            throw Diagnostic(
                code: "CID0641",
                summary: "'\(value)' is not a boolean",
                reason: "This property is written as `.disabled(_:)`, which takes true or false.",
                remedy: "Send true or false."
            )
        }
    }
}
