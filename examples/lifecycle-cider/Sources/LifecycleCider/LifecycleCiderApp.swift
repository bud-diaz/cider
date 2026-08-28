//  A narrow reference application for the app-level lifecycle hooks added
//  alongside this app: CiderApp.didEnterBackground()/didEnterForeground().
//  ApplicationRuntime.enterBackground()/enterForeground() (Stage 3) already
//  simulate the transition and are covered by LIFE-BG-001, but nothing
//  previously called into application code when they fired. See
//  docs/known-issues.md: nothing in `cider run` itself drives these
//  transitions yet -- only test/harness code (and LIFE-BG-002) can, so this
//  app's log will only ever show "Launched" outside of a test.

import CiderUI

@main
struct LifecycleCiderApp: CiderApp {
    @CiderState private var log: [String] = ["Launched"]

    var body: some CiderView {
        VStack(spacing: 18) {
            Text("Lifecycle").font(size: 28, weight: .bold)
            Text(log.joined(separator: "\n")).font(size: 14)
        }
    }

    func didEnterBackground() {
        log.append("Entered background")
    }

    func didEnterForeground() {
        log.append("Entered foreground")
    }
}
