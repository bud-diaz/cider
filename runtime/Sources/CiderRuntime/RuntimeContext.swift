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

    /// This application's isolated data area, prepared by `cider run` before
    /// launch. `nil` when the binary was started without going through the
    /// CLI, in which case no sandbox root was prepared. Nothing reads from or
    /// writes into it yet -- storage is Stage 3 -- but the isolation itself
    /// exists now, per docs/03-technical-architecture.md section 8.
    public let sandbox: SandboxPaths?

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
        sandbox: SandboxPaths?,
        appID: String,
        appName: String,
        log: Logger,
        invalidationTarget: InvalidationTarget
    ) {
        self.deviceProfile = deviceProfile
        self.permissions = permissions
        self.sandbox = sandbox
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
