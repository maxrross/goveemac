<p align="center">
  <img src="docs/icon.png" width="100" alt="Govee Mac icon">
</p>

<h1 align="center">Govee Mac</h1>
<p align="center"><strong>Your lights. Your Mac.</strong><br>Native, local control for Govee lights. Built by the community.</p>

<p align="center">
  <a href="https://github.com/maxrross/goveemac/actions/workflows/ci.yml"><img src="https://github.com/maxrross/goveemac/actions/workflows/ci.yml/badge.svg" alt="Build and tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-14a392" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-333333" alt="macOS 14 or later">
</p>

Govee Mac is an independent, open-source macOS app for controlling compatible Govee lights over **Bluetooth LE** or **local Wi-Fi**. No Govee account, cloud service, API key, subscription, or telemetry is required.

This is an early community release. Device support varies by model and firmware; please help us build the [compatibility list](docs/COMPATIBILITY.md).

![Govee Mac controls showing clearly labeled virtual demo lights](docs/screenshot.png)

## What you can do

- Discover LAN-enabled lights on your network or nearby compatible Bluetooth lights.
- Turn lights on or off, set brightness, and choose an RGB color.
- Adjust white temperature over LAN on models that support it.
- Apply six built-in looks, or save your own color, brightness, and temperature presets.
- Rename lights, mark favorites, and control them from the macOS menu bar.
- Add a light by IPv4 address when multicast discovery is blocked.
- Preview everything with labeled demo lights, without changing physical hardware.

Wi-Fi and Bluetooth read power and brightness replies from the light. Supported solid-color reply formats update RGB; mode-only replies retain the last requested RGB. Bluetooth controls are enabled only after a valid state response. A working connection does not guarantee every color format works on every model. H60B2 power and custom RGB on all three heads have been physically confirmed.

Encrypted legacy Bluetooth sessions (`e701`/`e702`, AES-ECB + RC4 framing) are negotiated automatically when plain state queries go unanswered. This is required by the H6098 tested during development. Newer AES-GCM session variants are not yet implemented.

## Get started

### Download

Download the universal community preview from [Releases](https://github.com/maxrross/goveemac/releases). It supports Apple Silicon and Intel Macs running **macOS 14 Sonoma or later**. Model support is listed in the [compatibility guide](docs/COMPATIBILITY.md).

Default builds are **ad-hoc signed development builds, not Apple-notarized releases**. macOS may require you to approve the app in System Settings → Privacy & Security after the first launch attempt.

### Build from source

Install Xcode 16 or later (Swift 6), then:

```sh
git clone https://github.com/maxrross/goveemac.git
cd goveemac
./script/build_and_run.sh
```

The script builds a real `dist/Govee Mac.app` bundle, then opens it. You can also open `Package.swift` in Xcode. Build and launch through the script to include the app's required privacy descriptions and icon.

If you have an Apple development certificate, set `GOVEE_MAC_SIGNING_IDENTITY` to its name when running the script. Signing with the same certificate retains Bluetooth permission across rebuilds. Ad-hoc signatures change with each build and may trigger a fresh macOS Bluetooth prompt.

```sh
swift test                             # Protocol and model tests
./script/build_and_run.sh --verify     # Build, launch, check the process
./script/build_and_run.sh --debug      # Launch under LLDB
./script/build_and_run.sh --logs       # Stream runtime logs
./script/build_app.sh --release --universal
```

To open an isolated demo instance:

```sh
open -n "dist/Govee Mac.app" --args --demo
```

### Connect your light

**Bluetooth:** Click **Add light → Bluetooth**. Allow Bluetooth access, choose your light, and click **Connect**. Keep it nearby and close other apps using its Bluetooth connection. The light must expose the compatible writable Govee characteristic.

**Wi-Fi:** In Govee Home, open the light's settings and enable **LAN Control**. Put your Mac on the same network, allow Local Network access if macOS asks, and click **Add light → Local Wi-Fi**. Only models with LAN Control support this connection. Discovery needs UDP 4001, replies use UDP 4002, and commands go to UDP 4003.

See the [setup and compatibility guide](docs/COMPATIBILITY.md) for troubleshooting.

## Community project

We welcome device reports, bug fixes, accessibility improvements, translations, and new features. Start with [CONTRIBUTING.md](CONTRIBUTING.md), open an [issue](https://github.com/maxrross/goveemac/issues/new/choose), or join [Discussions](https://github.com/maxrross/goveemac/discussions).

Potential next steps include broader Bluetooth protocols, screen sync, groups, and configurable per-model capabilities. These are ideas for contributors, not features shipped in this release.

## Architecture

`GoveeKit` contains Sendable value models, LAN/BLE packet codecs, and the legacy session cipher, with no UI or third-party dependencies. `GoveeMac` contains the SwiftUI app, shared observable store, CoreBluetooth service, and a serial-queue UDP transport. Commands are serialized per light; color-picker edits are debounced and BLE writes respect backpressure. Bluetooth state is queried after commands; session keys are kept only in memory and discarded at disconnect.

Device nicknames, favorites, manual IPs, and custom presets stay in local macOS preferences. No network credentials are stored. Demo launches use a separate preferences suite. LAN packets and BLE writes are unauthenticated local-device protocols; use them on networks you trust.

## Credits and license

Inspired by [Govee-Sync](https://github.com/Didilusse/Govee-Sync) by Adil Rahmani. Its MIT-licensed Bluetooth command framing is adapted with attribution. Encrypted-session research is credited to [mpalczew/govee-ble-segments](https://github.com/mpalczew/govee-ble-segments). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for notices. The UI, Wi-Fi transport, state handling, app icon, and project structure are new.

MIT © Govee Mac contributors. Independent community software; not affiliated with or endorsed by Govee.
