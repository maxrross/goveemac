import Foundation
import GoveeKit
import Observation

@Observable @MainActor final class LiveController {
    var mode = "Stopped"
    var deviceID: String?
    var isStarting = false
    var speed = 1.0
    var sensitivity = 2.0
    var source = "system"
    var mapping = "rows"
    var displayID: UInt32?
    var displays: [CaptureDisplay] = []
    var levels = [0.0,0.0,0.0]
    var preview = [RGB(0,0,0), RGB(0,0,0), RGB(0,0,0)]
    @ObservationIgnored weak var store: LightStore?
    @ObservationIgnored private var capture = CaptureService()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var snapshot: LightDevice?
    @ObservationIgnored private var sceneSnapshot: NativeScene?
    @ObservationIgnored private var pending: [RGB]?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var effect: LiveEffect?
    var isRunning: Bool { deviceID != nil }

    func refreshDisplays() async {
        do { displays = try await CaptureService.displays() }
        catch { store?.errorMessage = error.localizedDescription }
    }
    func start(mode: String, device: LightDevice, effect: LiveEffect? = nil) async throws {
        guard !isStarting else { throw ControlError.message("Capture is already starting.") }
        guard device.isAvailable else { throw ControlError.message("Connect the light before starting sync.") }
        isStarting = true; defer { isStarting = false }
        await stop(restore: false)
        let token = UUID(); generation = token
        snapshot = device; self.effect = effect
        sceneSnapshot = store?.scenes[device.model]?.first { $0.name == store?.activeScenes[device.id] }
        if mode == "Screen match" || mode == "Music" {
            do {
                try await capture.start(screen: mode == "Screen match", source: source, displayID: displayID, mapping: mapping,
                    onColors: { [weak self] colors in guard let self, self.generation == token else { return }; self.pending = colors },
                    onLevels: { [weak self] levels in guard let self, self.generation == token else { return }; self.levels = levels },
                    onError: { [weak self] message in
                        guard let self, self.generation == token else { return }
                        self.store?.errorMessage = message
                        Task { await self.stop(restore: true) }
                    })
            } catch { await capture.stop(); snapshot = nil; throw error }
        }
        guard generation == token else { await capture.stop(); throw CancellationError() }
        await store?.prepareForLive(to: device.id)
        guard await store?.perform([.power(true), .color(device.state.color)], to: device.id) == true else { await capture.stop(); throw ControlError.message("The light could not be started.") }
        deviceID = device.id; self.mode = mode
        let start = ProcessInfo.processInfo.systemUptime
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token else { return }
                let colors: [RGB]?
                if let effect { colors = LiveColors.effect(effect, time: ProcessInfo.processInfo.systemUptime-start, count: max(1,device.heads.count), speed: self.speed, color: device.state.color) }
                else if mode == "Music" {
                    let palette = [RGB(60,90,255), RGB(180,40,255), RGB(255,60,130)]
                    colors = (0..<3).map { i in
                        let target = min(1, self.levels[i]*self.sensitivity*10)
                        let value = LiveColors.scale(palette[i], target)
                        return LiveColors.mix(self.preview[i], value, amount: 0.65)
                    }
                } else { colors = self.pending; self.pending = nil }
                if let colors, !colors.isEmpty {
                    self.preview = colors.count == 1 ? Array(repeating: colors[0], count: 3) : colors
                    guard await self.store?.liveFrame(colors, to: device.id) == true else { Task { await self.stop(restore: false) }; return }
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }
    func stop(restore: Bool) async {
        generation = UUID(); loop?.cancel()
        let oldLoop = loop; loop = nil
        deviceID = nil; mode = "Stopped"; pending = nil
        await capture.stop()
        await oldLoop?.value
        if restore, let snapshot {
            let color: LightCommand = snapshot.state.temperature > 0 && snapshot.supportsTemperature ? .temperature(snapshot.state.temperature) : .color(snapshot.state.color)
            let commands: [LightCommand] = sceneSnapshot.map { [.brightness(snapshot.state.brightness), .scene($0), .power(snapshot.state.isOn)] } ?? (snapshot.heads.allSatisfy(\.hasRequestedState) && !snapshot.heads.isEmpty
                ? [.brightness(snapshot.state.brightness)] + snapshot.heads.map(LightCommand.head) + [.power(snapshot.state.isOn)]
                : [.brightness(snapshot.state.brightness), color, .power(snapshot.state.isOn)])
            _ = await store?.perform(commands, to: snapshot.id)
        }
        snapshot = nil; sceneSnapshot = nil; levels = [0,0,0]
    }
}
