//  Whitespace trimming for the line-oriented text formats Cider parses.

public extension StringProtocol {
    /// Trims spaces, tabs, carriage returns and newlines from both ends.
    ///
    /// Deliberately not Unicode-aware. Manifests and launch descriptors are
    /// ASCII by design, and a Unicode-aware trim would quietly accept a
    /// non-breaking space where a developer meant a space -- turning a typo that
    /// should be reported into a value that mysteriously does not match.
    func trimmingASCIIWhitespace() -> String {
        var view = Substring(self)
        while let first = view.first, Self.isASCIIWhitespace(first) {
            view = view.dropFirst()
        }
        while let last = view.last, Self.isASCIIWhitespace(last) {
            view = view.dropLast()
        }
        return String(view)
    }

    private static func isASCIIWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character == "\r" || character == "\n"
    }
}
