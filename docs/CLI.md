# CLI and agent control

`govee` ships inside `Govee Mac.app/Contents/MacOS`. It uses the app’s active
Bluetooth and LAN connections. Open Govee Mac and connect your light first;
the CLI does not create a second Bluetooth connection or hold session keys.

From a source checkout:

```sh
./script/build_and_run.sh
./script/install_cli.sh
# Ensure ~/.local/bin is in your PATH, or use the printed full path.
govee list
govee color '#24A5FF' --device 'Tree floor lamp'
govee head top --color '#AE6BFF' --brightness 80 --device 'Tree floor lamp'
govee head bottom --off --device 'Tree floor lamp'
govee scenes --device 'Tree floor lamp'
govee scene Aurora --device 'Tree floor lamp'
govee overlay breathe --speed 0.8 --device 'Tree floor lamp'
govee overlay off --device 'Tree floor lamp'
govee effect rainbow --speed 0.6 --device 'Tree floor lamp'
govee music --source system --sensitivity 2 --device 'Tree floor lamp'
govee music --source microphone --device 'Tree floor lamp'
govee displays
govee screen --display 1 --mapping rows --style vivid --device 'Tree floor lamp'  # Use the actual display ID.
govee stop --restore
govee preset 'Tree mix' --device 'Tree floor lamp'
```

For an installed app, invoke the binary with its full quoted path, or use the
install script with `/Applications/Govee Mac.app` as its first argument. The
installer never replaces a regular file at the destination. The app must stay
at the symlink target. Use `govee --help` for the complete command list.

Replies are JSON. Exit status is 0 on success, 1 on app/transport errors, and 2
on argument-parsing errors. Invalid command values rejected by the app also
return 1. `list` includes IDs, state, availability, and individual
heads. `status` also includes the current sync mode, analyzed audio levels,
sampled colors, capture status, detected beats, and output frame rate. When more than one light is available, specify its exact
name or ID with `--device`. Repeated names require an ID. A Bluetooth write ACK
or successful LAN send confirms transport, not physical device application.

`overlay` adds `breathe`, `pulse`, or `flicker` through master brightness only;
it keeps current RGB/head colors, relative head brightness, white settings,
and native scene selection. `--speed` accepts 0.1–5. The brightness command
sets the overlay's ceiling while it runs. `overlay off` removes only that
layer and restores the updated ceiling. It can run alongside a native scene
or Mac-driven colors. `effect` retains the earlier palette animations and
replaces RGB colors. `status` reports `overlay`, `outputBrightness` (the most
recent modulated level), and `nativeScene` (when exactly one light matches).
The main `mode` describes color/audio/screen sync, so it can be `Stopped` while
a brightness overlay is active. The light state's brightness is the user's
ceiling while an overlay runs.

The Unix socket is `~/Library/Application Support/GoveeMac/control.sock`,
inside a private directory. Socket permissions are 0600, and the server checks
the connecting process’s UID. There is no HTTP listener, external network
control port, or bearer token. Apps and agents running as your Mac user can
control the lights. Only one Govee Mac instance owns the socket. Message sizes
and socket reads are bounded. CLI import reads the explicitly selected file
in the command process and sends its content to the app; the GUI importer
uses the macOS file picker and reads off the main thread. Malformed requests return errors.

Manual color/head/scene commands stop Mac-driven color sync and keep the
brightness overlay. `off` stops it before powering off. `stop` stops both
layers, restoring the brightness ceiling; `stop --restore` also restores the prior
known head colors, white setting, or native scene. Mac effects, overlays, music, and
screen matching need the Mac awake and the app running; native scenes run on
the lamp after the commands have been delivered. Frames are serialized and
rate-limited to a target of eight updates per second. Streaming uses flow-controlled
Bluetooth writes without response when supported; other devices fall back to
acknowledged writes and may have a lower frame rate. Manual commands retain their
acknowledged delivery path. The displayed rate describes commands sent, not a
physical response measurement. Screen style is `vivid` by default; `average`
uses the mean visible color instead of emphasizing colored areas.
