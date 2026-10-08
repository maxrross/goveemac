# Setup and compatibility

Govee's transports and packet formats vary by model and firmware. We are building an honest community-tested list.

| Model | Connection | Evidence | Status |
| --- | --- | --- | --- |
| H6195 | Bluetooth LE | Govee-Sync's upstream author reports this as their primary tested model | Upstream reference; not independently verified by Govee Mac |
| H6098 | Bluetooth LE | Encrypted legacy handshake and valid power/brightness/color replies verified on a local device | Session and state queries verified; physical command report pending |
| LAN-enabled models | Local Wi-Fi | Codec tests and documented Govee UDP protocol | Physical model reports welcome |

Discovery and connection alone do not establish support for power, brightness, color, or temperature. Report each result separately in a compatibility issue. RGB-over-Bluetooth is implemented; dedicated white-temperature commands are available only over LAN, subject to the model's capabilities.

## Bluetooth

1. Power on the light, keep it near the Mac, and open Add light → Bluetooth.
2. Allow Govee Mac in System Settings → Privacy & Security → Bluetooth.
3. Select the light, then click Connect.
4. Close Govee Home and other Bluetooth controllers if connection stalls.

Nearby names containing `Govee`, `iHoment`, or a Govee `Hxxxx` model code appear in discovery. The app locates the writable characteristic `00010203-0405-0607-0809-0a0b0c0d2b11`, subscribes to `…2b10`, and queries state before enabling controls. If plain queries go unanswered, it negotiates a legacy encrypted `e701`/`e702` session. Newer AES-GCM session variants are not implemented.

Bluetooth reads power, brightness, and recognized solid-RGB reply formats. Unsupported effect modes retain the last requested RGB color. Commands are displayed immediately, then followed by state queries. A power query every two seconds keeps the authenticated connection active. Check the actual light when reporting support.

H6098/H6099 and devices using the legacy encrypted session use a 0–100 brightness scale. Other devices use the original 0–254 scale. H6098/H6099 encrypted RGB uses the extended RGBIC command. Broader model profiles are still needed.

## Local Wi-Fi

1. Open the light in Govee Home and enable Settings → LAN Control.
2. Connect the light and Mac to the same network.
3. Allow Local Network access for Govee Mac if prompted.
4. Open Add light → Local Wi-Fi and scan.

If the model does not offer LAN Control, try Bluetooth. This app does not use Govee's cloud API.

Discovery sends `scan` to `239.255.255.250:4001` on active IPv4 multicast interfaces. Replies arrive on UDP 4002. Commands and state requests use the light's source IPv4 address on UDP 4003. The app ignores a packet's advertised IP when deciding where to send commands.

If discovery fails, check guest-network/client isolation, VLAN routing, VPN routes, and UDP rules. A manual IPv4 entry can bypass multicast discovery but cannot bypass blocked UDP commands or missing LAN Control. Reserve the light's IP in your router if you use a manual address.

Only one LAN controller can use the app's exclusive UDP 4002 listener at a time. Quit other Govee LAN controllers if the app reports that the port is busy. The app queries LAN state every 12 seconds and marks a light unavailable after 30 seconds without a response.

White-temperature requests are clamped to 2000–9000 K; individual models may support a narrower range or no white-temperature command. This initial release does not discover per-model temperature capabilities automatically.

## Protocol sources

- [Govee-Sync](https://github.com/Didilusse/Govee-Sync), MIT-licensed BLE implementation, primarily tested upstream with H6195.
- [govee-ble-segments](https://github.com/mpalczew/govee-ble-segments), encrypted legacy session protocol research.
- [Govee LAN API 101](https://community.govee.com/posts/mastering-the-lan-api-series-lan-api-101/136755), published Govee community protocol documentation.

The app has no screen capture, audio capture, cloud scenes, segment control, or cloud-only device support in this release.
