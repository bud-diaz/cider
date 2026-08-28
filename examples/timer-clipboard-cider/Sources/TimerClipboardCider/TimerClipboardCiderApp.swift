//  A narrow reference application for CiderTimer, the one Stage 3 service
//  with conformance coverage (TIMER-001) but no reference-app coverage until
//  now. Paired with a minimal CiderClipboard touch (already exercised by
//  examples/notes-cider and examples/rest-client-cider) rather than adding a
//  second single-service app.
//
//  CiderTimer.after's callback runs on a background dispatch queue (see
//  compatibility/Sources/CiderUI/Services.swift), not the runtime's pump
//  loop -- mutating @CiderState from it, as below, is not synchronized with
//  rendering. That is Cider's actual behavior today, not something this app
//  papers over; see docs/known-issues.md.

import CiderUI

@main
struct TimerClipboardCiderApp: CiderApp {
    @CiderState private var status = "Idle"

    var body: some CiderView {
        VStack(spacing: 18) {
            Text("Timer + Clipboard").font(size: 28, weight: .bold)
            Button("Start Timer") {
                status = "Waiting..."
                // CiderTimer.after's closure is @Sendable, and CiderState
                // (unlike a plain struct) isn't Sendable -- capturing `self`
                // or `$status` needs an explicit opt-out. `nonisolated(unsafe)`
                // is the honest spelling of the same background-queue race
                // this file's header comment already documents, not a fix for it.
                nonisolated(unsafe) let box = $status
                CiderTimer.after(milliseconds: 500) {
                    box.wrappedValue = "Timer fired"
                }
            }
            Button("Copy Status") { CiderClipboard.copy(status) }
            Button("Paste") { status = CiderClipboard.text ?? status }
            Text(status).font(size: 14)
        }
    }
}
