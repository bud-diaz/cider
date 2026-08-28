//  Help text.

enum Usage {
    static let version = "0.1.0-pre-alpha"

    static let text = """
    cider \(version)

    An open compatibility runtime for developing iOS-style Swift applications on
    Linux. Cider does not emulate iPhone hardware and does not distribute iOS.

    USAGE
        cider <command> [options]

    COMMANDS
        doctor              Check that this machine can build and run Cider projects.
        scan                Report recognized unsupported APIs in project Swift source.
        compatibility-docs  Generate markdown from the compatibility registry.
        inspect             Print a project manifest/sandbox/scan summary.
        network             Show network permission and CiderHTTP URL call sites.
        storage             List files in the app sandbox data root.
        init                Create a new Cider project template.
        dev-loop            Print the fast build plus run --no-build loop.
        alpha-readiness     Report Stage 5 public-alpha gate status.
        dev                 Start the graphical local developer console.
        build               Compile the Cider project in the current directory.
        run                 Build if needed, then launch the application in a
                            virtual-device window.

    OPTIONS
        --path <dir>            Project directory. Defaults to the current
                                directory, searching upward for Cider.yaml.
        --device <name>         Device profile to launch with, overriding the
                                manifest.
        --log-level <level>     trace, debug, info, warning or error.
                                Defaults to info.
        --configuration <name>  debug or release. Defaults to debug.
        --output <file>         (compatibility-docs) Write generated markdown to
                                a file instead of stdout.
        --app-id <id>           (init) Application identifier for the template.
        --port <n>              (dev) Local dashboard port. Defaults to 5757.
        --inspect               Print the UI tree on every rebuild.
        --no-build              (run) Skip building; launch what is already built.
        --open                  (dev) Try to open the dashboard in a browser.
        --once                  (dev) Validate dashboard setup and exit.
        --version               Print the version and exit.
        --help, -h              Print this message.

    EXAMPLES
        cider doctor
        cider scan --path examples/ui-showcase
        cider compatibility-docs --output docs/generated-compatibility.md
        cider inspect --path examples/ui-showcase
        cider network --path examples/rest-client-cider
        cider storage --path examples/notes-cider
        cider init MyApp --app-id dev.example.myapp --path ./MyApp
        cider dev-loop --path examples/hello-cider
        cider alpha-readiness
        cider dev --path examples/rest-client-cider --once
        cd examples/hello-cider && cider run
        cider run --log-level debug --inspect
    """
}
