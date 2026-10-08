# Contributing to Govee Mac

Welcome! Small, focused contributions are a great place to start. You do not need to own every Govee model to contribute.

## Development

Use macOS 14+, Xcode 16+, and Swift 6. There are no third-party package dependencies.

```sh
swift test
./script/build_and_run.sh --verify
```

`script/build_and_run.sh` is the build/run entry point and the included Codex Run action. The script stages the app's privacy descriptions into its bundle. Running a bare SwiftPM executable can cause permission and launch behavior that differs from the app.

## Before opening a pull request

- Describe the problem, the resulting behavior, and how you verified it.
- Keep changes focused. Follow the existing app, views, stores, services, and kit boundaries.
- Add meaningful protocol regression tests for packet changes.
- Check real hardware when you can. State the exact model, firmware, connection, and which commands worked. Never call a device supported based only on discovery.
- Verify light and dark appearance and keyboard access for UI changes.
- Preserve MIT notices for adapted code. Use original icons and artwork or properly attributed assets.
- Do not commit device identifiers, network captures, IPs from your home, API keys, or credentials.

For a new transport or large feature, open an issue or Discussion before implementing it so we can agree on scope.

## Device reports

Use the compatibility issue template. Include model and firmware if known, macOS version, connection type, and separate results for power, brightness, color, and white temperature. Redact Bluetooth UUIDs, MAC addresses, serial numbers, and private network details from screenshots or logs.

## Release builds

```sh
./script/build_app.sh --release --universal
ditto -c -k --sequesterRsrc --keepParent "dist/Govee Mac.app" dist/Govee-Mac-universal.zip
```

Builds and tests run locally; repository GitHub Actions are disabled. Bundles default to ad-hoc signing. Set `GOVEE_MAC_SIGNING_IDENTITY` or place your existing development certificate's name in the ignored `.local-signing-identity` file for local signed builds. Notarization is not configured.

By contributing, you agree that your contributions may be distributed under the project's MIT license. Please follow our [Code of Conduct](CODE_OF_CONDUCT.md).
