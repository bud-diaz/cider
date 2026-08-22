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
        doctor      Check that this machine can build and run Cider projects.
        build       Compile the Cider project in the current directory.
        run         Build if needed, then launch the application in a
                    virtual-device window.

    OPTIONS
        --path <dir>            Project directory. Defaults to the current
                                directory, searching upward for Cider.yaml.
        --device <name>         Device profile to launch with, overriding the
                                manifest.
        --log-level <level>     trace, debug, info, warning or error.
                                Defaults to info.
        --configuration <name>  debug or release. Defaults to debug.
        --inspect               Print the UI tree on every rebuild.
        --no-build              (run) Skip building; launch what is already built.
        --version               Print the version and exit.
        --help, -h              Print this message.

    EXAMPLES
        cider doctor
        cd examples/hello-cider && cider run
        cider run --log-level debug --inspect
    """
}
