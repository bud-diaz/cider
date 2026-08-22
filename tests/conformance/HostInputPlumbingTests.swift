//  Smoke tests for the scroll/keyboard event plumbing landed ahead of any
//  node kind that consumes it (Stage 2's scroll view, list and text field).
//
//  There is no application-facing behaviour to give these a conformance ID
//  yet -- nothing on screen changes -- so unlike the tests in
//  ConformanceTests.swift these aren't numbered. What they pin down is
//  narrower: the runtime accepts these events without crashing, and without
//  side effects on state nothing has asked it to change yet.

import XCTest

import CiderHost

final class HostInputPlumbingTests: XCTestCase {

    func testScrollEventsAreAcceptedAndChangeNothingObservable() throws {
        let harness = try ConformanceHarness(CounterApp())
        try harness.launch()

        let framesBefore = harness.backend.presentedFrames.count
        try harness.deliver([.scroll(deltaX: 0, deltaY: 1)])

        XCTAssertEqual(harness.runtime.state, .foreground)
        XCTAssertEqual(
            harness.backend.presentedFrames.count, framesBefore,
            "nothing consumes scroll yet, so it must not trigger a redraw"
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
