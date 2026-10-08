# Security

Do not publish credentials or private device/network information in issues.

For a vulnerability in Govee Mac, use the repository's **Security → Report a vulnerability** private reporting feature. Include the affected version, reproduction steps, and impact. We will investigate and coordinate a fix; please avoid public disclosure until a fix is available.

The Govee LAN protocol is unencrypted, unauthenticated UDP. Govee Mac controls only devices on the local network or a nearby Bluetooth connection; these transports should be used on trusted networks. This app does not add device authentication to protocols that lack it.

The app contains no cloud client, telemetry, API keys, or account login. Download releases only from this repository or build from the source.
