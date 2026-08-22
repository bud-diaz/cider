//  The built-in device profiles.
//
//  Profile names are generic by policy, not by accident: Cider must not imply
//  that it reproduces any particular vendor's hardware. See
//  docs/07-legal-distribution-boundaries.md section 5.

import CiderCore

public enum DeviceProfileRegistry {

    /// A plausible modern phone in portrait.
    ///
    /// The numbers are Cider development defaults. They were chosen to be a
    /// realistic size to lay out against -- not to match any specific device, and
    /// not as a claim that an application laid out here will be laid out
    /// identically anywhere else.
    ///
    /// The scale is 1 for now. Layout and rasterization already carry scale
    /// through, so raising it is a profile change rather than a code change, but
    /// nothing has exercised a non-unit scale end to end yet.
    public static let phoneStandard = DeviceProfile(
        name: "phone-standard",
        logicalWidth: 390,
        logicalHeight: 844,
        scale: 1,
        orientation: .portrait,
        safeArea: EdgeInsets(top: 47, left: 0, bottom: 34, right: 0)
    )

    public static let all: [DeviceProfile] = [phoneStandard]

    public static let defaultProfileName = phoneStandard.name

    public static func profile(named name: String) -> DeviceProfile? {
        all.first { $0.name == name }
    }

    /// Looks a profile up, or produces a diagnostic listing what does exist.
    public static func resolve(_ name: String) throws -> DeviceProfile {
        if let profile = profile(named: name) {
            return profile
        }
        let available = all.map(\.name).sorted().joined(separator: "\n    ")
        throw Diagnostic(
            code: "CID0201",
            summary: "unknown device profile '\(name)'",
            reason: "Cider has no device profile by that name.",
            remedy: """
                Available profiles:

                    \(available)

                Set one in Cider.yaml under `runtime.device`, or pass --device.
                """
        )
    }
}
