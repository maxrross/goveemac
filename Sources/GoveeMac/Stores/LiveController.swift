import Foundation
import GoveeKit
import Observation
import AppKit

@Observable @MainActor final class LiveController {
    var mode = "Stopped"
    var deviceID: String?
    var isStarting = false
    var speed = 1.0
    var sensitivity = 2.0
    var source = "system"
    var mapping = "rows"
    var screenStyle = "vivid"
    var displayID: UInt32?
    var displays: [CaptureDisplay] = []
    var levels = [0.0,0.0,0.0]
    var preview = [RGB(0,0,0), RGB(0,0,0), RGB(0,0,0)]
    var hasCaptureInput = false
    var captureStatus = "Ready"
    var outputFPS = 0.0
    var beatCount = 0
    var screenImage: NSImage?
    @ObservationIgnored weak var store: LightStore?
    @ObservationIgnored private var capture = CaptureService()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var snapshot: LightDevice?
    @ObservationIgnored private var sceneSnapshot: NativeScene?
    @ObservationIgnored private var pending: [RGB]?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var effect: LiveEffect?
    @ObservationIgnored private var musicResponse = MusicResponse()
    @ObservationIgnored private var lastAudio = 0.0
    @ObservationIgnored private var lastOutput = 0.0
    var isRunning: Bool { deviceID != nil }

    func refreshDisplays() async {
        do { displays = try await CaptureService.displays() }
        catch { store?.errorMessage = error.localizedDescription }
    }
    func start(mode: String, device: LightDevice, effect: LiveEffect? = nil) async throws {
        guard !isStarting else { throw ControlError.message("Capture is already starting.") }
        guard device.isAvailable else { throw ControlError.message("Connect the light before starting sync.") }
        isStarting = true; defer { isStarting = false }
        let continuingSession = deviceID == device.id
        let previousLook = deviceID == device.id ? snapshot : nil
        let previousScene = deviceID == device.id ? sceneSnapshot : nil
        let token = UUID(); generation = token
        // Tear down the old transport without publishing a false "Stopped"
        // state. The active mode stays visible until its replacement is ready.
        await stopTransport()
        guard generation == token else { throw CancellationError() }
        snapshot = previousLook ?? device; self.effect = effect
        hasCaptureInput = false; captureStatus = "Waiting for capture…"; outputFPS = 0
        if !continuingSession || self.mode != mode { screenImage = nil }
        musicResponse = MusicResponse(); beatCount = 0; lastAudio = 0; lastOutput = 0
        sceneSnapshot = previousScene ?? store?.scenes[device.model]?.first { $0.name == store?.activeScenes[device.id] }
        do {
            if mode == "Screen match" || mode == "Music" {
                try await capture.start(screen: mode == "Screen match", source: source, displayID: displayID, mapping: mapping, style: screenStyle,
                    onColors: { [weak self] colors in
                        guard let self, self.generation == token else { return }
                        self.pending = colors; self.hasCaptureInput = true; self.captureStatus = "Receiving screen colors"
                    },
                    onLevels: { [weak self] levels in
                        guard let self, self.generation == token else { return }
                        self.levels = levels; self.lastAudio = ProcessInfo.processInfo.systemUptime; self.hasCaptureInput = true
                        self.pending = self.musicResponse.update(levels: levels, time: self.lastAudio, sensitivity: self.sensitivity)
                        self.beatCount = self.musicResponse.beatCount
                        self.captureStatus = (levels.max() ?? 0) > 0.0003 ? "Receiving audio · \(self.beatCount) beats" : "No audio detected — play audio or choose another source"
                    },
                    onError: { [weak self] message in
                        guard let self, self.generation == token else { return }
                        self.store?.errorMessage = message
                        Task { guard self.generation == token else { return }; await self.stop(restore: true) }
                    }, onFrame: { [weak self] image in
                        guard let self, self.generation == token else { return }
                        self.screenImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    })
            }
            guard generation == token else { throw CancellationError() }
            await store?.prepareForLive(to: device.id)
            guard generation == token else { throw CancellationError() }
            if !continuingSession {
                guard await store?.perform([.power(true), .color(device.state.color)], to: device.id) == true else { throw ControlError.message("The light could not be started.") }
            }
            guard generation == token else { throw CancellationError() }
            deviceID = device.id; self.mode = mode
            let start = ProcessInfo.processInfo.systemUptime
            loop = Task { [weak self] in
                while !Task.isCancelled {
                    guard let self, self.generation == token else { return }
                    let tick = ProcessInfo.processInfo.systemUptime
                    let colors: [RGB]?
                    if let effect { colors = LiveColors.effect(effect, time: ProcessInfo.processInfo.systemUptime-start, count: max(1,device.heads.count), speed: self.speed, color: device.state.color) }
                    else if mode == "Music" {
                        if tick - self.lastAudio > 0.15 {
                            self.levels = [0, 0, 0]
                            colors = self.musicResponse.update(levels: self.levels, time: tick, sensitivity: self.sensitivity)
                            self.captureStatus = self.hasCaptureInput ? "No audio detected — play audio or choose another source" : "Waiting for audio…"
                        } else {
                            colors = self.pending ?? self.musicResponse.colors
                        }
                    } else { colors = self.pending; self.pending = nil }
                    if let colors, !colors.isEmpty {
                        self.preview = colors.count == 1 ? Array(repeating: colors[0], count: 3) : colors
                        let delivered = await self.store?.liveFrame(colors, to: device.id)
                        guard self.generation == token, !Task.isCancelled else { return }
                        guard delivered == true else {
                            Task { guard self.generation == token else { return }; await self.stop(restore: false) }
                            return
                        }
                        let sent = ProcessInfo.processInfo.systemUptime
                        if self.lastOutput > 0 { self.outputFPS = 1 / max(0.001, sent - self.lastOutput) }
                        self.lastOutput = sent
                    }
                    let remaining = max(0.005, 0.125 - (ProcessInfo.processInfo.systemUptime - tick))
                    try? await Task.sleep(for: .seconds(remaining))
                }
            }
        } catch {
            // An explicit Stop may already have restored the original look.
            // Only clean up when this start still owns the transport.
            if generation == token {
                await stop(restore: false)
            } else {
                await capture.stop()
            }
            throw error
        }
    }
    func stop(restore: Bool) async {
        generation = UUID()
        deviceID = nil; mode = "Stopped"; pending = nil
        hasCaptureInput = false; captureStatus = "Ready"; outputFPS = 0; screenImage = nil
        await stopTransport()
        if restore, let snapshot {
            let color: LightCommand = snapshot.state.temperature > 0 && snapshot.supportsTemperature ? .temperature(snapshot.state.temperature) : .color(snapshot.state.color)
            let commands: [LightCommand] = sceneSnapshot.map { [.brightness(snapshot.state.brightness), .scene($0), .power(snapshot.state.isOn)] } ?? (snapshot.heads.allSatisfy(\.hasRequestedState) && !snapshot.heads.isEmpty
                ? [.brightness(snapshot.state.brightness)] + snapshot.heads.map(LightCommand.head) + [.power(snapshot.state.isOn)]
                : [.brightness(snapshot.state.brightness), color, .power(snapshot.state.isOn)])
            _ = await store?.perform(commands, to: snapshot.id)
        }
        snapshot = nil; sceneSnapshot = nil; levels = [0,0,0]
    }

    private func stopTransport() async {
        loop?.cancel()
        let oldLoop = loop; loop = nil; pending = nil
        await capture.stop()
        await oldLoop?.value
    }
}
