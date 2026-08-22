//  A bitmap image.
//
//  There is no asset pipeline or image decoder yet -- see `ImageSource`'s doc
//  comment. `Image` displays already-decoded pixels; loading one from a file
//  or an asset catalog is future work, out of Stage 2's scope.

import CiderCore
import CiderUITree

public struct Image: CiderView {
    public typealias Body = Never

    private let source: ImageSource

    public init(_ source: ImageSource) {
        self.source = source
    }

    public var body: Never { fatalError("Image has no body") }

    public func _lower(into context: LoweringContext) {
        let id = context.reserveIdentity()
        context.emit(.image(ImageNode(id: id, source: source)))
    }
}
