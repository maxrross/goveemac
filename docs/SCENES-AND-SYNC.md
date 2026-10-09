# Scenes, import, music, and screen matching

The Scenes tab loads Govee’s model-specific light-effect library. For H60B2,
88 scenes are available across Natural, Festival, Life, Emotion, Funny, Planet,
and Seasonal Changes. This matches the scene categories shown in Govee Lite.
Scenes are sent as native commands; they are not static color approximations.
Firmware-resident scenes select a code directly. Other scenes upload their
fragmented program before selecting the code. Aurora has been physically
verified on the Tree lamp. Each scene has not been individually hardware-tested.

Definitions are downloaded from Govee’s `app2.govee.com` library endpoint,
without account credentials, and cached under Application Support/GoveeMac/Scenes.
The endpoint is used by Govee’s app and may change independently of the
community project. Refresh updates the cache. Once downloaded, control is
local and the cache works offline. Proprietary Govee artwork and scene data
are not bundled in this repository. The app loads Govee's scene icons from
the HTTPS image URLs supplied by the library, with a neutral fallback when
an icon is unavailable. Icons identify scenes; they are not live RGB previews.

Import JSON accepts a raw model library response, a flat `govee_lights` scene
library (`scene_name`, `scene_code`, `scence_param`), or a JSON array of Govee
Mac saved looks. It validates frame bounds and assigns imported scenes to the selected model; choose a library downloaded for that model. Private app
containers are not automatically read. Govee Lite does not expose a general
export interface in the inspected Tree lamp UI, and its DIY tab showed no
saved DIY items. Import is not a claim that arbitrary account-specific cloud
DIY templates can be copied from Govee Home or Lite.

The Color tab's compact Effect menu offers Breathe, Pulse, and Flicker. These
send only master-brightness commands: RGB colors, relative head brightness,
white temperature, and a native scene program remain in place. Speed is
adjustable. The brightness slider sets the maximum; the effect varies below
that level without turning the lamp off. Choosing None restores that maximum
and leaves the current colors or native scene running. Color, head, and scene
edits keep this brightness effect active; turning the lamp off stops it.
The app must remain running. An overlay uses the model's brightness command,
so whether a particular firmware preserves its native animation needs a
physical check.

The CLI also retains the earlier palette effects (rainbow, color cycle,
breathe, candle, ocean, aurora, and sunset). `govee effect` replaces RGB colors;
`govee overlay` adds brightness motion over the current colors. Those palette
effects no longer occupy a separate panel in Scenes.
Choose Saved looks to save your current head colors and brightness levels.

Music supports system audio (default) and microphone input. System audio uses
ScreenCaptureKit; microphone input uses AVAudioEngine. Audio is split into
bass, mid, and treble energy bands. Continuous filters, automatic gain, a fast
attack/slower release envelope, and bass onset detection drive changing hues
and individual head brightness. Sensitivity is adjustable. Nothing is recorded or uploaded. Music continues
with other apps playing audio. Capture may not include protected media.

Screen matching samples one display at low resolution. Choose vertical regions
(bottom/middle/top), horizontal regions (left/center/right), or the whole screen.
The default is the main display; displays show their actual macOS names.
The live thumbnail shows which visible display is captured, including Govee Mac's
window. Vivid emphasizes dominant colored areas without diluting them with dark
bars; Average uses the mean visible color. Transparent padding and incomplete
frames are ignored. Color frames are processed locally; only the current
low-resolution preview is held in memory. Truly black content produces black.

macOS requires Screen & System Audio Recording permission for screen and
system-audio capture, and Microphone permission for microphone input. Access
is requested when starting the feature, never at launch. If denied, enable
Govee Mac in System Settings → Privacy & Security, restart it, and retry.
Source, display, region, and style changes restart the active capture automatically.
Manual edits stop audio/screen color sync while retaining any brightness
effect. Stop & restore stops both and restores the prior known look or scene.

Account-specific DIY/Share Space import, Govee's AI generator, remote cloud control,
and Alexa/Google account linking are not implemented. Wi-Fi setup, camera calibration,
and firmware updates also remain in Govee's apps. Local groups and schedules are
not implemented yet, but do not inherently require cloud access. LAN temperature remains
available; native white-channel control over Bluetooth is not yet implemented.
Only supported model/firmware protocols can be controlled locally.

Page tabs sit directly below the light's header. Scene and saved-look cards remain enabled while commands
are sent in order, so one selection does not fade the entire grid. While a
native scene plays, the lamp preview shows neutral heads marked "Scene active":
the lamp does not report the animated RGB values, and the preview must not
present stale manual colors as current scene colors.
Stop & restore is available in Music and Screen while sync is running. Choose
None in the Color page's Effect menu to stop a brightness effect and restore
the selected brightness. Native scenes run
on the light without the Mac sending continuous frames. Connection diagnostics
are in the main window's Settings page, rather than a footer under each tab.
Disconnect is available by right-clicking a connected Bluetooth light in the
sidebar. Scroll indicators are hidden; trackpad, wheel, and keyboard scrolling
remain available. Scene icons are larger and use the library's actual artwork.
The five page tabs have equal widths and switch without animating the page
layout. Scene search and category selection survive switching tabs. Decoded
scene thumbnails are reused from a bounded 128-image cache, and decoding runs
off the main thread. The Screen page reuses its display list; use Refresh
displays after connecting or removing a monitor.

## Release validation

The H60B2 Aurora scene was physically confirmed animating. Both system audio
and microphone capture produced nonzero frequency-band energy and changing
head frames. Screen capture produced region-specific colors while Bluetooth
remained connected. CLI tests checked per-head edits, animated effects,
stop/restore, malformed and oversized requests, concurrent clients, selected
light filtering, JSON imports, and invalid arguments. The pure protocol,
cipher, scene-fragment, audio-band, music-response, and screen-region/style suite
has 44 tests. A quiet 16-beat synthetic system-audio test produced 49 distinct
frames, detected all 16 beats, and sent a median 7.7 frames per second while
the H60B2 remained connected. These are software/transport measurements, not
a claim of measured physical beat latency. UI checks at the minimum window
width verified wrapped effects, search filtering, and equal control-card heights.
Live checks compared Vivid and Average screen colors, exercised both audio
sources, and verified that switching capture modes preserves the original
head colors and brightness for Stop & restore.
A follow-up effect-switch check sampled 15 live states across four replacements
without exposing a transient Stopped state or losing the Bluetooth connection.
Native scene restore and the saved unknown-color flags were also checked.

Brightness-overlay checks sampled 41 manual-color states and 42 native-scene
states on the connected H60B2. Head RGB values and relative brightness stayed
unchanged, editing the brightness ceiling kept the overlay running, and
choosing None restored the updated ceiling. With Star selected, the output
covered 18–70% with 27 distinct brightness levels, the native-scene name stayed
selected, and Bluetooth remained connected. These confirm app state and
command delivery, rather than physical animation behavior. Four pure tests
cover bounds, timing, invalid numeric inputs, and brightness-only packets.
Unchanged Bluetooth keepalives no longer mutate the device, streamed head
changes are applied once per frame, and the scene browser no longer depends
on live RGB state. No quantitative scroll frame timing is claimed.
