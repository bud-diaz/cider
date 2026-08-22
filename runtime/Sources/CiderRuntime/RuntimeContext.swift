//  What an application can see and do from inside the runtime.

import CiderCore

/// Handed to an application at launch.
///
/// Everything reachable from here is read-only except `invalidate()`. An
/// application cannot resize the device, change its own permissions or reach
/// the host window: those belong to the runtime, and letting an application
/// touch them would make its behaviour depend on load order.
public final class RuntimeContext {
    /// The virtual device the application is running on.
    public let deviceProfile: DeviceProfile

    /// Capabilities the manifest granted. Services check these before acting;
    /// no service uses them yet, since networking and storage are Stage 3.
    public let permissions: AppPermissions

    /// Identity from the manifest.
    public let appID: String
    public let appName: String

    /// A logger on the application channel, so developer output stays visually
    /// distinct from Cider's own.
    public let log: Logger

    /// Set by the runtime at construction. Weak, because the runtime owns the
    /// application which owns this context.
    private weak var invalidationTarget: InvalidationTarget?

    init(
        deviceProfile: DeviceProfile,
        permissions: AppPermissions,
        appID: String,
        appName: String,
        log: Logger,
        invalidationTarget: InvalidationTarget
    ) {
        self.deviceProfile = deviceProfile
        self.permissions = permissions
        self.appID = appID
        self.appName = appName
        self.log = log
        self.invalidationTarget = invalidationTarget
    }

    /// Tells the runtime that application state changed and the frame it is
    /// showing is stale.
    ///
    /// Calling this more often than necessary costs nothing beyond a flag: the
    /// runtime coalesces invalidations and rebuilds at most once per frame.
    public func invalidate() {
        invalidationTarget?.setNeedsRebuild()
    }
}

/// The narrow slice of the runtime a context is allowed to poke.
protocol InvalidationTarget: AnyObject {
    func setNeedsRebuild()
}
