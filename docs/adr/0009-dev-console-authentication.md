# 0009. Dev console authentication

## Status

Accepted — 2026-08-29.

## Context

`cider dev` serves its dashboard from a hand-rolled HTTP server bound to
`127.0.0.1`. Until now that was the entire security model, and the Stage 4
console already had two routes that change state: `POST /api/sandbox/reset`,
which deletes the application's sandbox, and `POST /api/proxy/fetch`, which
makes the console fetch an arbitrary URL.

**Loopback is not a security boundary.** Any web page the developer happens to
have open can `fetch()` a POST at `http://127.0.0.1:5757`, and the browser
delivers it. CORS stops the page *reading* the reply; it does not stop the
request arriving or taking effect. The existing
`Access-Control-Allow-Origin` header protects the response, not the side effect.

ADR 0008 adds a route that writes a Swift file which `cider dev` then rebuilds
and runs. On an unauthenticated loopback port, that is remote code execution on
the developer's machine, reachable from any tab.

## Decision

**A per-run session token on every mutating route.** 32 random bytes, hex
encoded, minted in `DevSession` and never persisted, so a token cannot outlive
the session it belongs to. Sent as `X-Cider-Dev-Token`.

**The token is served only to the console's own origin**, at
`GET /api/dev/session`, guarded by the same origin check as the mutating routes.

**A custom header is itself part of the defence.** A cross-origin request
carrying one is not a CORS "simple request", so the browser must preflight it —
and the preflight is answered only for this origin.

**`Origin` and `Host` are validated** against `127.0.0.1:<port>` and
`localhost:<port>` on every mutating route and on the token route. A request
with no `Origin` can still carry a foreign `Host`, and a `Host` that is not this
dashboard means the request was not aimed here.

**This applies retroactively.** `/api/sandbox/reset` and `/api/proxy/fetch` are
gated too. They were reachable before this change.

**The running application is authenticated, not exempted.** `CiderHTTP`'s
capture POST carries the same token, delivered through a new
`request-capture.token` launch-descriptor field.

**Request bodies are read to `Content-Length` and capped at 1 MiB.** Not
security theatre — the server previously did a single `read()`, so a client that
split its head and body across writes could have its POST body silently
truncated to nothing. The cap keeps one connection from holding the
single-threaded accept loop.

## Alternatives Considered

**Unix domain socket instead of TCP.** Genuinely unreachable from a browser, and
the cleanest answer to this threat. Rejected for now because the dashboard *is* a
browser page, so the socket would need an HTTP bridge anyway; worth revisiting if
the console ever grows a native client.

**Checking `Origin` alone.** Simpler. Rejected because `Origin` is absent on
same-origin GETs and on non-browser clients, so it cannot be required, and a
check that can be skipped by omitting a header is not a check.

**A token in the URL rather than a header.** Would avoid the preflight. Rejected
because it lands in shell history, logs and `Referer`, and it loses the
preflight, which is a second independent barrier.

**Leaving `/api/proxy/fetch` open, as before.** Rejected: it is an SSRF vector
from any page, and it is now the one route a non-browser client uses, so
authenticating it costs one descriptor field.

## Consequences

- The dashboard must fetch its token before it can act; a reload re-fetches.
- A stale browser tab from a previous `cider dev` run holds a dead token and is
  refused with `CID0631` rather than acting on the new session.
- Any future mutating route is gated by default: the check is on the method, not
  on a list of paths.
- This does not make the console safe to expose beyond loopback, and nothing
  here should be read as an invitation to. It closes the gap between "bound to
  loopback" and "actually only reachable by its own dashboard".
