# Contributing to Omarchy Audio

Bug reports, documentation improvements, and pull requests are welcome.

## Getting started

You need macOS 14 or later and Xcode Command Line Tools with Swift 6.
The project has no external package dependencies.

Fork the repository and clone your fork, or clone the repository directly if
you have write access. Create a branch for your change. From the project directory,
run:

```bash
swift run AudioChecks
bash scripts/build-app.sh
open "build/Omarchy Audio.app"
```

To test live audio, you also need a Linux host running PipeWire/PulseAudio with
`pactl` and `parec`, reachable over SSH using key-based authentication without
password prompts. Configure your own SSH alias, hostname, IP address, or
`user@host` in the app's settings. No host is configured by default.

## Making changes

Keep each pull request focused on one change and follow the surrounding Swift
code style. Update the README when behavior, requirements, or commands change.
For changes to PCM buffering, concurrency, or host validation, add or update
relevant checks in `Sources/AudioChecks/main.swift`.

Run `swift run AudioChecks` and `bash scripts/build-app.sh` before submitting
code changes. After rebuilding, quit the running app and reopen it to load the
new version. For audio or connection changes, also check a live stream with the
app closed:

```bash
"build/Omarchy Audio.app/Contents/MacOS/OmarchyAudio" --check-stream
```

This diagnostic plays remote audio for six seconds and requires a working SSH
connection. If you cannot run it, mention that in the pull request. For UI changes,
include a screenshot and describe what you checked manually.

Do not commit build output, private SSH keys, credentials, or personal connection
details. The app should continue to use the existing OpenSSH configuration for
authentication.

## Reporting bugs and opening pull requests

For bug reports, include your macOS version, Mac architecture, app version,
steps to reproduce, and expected versus actual behavior. Include relevant error
messages with personal or sensitive information removed.

For pull requests, explain the problem, describe the resulting behavior, and
list the checks you ran. Discuss substantial changes in an issue before starting
implementation so the approach can be agreed on.

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).
