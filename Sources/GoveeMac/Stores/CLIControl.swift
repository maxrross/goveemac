import Foundation
import GoveeKit

extension LightStore {
    func handleControl(_ request: ControlRequest) async -> ControlReply {
        do {
            var reply = ControlReply()
            switch request.action {
            case "list", "status":
                let lights = request.device.map { query in devices.filter { $0.id == query || $0.name.caseInsensitiveCompare(query) == .orderedSame } } ?? devices
                guard request.device == nil || lights.count == 1 else { throw ControlError.message("Use an exact, unique light name or ID.") }
                reply.lights = lights.map(ControlLight.init); reply.mode = live.mode; reply.levels = live.levels; reply.preview = live.preview; return reply
            case "presets": reply.presets = presets; return reply
            case "displays": reply.displays = try await CaptureService.displays(); return reply
            case "stop": await live.stop(restore: request.restore ?? false); reply.mode = live.mode; return reply
            default: break
            }
            let matches: [LightDevice]
            if let query = request.device {
                matches = devices.filter { $0.id == query || $0.name.caseInsensitiveCompare(query) == .orderedSame }
            } else { matches = devices.filter(\.isAvailable) }
            guard matches.count == 1, let device = matches.first else { throw ControlError.message("Choose one light using --device and its exact name or ID from govee list.") }
            var commands: [LightCommand] = []
            switch request.action {
            case "on": commands = [.power(true)]
            case "off": commands = [.power(false)]
            case "color": guard let value = request.value, let color = RGB(hex: value) else { throw ControlError.message("Color must be #RRGGBB.") }; commands = [.color(color)]
            case "brightness": guard let value = request.value, let n = Int(value), (1...100).contains(n) else { throw ControlError.message("Brightness must be 1–100.") }; commands = [.brightness(n)]
            case "temperature": guard device.supportsTemperature else { throw ControlError.message("White temperature is currently supported over LAN only.") }; guard let value = request.value, let n = Int(value), (2000...9000).contains(n) else { throw ControlError.message("Temperature must be 2000–9000 K.") }; commands = [.temperature(n)]
            case "head":
                let labels = ["bottom", "middle", "top"]
                guard let label = request.head?.lowercased(), let index = labels.firstIndex(of: label), device.heads.indices.contains(index) else { throw ControlError.message("Head must be bottom, middle, or top on an H60B2.") }
                var head = device.heads[index]
                if let hex = request.value { guard let color = RGB(hex: hex) else { throw ControlError.message("Color must be #RRGGBB.") }; head.color = color; head.isOn = true }
                if let n = request.brightness { guard (1...100).contains(n) else { throw ControlError.message("Brightness must be 1–100.") }; head.brightness = n }
                if let source = request.source { guard ["on","off"].contains(source) else { throw ControlError.message("Use --on or --off for head power.") }; head.isOn = source == "on" }
                guard request.value != nil || request.brightness != nil || request.source != nil else { throw ControlError.message("Specify --color, --brightness, --on, or --off.") }
                commands = [.head(head)]
            case "scenes", "scene":
                await loadScenes(model: device.model)
                guard let library = scenes[device.model], !library.isEmpty else { throw ControlError.message(sceneStatus[device.model] ?? "No scene library is available.") }
                if request.action == "scenes" { reply.scenes = library.map(ControlScene.init); return reply }
                let matching = library.filter { $0.id == request.value || $0.name.caseInsensitiveCompare(request.value ?? "") == .orderedSame }
                guard matching.count == 1, let scene = matching.first else { throw ControlError.message("Use a unique scene name or ID from govee scenes.") }
                commands = [.power(true), .scene(scene)]
            case "preset":
                guard let preset = presets.first(where: { $0.id == request.value || $0.name.caseInsensitiveCompare(request.value ?? "") == .orderedSame }) else { throw ControlError.message("Unknown preset. Use govee presets.") }
                if let heads = preset.heads {
                    guard heads.map(\.id) == Array(device.heads.indices), !heads.isEmpty else { throw ControlError.message("This preset needs three individually controlled heads.") }
                    commands = [.power(true), .brightness(preset.brightness)] + heads.map(LightCommand.head)
                } else { commands = [.power(true), .brightness(preset.brightness), preset.temperature > 0 && device.supportsTemperature ? .temperature(preset.temperature) : .color(preset.color)] }
            case "effect", "music", "screen":
                if let speed = request.speed { guard speed.isFinite, (0.1...5).contains(speed) else { throw ControlError.message("Speed must be 0.1–5.") }; live.speed = speed }
                if let source = request.source { guard ["system","microphone"].contains(source) else { throw ControlError.message("Music source must be system or microphone.") }; live.source = source }
                if let sensitivity = request.sensitivity { guard sensitivity.isFinite, (0.2...5).contains(sensitivity) else { throw ControlError.message("Sensitivity must be 0.2–5.") }; live.sensitivity = sensitivity }
                if let mapping = request.mapping { guard ["rows","columns","whole"].contains(mapping) else { throw ControlError.message("Mapping must be rows, columns, or whole.") }; live.mapping = mapping }
                if let display = request.display { live.displayID = display }
                let effect = request.action == "effect" ? LiveEffect(rawValue: request.value ?? "") : nil
                guard request.action != "effect" || effect != nil else { throw ControlError.message("Unknown effect. Use govee --help.") }
                try await live.start(mode: effect?.title ?? (request.action == "music" ? "Music" : "Screen match"), device: device, effect: effect)
                reply.mode = live.mode; return reply
            case "import":
                guard let data = request.library else { throw ControlError.message("Use govee import with a selected JSON file.") }
                reply.message = try importLibrary(data: data, model: device.model); return reply
            default: throw ControlError.message("Unknown control action.")
            }
            await live.stop(restore: false)
            guard await perform(commands, to: device.id) else { throw ControlError.message(errorMessage ?? "The light did not accept the command.") }
            reply.lights = devices.filter { $0.id == device.id }.map(ControlLight.init)
            reply.message = "Command sent"; return reply
        } catch { return ControlReply(ok: false, message: error.localizedDescription) }
    }
}
