//  The source rewriter, exercised offline.
//
//  This is the component that can damage a developer's work, so it is tested
//  the way that risk deserves: every case asserts the *whole* resulting file,
//  not just the changed line, and every refusal asserts that the file came back
//  byte-identical. A rewriter that silently reflows the rest of a file would
//  pass a test that only looked at one line.

import XCTest

@testable import CiderCore
@testable import CiderProject

final class SwiftSourceEditorTests: XCTestCase {

    // MARK: - Rewriting a value that is already written

    func testRewritesAModifierArgumentAndLeavesTheRestOfTheFileAlone() throws {
        let source = """
            VStack(spacing: 24) {
                Text("Cider Demo")
                    .font(size: 28, weight: .bold)
            }
            """
        let result = try apply(source, head: "Text", property: "fontSize", value: "36")
        XCTAssertEqual(result, """
            VStack(spacing: 24) {
                Text("Cider Demo")
                    .font(size: 36, weight: .bold)
            }
            """)
    }

    func testRewritesAnEnumCaseArgument() throws {
        let source = #"Text("Title").font(size: 28, weight: .bold)"#
        let result = try apply(source, head: "Text", property: "fontWeight", value: ".regular")
        XCTAssertEqual(result, #"Text("Title").font(size: 28, weight: .regular)"#)
    }

    func testRewritesAStringInitializerArgument() throws {
        let source = #"Text("Cider Demo").font(size: 28)"#
        let result = try apply(source, head: "Text", property: "text", value: #""Hello""#)
        XCTAssertEqual(result, #"Text("Hello").font(size: 28)"#)
    }

    func testRewritesAnInitializerArgumentThatWasWritten() throws {
        let source = "VStack(spacing: 24, alignment: .leading) {\n    Text(\"x\")\n}"
        let result = try apply(source, head: "VStack", property: "spacing", value: "32")
        XCTAssertEqual(result, "VStack(spacing: 32, alignment: .leading) {\n    Text(\"x\")\n}")
    }

    /// A colour is never a bare token, so it gets its own proof. Without this,
    /// the property an editor is most often asked to change would be the one it
    /// could never write.
    func testRewritesAColorCall() throws {
        let source = #"Text("x").foregroundColor(Color(hex: 0xFF0000))"#
        let result = try apply(
            source, head: "Text", property: "color", value: "Color(hex: 0x00FF00)"
        )
        XCTAssertEqual(result, #"Text("x").foregroundColor(Color(hex: 0x00FF00))"#)
    }

    /// The panel shows `isEnabled`; the source says `.disabled`. The rewriter
    /// owns the inversion so the two never disagree.
    func testInvertsIsEnabledIntoDisabled() throws {
        let source = "Button(\"Go\") {}.disabled(false)"
        let result = try apply(source, head: "Button", property: "isEnabled", value: "false")
        XCTAssertEqual(result, "Button(\"Go\") {}.disabled(true)")
    }

    /// Copy-and-overwrite means the last call in a chain is the one whose value
    /// the node carries, so that is the one an edit has to change.
    func testRewritesTheLastMatchingModifierInAChain() throws {
        let source = #"Text("x").font(size: 10).font(size: 20)"#
        let result = try apply(source, head: "Text", property: "fontSize", value: "30")
        XCTAssertEqual(result, #"Text("x").font(size: 10).font(size: 30)"#)
    }

    // MARK: - Inserting a call that was never written

    func testInsertsAModifierInlineWhenTheChainIsOnOneLine() throws {
        let source = #"Text("Notes").font(size: 28, weight: .bold)"#
        let result = try apply(
            source, head: "Text", property: "color", value: "Color(hex: 0xE89A2F)"
        )
        XCTAssertEqual(
            result,
            #"Text("Notes").font(size: 28, weight: .bold).foregroundColor(Color(hex: 0xE89A2F))"#
        )
    }

    func testInsertsAModifierOnItsOwnLineWhenTheChainIsAlreadyMultiLine() throws {
        let source = """
            VStack {
                Text("Cider Demo")
                    .font(size: 28, weight: .bold)
            }
            """
        let result = try apply(
            source, head: "Text", property: "color", value: "Color(hex: 0xE89A2F)"
        )
        XCTAssertEqual(result, """
            VStack {
                Text("Cider Demo")
                    .font(size: 28, weight: .bold)
                    .foregroundColor(Color(hex: 0xE89A2F))
            }
            """)
    }

    /// The insertion point is past the trailing closure, not past the argument
    /// list -- putting it after `)` would land inside the button's action.
    func testInsertsAfterATrailingClosure() throws {
        let source = """
            Button("Press Me") {
                count += 1
            }
            """
        let result = try apply(source, head: "Button", property: "cornerRadius", value: "12")
        XCTAssertEqual(result, """
            Button("Press Me") {
                count += 1
            }
                .cornerRadius(12)
            """)
    }

    /// A modifier that takes more than one argument has to be written whole,
    /// which means the caller must supply the values it is not changing.
    func testInsertsAMultiArgumentModifierUsingSuppliedSiblings() throws {
        let source = "Button(\"Go\") {}"
        var edit = try makeEdit(source, head: "Button", property: "paddingHorizontal", value: "30")
        edit.siblingValues = ["vertical": "14"]
        let result = try SwiftSourceEditor.apply(edit, to: source)
        XCTAssertEqual(result, "Button(\"Go\") {}.padding(horizontal: 30, vertical: 14)")
    }

    func testInsertsAPositionalAndLabelledPairInDeclarationOrder() throws {
        let source = "Button(\"Go\") {}"
        var edit = try makeEdit(
            source, head: "Button", property: "backgroundColor", value: "Color(hex: 0x2040C0)"
        )
        // `backgroundColor` is itself the positional argument here, so the
        // sibling to supply is the labelled one.
        edit.siblingValues = ["pressed": "Color(hex: 0x3050D0)"]
        let result = try SwiftSourceEditor.apply(edit, to: source)
        XCTAssertEqual(
            result,
            "Button(\"Go\") {}.background(Color(hex: 0x2040C0), pressed: Color(hex: 0x3050D0))"
        )
    }

    func testSynthesisesAnArgumentListWhenTheCallHasOnlyATrailingClosure() throws {
        let source = "VStack {\n    Text(\"x\")\n}"
        let result = try apply(source, head: "VStack", property: "spacing", value: "24")
        XCTAssertEqual(result, "VStack(spacing: 24) {\n    Text(\"x\")\n}")
    }

    func testInsertsAnInitializerArgumentInDeclarationOrder() throws {
        let source = "List(width: 100, height: 100) {\n    Text(\"row\")\n}"
        let result = try apply(source, head: "List", property: "spacing", value: "4")
        XCTAssertEqual(result, "List(width: 100, height: 100, spacing: 4) {\n    Text(\"row\")\n}")
    }

    func testInsertsAnInitializerArgumentBeforeALaterOne() throws {
        let source = "VStack(alignment: .leading) {\n    Text(\"x\")\n}"
        let result = try apply(source, head: "VStack", property: "spacing", value: "24")
        XCTAssertEqual(result, "VStack(spacing: 24, alignment: .leading) {\n    Text(\"x\")\n}")
    }

    // MARK: - Refusals
    //
    // Every one of these asserts the file is returned untouched. A rewriter
    // that declines but has already written half an edit is worse than one that
    // never tried.

    func testRefusesAnInterpolatedString() throws {
        let source = #"Text("Count: \(count)")"#
        try expectRefusal("CID0637", source, head: "Text", property: "text", value: #""Hello""#)
    }

    func testRefusesAnExpression() throws {
        let source = #"Text("x").font(size: base * 2)"#
        try expectRefusal("CID0636", source, head: "Text", property: "fontSize", value: "36")
    }

    func testRefusesANamedConstant() throws {
        let source = #"Text("x").font(size: Theme.bodyFontSize)"#
        try expectRefusal("CID0636", source, head: "Text", property: "fontSize", value: "36")
    }

    func testRefusesANamedColour() throws {
        let source = #"Text("x").foregroundColor(Theme.ciderAmber)"#
        try expectRefusal(
            "CID0636", source, head: "Text", property: "color", value: "Color(hex: 0x00FF00)"
        )
    }

    /// A comment beside a value is outside the span being replaced, so it
    /// survives. Only a comment *inside* the span -- which needs a multi-token
    /// shape like a colour call -- forces a refusal.
    func testPreservesACommentSittingBesideTheValue() throws {
        let source = #"Text("x").font(size: /* twice the body size */ 34)"#
        let result = try apply(source, head: "Text", property: "fontSize", value: "36")
        XCTAssertEqual(result, #"Text("x").font(size: /* twice the body size */ 36)"#)
    }

    func testRefusesAValueWithACommentInsideIt() throws {
        let source = #"Text("x").foregroundColor(Color(hex: /* brand */ 0xFF0000))"#
        try expectRefusal(
            "CID0636", source, head: "Text", property: "color", value: "Color(hex: 0x00FF00)"
        )
    }

    /// The compare-and-swap: what the panel showed has to still be what the
    /// file says, or the snapshot is stale and the edit is aimed at the past.
    func testRefusesWhenTheSourceNoLongerHoldsTheExpectedValue() throws {
        let source = #"Text("x").font(size: 28)"#
        var edit = try makeEdit(source, head: "Text", property: "fontSize", value: "36")
        edit.expectedCurrentValue = "17.0"
        XCTAssertThrowsError(try SwiftSourceEditor.apply(edit, to: source)) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0634")
        }
    }

    func testAcceptsAnExpectedValueFormattedAsADouble() throws {
        // The snapshot formats every double with one decimal; the source will
        // usually say `28`. Comparing as text alone would refuse every edit.
        let source = #"Text("x").font(size: 28)"#
        var edit = try makeEdit(source, head: "Text", property: "fontSize", value: "36")
        edit.expectedCurrentValue = "28.0"
        XCTAssertEqual(try SwiftSourceEditor.apply(edit, to: source), #"Text("x").font(size: 36)"#)
    }

    func testRefusesWhenTheAnchorNoLongerNamesTheExpectedView() throws {
        let source = #"Button("x") {}"#
        let edit = SwiftSourceEditor.Edit(
            head: "Text",
            line: 1,
            column: 1,
            property: "fontSize",
            newValue: "36"
        )
        XCTAssertThrowsError(try SwiftSourceEditor.apply(edit, to: source)) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0635")
        }
    }

    func testRefusesAPropertyThatHasNoSourceForm() throws {
        let source = #"TextField($draft, width: 280)"#
        try expectRefusal("CID0640", source, head: "TextField", property: "text", value: #""x""#)
    }

    func testRefusesToReformatAMultiLineArgumentList() throws {
        let source = """
            List(
                width: 100,
                height: 100
            ) {
                Text("row")
            }
            """
        try expectRefusal("CID0639", source, head: "List", property: "spacing", value: "4")
    }

    func testRefusesAnUnterminatedStringRatherThanGuessing() throws {
        let source = "Text(\"unterminated).font(size: 28)"
        let edit = SwiftSourceEditor.Edit(
            head: "Text", line: 1, column: 1, property: "fontSize", newValue: "36"
        )
        XCTAssertThrowsError(try SwiftSourceEditor.apply(edit, to: source)) { error in
            XCTAssertEqual((error as? Diagnostic)?.code, "CID0639")
        }
    }

    func testRefusesANonBooleanForAnInvertedProperty() throws {
        let source = "Button(\"Go\") {}.disabled(false)"
        try expectRefusal("CID0641", source, head: "Button", property: "isEnabled", value: "yes")
    }

    // MARK: - Scanning
    //
    // The scanner is where "this is a string, not code" is decided, so the
    // constructs that make that hard get their own coverage.

    func testScannerHandlesNestedBlockComments() throws {
        let source = try SwiftSource("/* outer /* inner */ still comment */ Text(\"x\")")
        XCTAssertEqual(source.code.first.map(source.text(of:)), "Text")
    }

    func testScannerHandlesRawStringsWhereBackslashQuoteIsNotAnEscape() throws {
        let source = try SwiftSource(##"Text(#"a\"b"#)"##)
        let strings = source.tokens.filter { if case .string = $0.kind { return true } else { return false } }
        XCTAssertEqual(strings.count, 1)
        XCTAssertEqual(strings.first.map(source.text(of:)), ##"#"a\"b"#"##)
    }

    func testScannerHandlesInterpolationContainingAStringContainingAParen() throws {
        let source = try SwiftSource(#"Text("a\(f(")("))b")"#)
        let strings = source.tokens.filter { if case .string = $0.kind { return true } else { return false } }
        XCTAssertEqual(strings.count, 1, "the whole literal is one token, interpolation included")
        if case .string(let interpolated, _, _) = strings[0].kind {
            XCTAssertTrue(interpolated)
        } else {
            XCTFail("expected a string token")
        }
    }

    func testScannerHandlesMultilineStrings() throws {
        let source = try SwiftSource("let a = \"\"\"\nline \"quoted\" here\n\"\"\"\nText(\"x\")")
        let strings = source.tokens.filter { if case .string = $0.kind { return true } else { return false } }
        XCTAssertEqual(strings.count, 2, "the multiline literal, then Text's argument")
        if case .string(_, _, let multiline) = strings[0].kind {
            XCTAssertTrue(multiline)
        } else {
            XCTFail("expected a multiline string token")
        }
    }

    /// Two views on one line have to be told apart, which is the whole reason
    /// an origin carries a column.
    func testLocatorPicksTheViewAtTheGivenColumn() throws {
        let source = #"VStack { Text("left"); Text("right") }"#
        let result = try apply(source, head: "Text", property: "text", value: #""edited""#, occurrence: 2)
        XCTAssertEqual(result, #"VStack { Text("left"); Text("edited") }"#)
    }

    // MARK: - Helpers

    /// Finds the 1-based line and column of an occurrence of `needle`, the way
    /// the compiler would report it for a call written there.
    private func position(of needle: String, in source: String, occurrence: Int) -> (line: Int, column: Int) {
        var line = 1
        var column = 1
        var seen = 0
        let characters = Array(source)
        let target = Array(needle)

        for index in characters.indices {
            if index + target.count <= characters.count,
               Array(characters[index..<index + target.count]) == target {
                seen += 1
                if seen == occurrence { return (line, column) }
            }
            if characters[index] == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }
        return (1, 1)
    }

    private func makeEdit(
        _ source: String,
        head: String,
        property: String,
        value: String,
        occurrence: Int = 1
    ) throws -> SwiftSourceEditor.Edit {
        let found = position(of: head, in: source, occurrence: occurrence)
        return SwiftSourceEditor.Edit(
            head: head,
            line: found.line,
            column: found.column,
            property: property,
            newValue: value
        )
    }

    private func apply(
        _ source: String,
        head: String,
        property: String,
        value: String,
        occurrence: Int = 1
    ) throws -> String {
        try SwiftSourceEditor.apply(
            makeEdit(source, head: head, property: property, value: value, occurrence: occurrence),
            to: source
        )
    }

    private func expectRefusal(
        _ code: String,
        _ source: String,
        head: String,
        property: String,
        value: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let edit = try makeEdit(source, head: head, property: property, value: value)
        var produced: String?
        do {
            produced = try SwiftSourceEditor.apply(edit, to: source)
        } catch let diagnostic as Diagnostic {
            XCTAssertEqual(diagnostic.code, code, file: file, line: line)
            return
        }
        XCTFail(
            "expected \(code); the edit succeeded and produced \(produced ?? "nothing")",
            file: file,
            line: line
        )
    }
}
