# Signed and notarized releases

GitHub downloads are Developer ID signed, Apple-notarized, and stapled. Local development builds use the signing identity configured on that Mac and do not need notarization.

Release work runs locally. Repository GitHub Actions are disabled.

## Prepare a release

You need a Developer ID Application certificate and an existing `notarytool` keychain profile for the same Apple Developer team. Credentials stay in Keychain and must not be committed.

Build the universal app, then notarize a copy:

```sh
./script/build_app.sh --release --universal
export GOVEE_RELEASE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export GOVEE_NOTARY_PROFILE='Your existing notarization profile'
./script/notarize_app.sh "dist/Govee Mac.app" dist
```

The script preserves the input bundle, signs its staged copy with hardened runtime and a secure timestamp, submits it to Apple, requires `Accepted`, staples and validates the ticket, and checks Gatekeeper. It then creates the universal ZIP and `SHA256SUMS.txt`.

Processing may take time. A timeout does not cancel Apple's submission. The retained staging directory holds the exact signed app, upload archive, and submission result; check that submission before creating another one.

The current app has one executable. If frameworks, extensions, or XPC helpers are introduced, extend the script to sign that nested code explicitly before the outer app.

## Publish

Upload the ZIP and checksum to the intended GitHub release after validation. Release notes should name the models physically checked, disclose remaining compatibility limits, and identify the source commit used for the build.
