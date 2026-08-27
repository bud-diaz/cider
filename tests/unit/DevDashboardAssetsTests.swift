import XCTest

@testable import CiderProject

final class DevDashboardAssetsTests: XCTestCase {
    func testDashboardAssetsMatchLockedSnapshots() throws {
        XCTAssertEqual(DevDashboardAssets.indexHTML.trimmedForSnapshot, try snapshot(named: "index.html"))
        XCTAssertEqual(DevDashboardAssets.appCSS.trimmedForSnapshot, try snapshot(named: "app.css"))
        XCTAssertEqual(DevDashboardAssets.appJS.trimmedForSnapshot, try snapshot(named: "app.js"))
    }

    func testDashboardCSSUsesLockedDevToolDesignTokens() {
        let css = DevDashboardAssets.appCSS
        let requiredTokens = [
            "--bg-page: #09090b;",
            "--bg-panel: #111115;",
            "--bg-panel-deep: #0d0d0f;",
            "--bg-panel-hover: #15151a;",
            "--border-default: rgba(39, 39, 42, 0.78);",
            "--border-hover: #3f3f46;",
            "--text-primary: #fafafa;",
            "--text-body: #a1a1aa;",
            "--text-muted: #71717a;",
            "--text-dim: #52525b;",
            "--accent-rose: #fb7185;",
            "--accent-amber: #fbbf24;",
            "--accent-emerald: #34d399;",
            "--selection: rgba(244, 63, 94, 0.3);",
        ]

        for token in requiredTokens {
            XCTAssertTrue(css.contains(token), "Missing locked design token: \(token)")
        }

        XCTAssertFalse(css.contains("transition: all"), "Dashboard interactions must name transition properties explicitly.")
        XCTAssertFalse(css.contains("ease-in"), "Cider dashboard motion should stay fast/responsive, not ease-in sluggish.")
    }

    func testDashboardEncodesDevToolChromeAndInteractionRules() {
        let html = DevDashboardAssets.indexHTML
        let css = DevDashboardAssets.appCSS
        let js = DevDashboardAssets.appJS
        let combined = [html, css, js].joined(separator: "\n")
        let lowercased = combined.lowercased()

        XCTAssertTrue(html.contains("class=\"ide-titlebar\""))
        XCTAssertTrue(html.contains("cider.dev/session.config"))
        XCTAssertTrue(html.contains("class=\"resource-sidebar\""))
        XCTAssertTrue(html.contains("class=\"editor-window focused-panel\""))
        XCTAssertTrue(html.contains("aria-selected=\"true\""))
        XCTAssertTrue(css.contains("button:active { transform: scale(0.97); }"))
        XCTAssertTrue(css.contains("@media (hover: hover) and (pointer: fine)"))
        XCTAssertTrue(css.contains("@media (prefers-reduced-motion: reduce)"))
        XCTAssertTrue(css.contains(".severity-success"))
        XCTAssertTrue(css.contains(".severity-warning"))
        XCTAssertTrue(css.contains(".severity-error"))
        XCTAssertTrue(js.contains("setAttribute('aria-selected', String(isSelected))"))
        XCTAssertTrue(js.contains("function escapeHTML(value)"))
        XCTAssertTrue(js.contains("navigator.clipboard.writeText(text)"))
        XCTAssertTrue(js.contains("No runtime snapshot yet."))

        for forbidden in ["🍎", "apple logo", "xcode-blue", "penguin", "cider glass", "cider bottle"] {
            XCTAssertFalse(lowercased.contains(forbidden), "Dashboard should not drift into forbidden brand imagery: \(forbidden)")
        }
    }

    private func snapshot(named name: String) throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
        let snapshotURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots/DevDashboardAssets")
            .appendingPathComponent(name)
        return try String(contentsOf: snapshotURL, encoding: .utf8).trimmedForSnapshot
    }
}

private extension String {
    var trimmedForSnapshot: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
