import Darwin
import Foundation
import GoveeKit
import Observation

@Observable @MainActor
final class LightStore {
    var devices: [LightDevice] = []
    var selectedID: String? {
        didSet {
            if let id = selectedID, !id.hasPrefix("demo:") { defaults.set(id, forKey: "selectedLight") }
        }
    }
    var favorites: Set<String> = []
    var customPresets: [LightPreset] = []
    var isScanningLAN = false
    var isScanningBluetooth = false
    var lanStatus = "Discover lights on the same network as your Mac."
    var bluetoothStatus = "Find compatible Govee lights nearby."
    var errorMessage: String?
    var busyIDs: Set<String> = []
    var isDemo = false

    @ObservationIgnored private let lan = LANService()
    @ObservationIgnored private let bluetooth = BluetoothService()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var names: [String: String] = [:]
    @ObservationIgnored private var lanReady = false
    @ObservationIgnored private var started = false
    @ObservationIgnored private var polling: Task<Void, Never>?
    @ObservationIgnored private var bluetoothScan: Task<Void, Never>?
    @ObservationIgnored private var commandTails: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var debounceTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var savedHeads: [String: [LightHeadState]] = [:]

    var selectedDevice: LightDevice? { devices.first { $0.id == selectedID } }
    var presets: [LightPreset] { LightPreset.builtIns + customPresets }
    var availableCount: Int { devices.filter(\.isAvailable).count }
    var onCount: Int { devices.filter { $0.hasKnownState && $0.state.isOn && $0.isAvailable }.count }

    init() {
        defaults = ProcessInfo.processInfo.arguments.contains("--demo")
            ? UserDefaults(suiteName: "community.goveemac.preview")! : .standard
        names = defaults.dictionary(forKey: "lightNames") as? [String: String] ?? [:]
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        if let data = defaults.data(forKey: "headSettings"),
           let saved = try? JSONDecoder().decode([String: [LightHeadState]].self, from: data) {
            savedHeads = saved
        }
        if let data = defaults.data(forKey: "presets"), let saved = try? JSONDecoder().decode([LightPreset].self, from: data) {
            customPresets = saved
        }
        for host in defaults.stringArray(forKey: "manualAddresses") ?? [] {
            let id = "manual:\(host)"
            devices.append(LightDevice(id: id, name: names[id] ?? "Govee light", model: "Manual IP", connection: .lan, address: host))
        }
        for record in defaults.array(forKey: "rememberedBluetooth") as? [[String: String]] ?? [] {
            guard let uuid = record["uuid"], let name = record["name"], let model = record["model"] else { continue }
            devices.append(LightDevice(id: "ble:\(uuid)", name: names["ble:\(uuid)"] ?? DeviceCatalog.friendlyName(model: model) ?? name, model: model, connection: .bluetooth, address: uuid))
        }
        let savedSelection = defaults.string(forKey: "selectedLight")
        for index in devices.indices { restoreHeads(at: index) }
        selectedID = devices.contains(where: { $0.id == savedSelection }) ? savedSelection : devices.first?.id
        bluetooth.onDiscovery = { [weak self] id, name in self?.discoveredBluetooth(id: id, name: name) }
        bluetooth.onConnection = { [weak self] id, ready, error in
            guard let self, let index = self.devices.firstIndex(where: { $0.id == "ble:\(id)" }) else { return }
            self.devices[index].isAvailable = ready
            self.devices[index].isConnecting = false
            self.devices[index].lastSeen = ready ? Date() : nil
            if ready {
                var records = self.defaults.array(forKey: "rememberedBluetooth") as? [[String: String]] ?? []
                records.removeAll { $0["uuid"] == id }
                let device = self.devices[index]
                records.append(["uuid": id, "name": device.name, "model": device.model])
                self.defaults.set(records, forKey: "rememberedBluetooth")
            }
            if let error { self.errorMessage = error }
        }
        bluetooth.onStatus = { [weak self] in self?.bluetoothStatus = $0 }
        bluetooth.onReconnecting = { [weak self] id in
            guard let self, let index = self.devices.firstIndex(where: { $0.id == "ble:\(id)" }) else { return }
            self.devices[index].isConnecting = true
        }
        bluetooth.onEncryptedSession = { [weak self] id in
            guard let self, let index = self.devices.firstIndex(where: { $0.id == "ble:\(id)" }) else { return }
            self.devices[index].usesEncryptedBLE = true
        }
        bluetooth.onReply = { [weak self] id, data, percent in
            guard let self, data.count >= 3, data[0] == 0xAA,
                  let index = self.devices.firstIndex(where: { $0.id == "ble:\(id)" }) else { return }
            switch data[1] {
            case 0x01:
                guard data[2] <= 1 else { return }
                self.devices[index].state.isOn = data[2] == 1
                self.devices[index].hasKnownState = true
            case 0x04:
                self.devices[index].state.brightness = max(1, min(100, percent ? Int(data[2]) : Int((Double(data[2]) / 254 * 100).rounded())))
            case 0x05 where !DeviceCatalog.hasModeOnlyColorReply(model: self.devices[index].model) && data.count >= 6 && [0x02, 0x0D].contains(data[2]):
                self.devices[index].state.color = RGB(data[3], data[4], data[5])
                self.devices[index].state.temperature = 0
            case 0x05 where !DeviceCatalog.hasModeOnlyColorReply(model: self.devices[index].model) && data.count >= 7 && data[2] == 0x15 && data[3] == 1:
                self.devices[index].state.color = RGB(data[4], data[5], data[6])
                self.devices[index].state.temperature = 0
            default: break
            }
            self.devices[index].lastSeen = Date()
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") { enableDemo() }
    }

    func start() async {
        guard !started else { return }
        started = true
        if !isDemo {
            bluetooth.reconnect(ids: devices.filter { $0.connection == .bluetooth }.map(\.address))
            await scanLAN()
        }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled, let self else { return }
                for device in self.devices where device.connection == .lan {
                    if let seen = device.lastSeen, Date().timeIntervalSince(seen) > 30,
                       let index = self.devices.firstIndex(where: { $0.id == device.id }) {
                        self.devices[index].isAvailable = false
                    }
                    try? await self.lan.send(.status, to: device.address)
                }
            }
        }
    }

    private func prepareLAN() async throws {
        guard !lanReady else { return }
        try await lan.start { [weak self] event, address in
            Task { @MainActor [weak self] in self?.received(event, from: address) }
        }
        lanReady = true
    }

    func scanLAN() async {
        guard !isScanningLAN else { return }
        isScanningLAN = true
        lanStatus = "Looking for lights on your network…"
        defer { isScanningLAN = false }
        do {
            try await prepareLAN()
            for device in devices where device.connection == .lan { try? await lan.send(.status, to: device.address) }
            for _ in 0..<3 {
                try await lan.scan()
                try await Task.sleep(for: .seconds(1.5))
            }
            let count = devices.filter { $0.connection == .lan && $0.isAvailable }.count
            lanStatus = count == 0 ? "No Wi-Fi lights found. Enable LAN Control in Govee Home, then try again." : "Found \(count) local \(count == 1 ? "light" : "lights")."
        } catch {
            lanStatus = error.localizedDescription
        }
    }

    func scanBluetooth() {
        guard !isScanningBluetooth else { return }
        isScanningBluetooth = true
        bluetooth.scan()
        bluetoothScan?.cancel()
        bluetoothScan = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled, let self else { return }
            self.bluetooth.stopScan()
            self.isScanningBluetooth = false
            if !self.bluetooth.isPoweredOn { return }
            if !self.devices.contains(where: { $0.connection == .bluetooth }) {
                self.bluetoothStatus = "No nearby lights found. Move closer and close Govee Home before retrying."
            } else { self.bluetoothStatus = "Select a Bluetooth light and click Connect." }
        }
    }

    func connect(_ device: LightDevice) {
        guard device.connection == .bluetooth,
              let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].isConnecting = true
        isScanningBluetooth = false
        bluetoothScan?.cancel()
        bluetooth.connect(id: device.address)
    }

    func disconnect(_ device: LightDevice) {
        bluetooth.disconnect(id: device.address)
        let records = (defaults.array(forKey: "rememberedBluetooth") as? [[String: String]] ?? []).filter { $0["uuid"] != device.address }
        defaults.set(records, forKey: "rememberedBluetooth")
    }

    func addManual(address: String, name: String) async -> Bool {
        let host = address.trimmingCharacters(in: .whitespacesAndNewlines)
        var parsed = in_addr()
        guard inet_pton(AF_INET, host, &parsed) == 1, parsed.s_addr != 0,
              parsed.s_addr != UInt32.max else {
            errorMessage = "Enter the light’s IPv4 address from your router, such as 192.168.1.50."; return false
        }
        do { try await prepareLAN() } catch { errorMessage = error.localizedDescription; return false }
        if let existing = devices.first(where: { $0.address == host && $0.connection == .lan }) {
            selectedID = existing.id; return true
        }
        let id = "manual:\(host)"
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        devices.append(LightDevice(id: id, name: label.isEmpty ? "Govee light" : label, model: "Manual IP", connection: .lan, address: host))
        names[id] = label.isEmpty ? "Govee light" : label
        persistMetadata()
        persistManualAddresses()
        selectedID = id
        do { try await lan.send(.status, to: host) }
        catch { errorMessage = error.localizedDescription }
        return true
    }

    private func received(_ event: LANEvent, from host: String) {
        switch event {
        case .discovery(let identifier, let model):
            let id = "lan:\(identifier)"
            if let index = devices.firstIndex(where: { $0.id == id }) {
                devices[index].address = host
                devices[index].isAvailable = true
                devices[index].lastSeen = Date()
            } else if let index = devices.firstIndex(where: { $0.connection == .lan && $0.address == host }) {
                // Keep the manual identifier and nickname stable after multicast discovery.
                devices[index].model = model
                if devices[index].heads.count != DeviceCatalog.headCount(model: model) {
                    devices[index].heads = (0..<DeviceCatalog.headCount(model: model)).map { LightHeadState(id: $0) }
                    restoreHeads(at: index)
                }
                devices[index].isAvailable = true
                devices[index].lastSeen = Date()
            } else {
                var light = LightDevice(id: id, name: names[id] ?? DeviceCatalog.friendlyName(model: model) ?? "Govee \(model)", model: model, connection: .lan, address: host)
                light.isAvailable = true; light.lastSeen = Date()
                devices.append(light)
                restoreHeads(at: devices.count - 1)
                if selectedID == nil { selectedID = id }
            }
            Task { try? await lan.send(.status, to: host) }
        case .status(let state):
            guard let index = devices.firstIndex(where: { $0.address == host && $0.connection == .lan }) else { return }
            var reported = state
            if DeviceCatalog.hasModeOnlyColorReply(model: devices[index].model), state.color == RGB(0, 0, 0), state.temperature == 0 {
                reported.color = devices[index].state.color
            }
            devices[index].state = reported
            devices[index].hasKnownState = true
            devices[index].isAvailable = true
            devices[index].lastSeen = Date()
        }
    }

    private func discoveredBluetooth(id: String, name: String) {
        let key = "ble:\(id)"
        guard !devices.contains(where: { $0.id == key }) else { return }
        let range = name.range(of: "H[0-9A-F]{4}", options: .regularExpression)
        let model = range.map { String(name[$0]) } ?? "Govee BLE"
        devices.append(LightDevice(id: key, name: names[key] ?? DeviceCatalog.friendlyName(model: model) ?? name, model: model, connection: .bluetooth, address: id))
        restoreHeads(at: devices.count - 1)
        if selectedID == nil { selectedID = key }
    }

    func send(_ command: LightCommand, to id: String, debounce: Bool = false) {
        if case .color = command { cancelHeadEdits(to: id) }
        if case .temperature = command { cancelHeadEdits(to: id) }
        if case .head = command { debounceTasks["\(id):color"]?.cancel() }
        let key = "\(id):\(command.key)"
        debounceTasks[key]?.cancel()
        if debounce {
            debounceTasks[key] = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(160))
                guard !Task.isCancelled else { return }
                self?.enqueue([command], to: id)
            }
        } else { enqueue([command], to: id) }
    }

    private func enqueue(_ commands: [LightCommand], to id: String) {
        let previous = commandTails[id]
        commandTails[id] = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled else { return }
            self.busyIDs.insert(id)
            defer { self.busyIDs.remove(id) }
            for command in commands {
                guard await self.execute(command, to: id) else { return }
            }
            if let device = self.devices.first(where: { $0.id == id }), device.connection != .demo {
                try? await Task.sleep(for: .milliseconds(250))
                if device.connection == .lan { try? await self.lan.send(.status, to: device.address) }
                else { self.bluetooth.refresh(id: device.address) }
            }
        }
    }

    private func execute(_ command: LightCommand, to id: String) async -> Bool {
        guard let device = devices.first(where: { $0.id == id }), device.isAvailable else {
            errorMessage = "The light is unavailable. Discover it again or connect over Bluetooth."; return false
        }
        do {
            switch device.connection {
            case .lan: try await lan.send(command, to: device.address, model: device.model)
            case .bluetooth: try await bluetooth.send(command, to: device.address)
            case .demo: break
            }
            if let index = devices.firstIndex(where: { $0.id == id }) {
                devices[index].state = command.applying(to: devices[index].state)
                switch command {
                case .head(var head):
                    guard devices[index].heads.indices.contains(head.id) else { return false }
                    head.hasRequestedState = true
                    devices[index].heads[head.id] = head
                    persistHeads(for: devices[index])
                case .color(let color):
                    devices[index].heads = devices[index].heads.map {
                        LightHeadState(id: $0.id, color: color, hasRequestedState: true)
                    }
                    persistHeads(for: devices[index])
                case .temperature:
                    for headIndex in devices[index].heads.indices {
                        devices[index].heads[headIndex].hasRequestedState = false
                    }
                    persistHeads(for: devices[index])
                default: break
                }
                // Sending brightness/color cannot establish an unknown power state.
                if case .power = command { devices[index].hasKnownState = true }
                devices[index].lastSent = Date()
            }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func apply(_ preset: LightPreset, to id: String) {
        guard let device = devices.first(where: { $0.id == id }) else { return }
        // Cancel stale color edits so a delayed picker event cannot overwrite a preset.
        debounceTasks["\(id):color"]?.cancel()
        cancelHeadEdits(to: id)
        if let heads = preset.heads {
            guard !heads.isEmpty, heads.count == device.heads.count,
                  heads.map(\.id) == Array(device.heads.indices) else {
                errorMessage = "This look requires a lamp with three individually controlled heads."
                return
            }
            enqueue([.power(true), .brightness(preset.brightness)] + heads.map(LightCommand.head), to: id)
            return
        }
        let colorCommand: LightCommand = preset.temperature > 0 && device.supportsTemperature ? .temperature(preset.temperature) : .color(preset.color)
        enqueue([.power(true), .brightness(preset.brightness), colorCommand], to: id)
    }

    func setAllPower(_ on: Bool) {
        for device in devices where device.isAvailable { send(.power(on), to: device.id) }
    }

    func rename(_ id: String, to name: String) {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].name = label
        if devices[index].connection != .demo { names[id] = label; persistMetadata() }
    }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        persistMetadata()
    }

    func savePreset(name: String, device: LightDevice) {
        let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let heads = !device.heads.isEmpty && device.heads.allSatisfy(\.hasRequestedState) ? device.heads : nil
        customPresets.append(.init(name: label, color: device.state.color, brightness: device.state.brightness,
                                   temperature: device.state.temperature, heads: heads))
        persistPresets()
    }

    func deletePreset(_ id: String) { customPresets.removeAll { $0.id == id }; persistPresets() }

    private func cancelHeadEdits(to id: String) {
        for key in debounceTasks.keys where key.hasPrefix("\(id):head:") { debounceTasks[key]?.cancel() }
    }

    private func restoreHeads(at index: Int) {
        guard let heads = savedHeads[devices[index].id], !heads.isEmpty,
              heads.count == devices[index].heads.count,
              heads.map(\.id) == Array(devices[index].heads.indices) else { return }
        devices[index].heads = heads
    }

    private func persistHeads(for device: LightDevice) {
        guard !device.heads.isEmpty, device.connection != .demo else { return }
        savedHeads[device.id] = device.heads
        if let data = try? JSONEncoder().encode(savedHeads) { defaults.set(data, forKey: "headSettings") }
    }

    func remove(_ device: LightDevice) {
        if device.connection == .bluetooth { disconnect(device) }
        devices.removeAll { $0.id == device.id }
        if device.connection == .bluetooth {
            let records = (defaults.array(forKey: "rememberedBluetooth") as? [[String: String]] ?? []).filter { $0["uuid"] != device.address }
            defaults.set(records, forKey: "rememberedBluetooth")
        }
        if selectedID == device.id { selectedID = devices.first?.id }
        persistManualAddresses()
    }

    func enableDemo() {
        guard !isDemo else { return }
        isDemo = true
        for (id, name, model, color, brightness) in [
            ("demo:desk", "Desk light", "Demo light", RGB(36, 194, 174), 75),
            ("demo:corner", "Corner lamp", "Demo light", RGB(255, 159, 90), 40),
            ("demo:tree", "Tree lamp", "H60B2", RGB(36, 165, 255), 70)
        ] {
            var light = LightDevice(id: id, name: name, model: model, connection: .demo)
            light.isAvailable = true; light.hasKnownState = true
            light.state = LightState(isOn: true, brightness: brightness, color: color)
            if id == "demo:tree" {
                light.heads = [LightHeadState(id: 0, color: RGB(36, 165, 255), hasRequestedState: true),
                               LightHeadState(id: 1, color: RGB(73, 200, 133), brightness: 70, hasRequestedState: true),
                               LightHeadState(id: 2, color: RGB(174, 107, 255), hasRequestedState: true)]
            }
            devices.append(light)
        }
        selectedID = "demo:desk"
    }

    func disableDemo() {
        devices.removeAll { $0.connection == .demo }
        isDemo = false
        selectedID = devices.first?.id
    }

    private func persistMetadata() {
        defaults.set(names, forKey: "lightNames")
        defaults.set(Array(favorites.filter { !$0.hasPrefix("demo:") }), forKey: "favorites")
    }
    private func persistManualAddresses() {
        defaults.set(devices.filter { $0.id.hasPrefix("manual:") }.map(\.address), forKey: "manualAddresses")
    }
    private func persistPresets() {
        if let data = try? JSONEncoder().encode(customPresets) { defaults.set(data, forKey: "presets") }
    }
}
