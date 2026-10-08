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
govee effect rainbow --speed 0.6 --device 'Tree floor lamp'
govee music --source system --sensitivity 2 --device 'Tree floor lamp'
govee music --source microphone --device 'Tree floor lamp'
govee displays
govee screen --display 1 --mapping rows --device 'Tree floor lamp'  # Use the actual display ID.
govee stop --restore
govee preset 'Tree mix' --device 'Tree floor lamp'
```

For an installed app, invoke the binary with its full quoted path, or use the
install script with `/Applications/Govee Mac.app` as its first argument. The
installer never replaces a regular file at the destination. The app must stay
at the symlink target. Use `govee --help` for the complete command list.

Replies are JSON. Exit status is 0 on success, 1 on app/transport errors, and 2
on argument errors. `list` includes IDs, state, availability, and individual
heads. `status` also includes the current sync mode, analyzed audio levels,
and sampled colors. When more than one light is available, specify its exact
name or ID with `--device`. Repeated names require an ID. A Bluetooth write ACK
or successful LAN send confirms transport, not physical device application.

The Unix socket is `~/Library/Application Support/GoveeMac/control.sock`,
inside a private directory. Socket permissions are 0600, and the server checks
the connecting process’s UID. There is no HTTP listener, external network
control port, or bearer token. Apps and agents running as your Mac user can
control the lights. Only one Govee Mac instance owns the socket. Message sizes
and socket reads are bounded. CLI import reads the explicitly selected file
in the command process and sends its content to the app; the GUI importer
uses the macOS file picker and reads off the main thread. Malformed requests return errors.

Manual commands stop Mac-driven sync. `stop --restore` restores the prior
known head colors, white setting, or native scene. Mac effects, music, and
screen matching need the Mac awake and the app running; native scenes run on
the lamp after the commands have been delivered. Frames are serialized and
rate-limited; Bluetooth responsiveness depends on the device’s ACK timing.
