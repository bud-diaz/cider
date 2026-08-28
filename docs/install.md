# Installing Cider

Cider is still pre-alpha/alpha-track software. The supported install path for now is a source checkout build; packaged binaries are a Stage 5 release gate, not done yet.

## Supported host baseline

- Ubuntu 24.04 x86-64 today.
- Swift 6.0 or later.
- `build-essential`, `pkg-config`, `libx11-dev`, `libfreetype-dev`, `libfontconfig-dev`.
- An X display for `cider run`; `Xvfb` is acceptable for headless smoke tests.

```sh
sudo apt install build-essential pkg-config libx11-dev libfreetype-dev libfontconfig-dev xvfb
```

## Source install

```sh
git clone <repo-url> cider
cd cider
swift build
swift test
export PATH="$PWD/.build/debug:$PATH"
cider doctor
```

For release-mode local validation:

```sh
swift build --configuration release
swift test --configuration release
export PATH="$PWD/.build/release:$PATH"
```

## Creating an app from the checkout

```sh
cider init MyApp --app-id dev.example.myapp --path ./MyApp
cd MyApp
cider scan
cider run
```

`cider init` writes a SwiftPM path dependency to the active Cider checkout, so source-built templates can build without an already-published package.

## Packaging status

Not yet done for public alpha:

- signed binary archives;
- package-manager distribution;
- checksums and provenance notes;
- documented upgrade/uninstall path.

Track the gate with:

```sh
cider alpha-readiness
```
