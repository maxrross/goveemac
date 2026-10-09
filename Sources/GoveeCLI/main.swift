import Foundation
import GoveeKit
import Darwin

let help = """
Govee Mac CLI — controls the running app over a private local socket.

  govee list                             Connected/discovered lights and IDs
  govee status [--device NAME_OR_ID]      State and active sync mode
  govee on|off [--device NAME_OR_ID]
  govee brightness 1..100 [--device …]
  govee color '#RRGGBB' [--device …]
  govee temperature 2000..9000 [--device …]
  govee head bottom|middle|top --color '#RRGGBB' [--brightness 70] [--off|--on]
  govee presets                          Saved looks
  govee preset NAME [--device …]
  govee scenes [--device …]               Download/cache model-specific library
  govee scene NAME_OR_ID [--device …]     Run a native Govee scene
  govee effect rainbow|breathe|candle|ocean|aurora|sunset|colorCycle [--speed 1]
  govee overlay breathe|pulse|flicker|off [--speed 1]  Motion over existing colors/scenes
  govee music [--source system|microphone] [--sensitivity 2]
  govee displays                         Available screen-capture displays
  govee screen [--display ID] [--mapping rows|columns|whole] [--style vivid|average]
  govee stop [--restore]                  Stop app-driven lighting
  govee import /path/to/library.json [--device …]

All replies are JSON. Exit 0 = accepted/completed; exit 1 = failed;
exit 2 = invalid arguments. --device is required when multiple lights exist.
Music and screen capture require the normal macOS permissions in Govee Mac.
Transport success cannot prove that the physical light applied a command.
"""
func fail(_ message: String, code: Int32 = 2) -> Never {
    let data = (try? JSONEncoder().encode(ControlReply(ok: false, message: message))) ?? Data()
    FileHandle.standardError.write(data + Data([10])); exit(code)
}
var args = Array(CommandLine.arguments.dropFirst())
if args.isEmpty || args.contains("--help") || args.first == "help" { print(help); exit(0) }
var request = ControlRequest(action: args.removeFirst())
let actions = ["list","status","on","off","brightness","color","temperature","head","presets","preset","scenes","scene","effect","overlay","music","displays","screen","stop","import"]
guard actions.contains(request.action) else { fail("Unknown command. Use govee --help.") }
while !args.isEmpty {
    let arg = args.removeFirst()
    if arg == "--restore" { guard request.action == "stop" else { fail("--restore is only valid with stop.") }; request.restore = true; continue }
    if arg == "--off" { guard request.action == "head" else { fail("--off is only valid with head.") }; request.source = "off"; continue }
    if arg == "--on" { guard request.action == "head" else { fail("--on is only valid with head.") }; request.source = "on"; continue }
    if arg.hasPrefix("--") {
        guard !args.isEmpty else { fail("Missing value for \(arg).") }
        let allowed = ["--color": ["head"], "--brightness": ["head"], "--source": ["music"], "--speed": ["effect","overlay"], "--display": ["screen"], "--sensitivity": ["music"], "--mapping": ["screen"], "--style": ["screen"]]
        if let actions = allowed[arg], !actions.contains(request.action) { fail("\(arg) is not valid with \(request.action).") }
        let value = args.removeFirst()
        switch arg {
        case "--device": request.device = value
        case "--color": request.value = value
        case "--source": request.source = value
        case "--brightness": guard let n = Int(value), (1...100).contains(n) else { fail("Brightness must be 1–100.") }; request.brightness = n
        case "--speed": guard let n = Double(value), n.isFinite, (0.1...5).contains(n) else { fail("Speed must be 0.1–5.") }; request.speed = n
        case "--sensitivity": guard let n = Double(value), n.isFinite, (0.2...5).contains(n) else { fail("Sensitivity must be 0.2–5.") }; request.sensitivity = n
        case "--mapping": guard ["rows","columns","whole"].contains(value) else { fail("Mapping must be rows, columns, or whole.") }; request.mapping = value
        case "--style": guard ["vivid","average"].contains(value) else { fail("Screen style must be vivid or average.") }; request.style = value
        case "--display": guard let n = UInt32(value) else { fail("Display must be a numeric ID.") }; request.display = n
        default: fail("Unknown option \(arg).")
        }
    } else if request.action == "head", request.head == nil { request.head = arg }
    else if request.value == nil { request.value = arg }
    else { fail("Unexpected argument \(arg). Quote names containing spaces.") }
}
let requiredValue = ["brightness","color","temperature","preset","scene","effect","overlay","import"]
if requiredValue.contains(request.action), request.value == nil { fail("Missing value for \(request.action).") }
if !requiredValue.contains(request.action), request.action != "head", request.value != nil { fail("Unexpected value for \(request.action).") }
do {
    if request.action == "import" {
        guard let path = request.value, path.hasPrefix("/") else { fail("Use an absolute JSON file path.") }
        let input = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        defer { try? input.close() }
        let data = try input.read(upToCount: 8_000_001) ?? Data()
        guard data.count <= 8_000_000 else { fail("Import files must be at most 8 MB.") }
        request.library = data; request.value = nil
    }
    let fd = try ControlSocket.connect(); defer { close(fd) }
    try ControlSocket.writeMessage(JSONEncoder().encode(request), to: fd)
    let data = try ControlSocket.readMessage(fd)
    let reply = try JSONDecoder().decode(ControlReply.self, from: data)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    FileHandle.standardOutput.write(try encoder.encode(reply) + Data([10]))
    exit(reply.ok ? 0 : 1)
} catch { fail(error.localizedDescription, code: 1) }
