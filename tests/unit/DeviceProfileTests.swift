//  Unit tests for device profiles.

import XCTest

@testable import CiderCore
@testable import CiderDeviceProfiles

final class DeviceProfileTests: XCTestCase {

    func testPhoneStandardMatchesItsDocumentedValues() {
        // These numbers are Cider development defaults, not a reproduction of
        // any vendor's hardware. The test pins them so a change is deliberate.
        let profile = DeviceProfileRegistry.phoneStandard

        XCTAssertEqual(profile.name, "phone-standard")
        XCTAssertEqual(profile.logicalWidth, 390)
        XCTAssertEqual(profile.logicalHeight, 844)
        XCTAssertEqual(profile.scale, 1)
        XCTAssertEqual(profile.orientation, .portrait)
        XCTAssertEqual(profile.safeArea, EdgeInsets(top: 47, left: 0, bottom: 34, right: 0))
    }

    func testProfileNamesAvoidVendorBranding() {
        // docs/07-legal-distribution-boundaries.md section 5.
        let forbidden = ["iphone", "ipad", "ios", "apple"]
        for profile in DeviceProfileRegistry.all {
            let name = profile.name.lowercased()
            for term in forbidden {
                XCTAssertFalse(name.contains(term), "profile `\(profile.name)` uses vendor branding")
            }
        }
    }

    func testSafeAreaBounds() {
        let bounds = DeviceProfileRegistry.phoneStandard.safeAreaBounds
        XCTAssertEqual(bounds.minY, 47)
        XCTAssertEqual(bounds.height, 844 - 47 - 34)
    }

    func testPixelSizeAppliesScale() {
        var profile = DeviceProfileRegistry.phoneStandard
        XCTAssertEqual(profile.pixelSize.width, 390)

        profile.scale = 2
        XCTAssertEqual(profile.pixelSize.width, 780)
        XCTAssertEqual(profile.pixelSize.height, 1688)
    }

    func testUnknownProfileListsWhatExists() {
        XCTAssertThrowsError(try DeviceProfileRegistry.resolve("phone-enormous")) { error in
            let diagnostic = error as? Diagnostic
            XCTAssertEqual(diagnostic?.code, "CID0201")
            XCTAssertTrue(diagnostic?.remedy?.contains("phone-standard") ?? false)
        }
    }
}
