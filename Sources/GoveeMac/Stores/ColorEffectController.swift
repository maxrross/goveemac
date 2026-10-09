import Foundation
import GoveeKit
import Observation

@Observable @MainActor final class ColorEffectController {
    var deviceID: String?
    var effect: ColorEffect?
    var speed = 1.0
    var baseBrightness = 100
    var outputBrightness = 100
    var isStarting = false
    @ObservationIgnored weak var store: LightStore?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    func start(_ effect: ColorEffect, device: LightDevice) async throws {
        guard !isStarting else { return }
        guard device.isAvailable else { throw ControlError.message("Connect the light before adding an effect.") }
        isStarting = true; defer { isStarting = false }
        let sameDevice = deviceID == device.id
        let ceiling = sameDevice ? baseBrightness : device.state.brightness
        if !sameDevice { await stop(restore: true) }
        let token = UUID(); generation = token
        await haltLoop()
        guard generation == token else { return }
        if !device.state.isOn {
            guard await store?.perform([.power(true)], to: device.id) == true else { throw ControlError.message("The light could not be turned on.") }
        }
        guard generation == token else { return }
        baseBrightness = ceiling; outputBrightness = ceiling
        deviceID = device.id; self.effect = effect
        let started = ProcessInfo.processInfo.systemUptime
        loop = Task { [weak self] in
            var lastValue: Int?
            while !Task.isCancelled {
                guard let self, self.generation == token else { return }
                let tick = ProcessInfo.processInfo.systemUptime
                let value = effect.brightness(time: tick - started, base: self.baseBrightness, speed: self.speed)
                if value != lastValue {
                    let sent = await self.store?.perform([.brightness(value)], to: device.id, persist: false, showsBusy: false)
                    guard self.generation == token, !Task.isCancelled else { return }
                    guard sent == true else {
                        Task { guard self.generation == token else { return }; await self.stop(restore: false) }
                        return
                    }
                    self.outputBrightness = value; lastValue = value
                }
                try? await Task.sleep(for: .seconds(max(0.005, 0.125 - (ProcessInfo.processInfo.systemUptime - tick))))
            }
        }
    }

    func stop(restore: Bool) async {
        let oldDevice = deviceID, ceiling = baseBrightness
        generation = UUID(); deviceID = nil; effect = nil
        await haltLoop()
        if restore, let oldDevice {
            _ = await store?.perform([.brightness(ceiling)], to: oldDevice)
        }
        outputBrightness = ceiling
    }

    private func haltLoop() async {
        loop?.cancel()
        let old = loop; loop = nil
        await old?.value
    }
}
