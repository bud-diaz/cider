//  Idling between frames.
//
//  Deliberately not part of the host abstraction. Sleeping is not a platform
//  capability Cider needs to model -- every host Swift runs on has one, and
//  routing it through the backend would mean two implementations of `nanosleep`
//  and a protocol method that never varies.

#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

enum Sleep {
    static func milliseconds(_ value: Int) {
        guard value > 0 else { return }
        var request = timespec(
            tv_sec: value / 1000,
            tv_nsec: (value % 1000) * 1_000_000
        )
        var remaining = timespec()
        // A signal can cut the sleep short. Resume rather than return early, so
        // a stray signal cannot turn the idle loop into a busy loop.
        while nanosleep(&request, &remaining) == -1 && errno == EINTR {
            request = remaining
        }
    }
}
