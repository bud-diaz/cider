//  Smoke tests for host input events that reach the runtime with no effect
//  when nothing on screen consumes them.
//
//  Scroll has a real consumer since B4 (ScrollView) -- see UI-SCROLL-001 in
//  ConformanceTests.swift for its actual behaviour. Keyboard events still
//  have none (no node kind accepts focus until B5's text field), so those
//  cases here aren't numbered: there's no application-facing behaviour yet
//  to certify.

import XCTest

import CiderCore
import CiderHost

final class HostInputPlumbingTests: XCTestCase {

    func testScrollOverAnAppWithNoScrollViewChangesNothing() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let framesBefore = harness.backend.presentedFrames.count
        try harness.deliver([.scroll(location: Point(x: 10, y: 10), deltaX: 0, deltaY: 1)])

        XCTAssertEqual(harness.runtime.state, .foreground)
        XCTAssertEqual(
            harness.backend.presentedFrames.count, framesBefore,
            "nothing scrollable is on screen, so the scroll must not trigger a redraw"
        )
    }

    func testKeyEventsAreAcceptedWithNoFocusedNode() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        XCTAssertNil(harness.runtime.currentFocusedNode, "nothing can set focus yet")

        try harness.deliver([.keyDown(keyCode: 65)])
        try harness.deliver([.keyUp(keyCode: 65)])
        try harness.deliver([.textInput("a")])

        XCTAssertEqual(harness.runtime.state, .foreground)
        XCTAssertNil(harness.runtime.currentFocusedNode)
    }
}
