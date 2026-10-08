import AVFoundation
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import GoveeKit

final class CaptureSink: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let onColors: @MainActor @Sendable ([RGB]) -> Void
    let onLevels: @MainActor @Sendable ([Double]) -> Void
    let onError: @MainActor @Sendable (String) -> Void
    let mapping: String
    private var lastVideo = 0.0
    private var lastAudio = 0.0
    init(mapping: String, onColors: @escaping @MainActor @Sendable ([RGB]) -> Void,
         onLevels: @escaping @MainActor @Sendable ([Double]) -> Void,
         onError: @escaping @MainActor @Sendable (String) -> Void) {
        self.mapping = mapping; self.onColors = onColors; self.onLevels = onLevels; self.onError = onError
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in onError(message) }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sample.isValid else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if type == .screen, now-lastVideo >= 0.15, let pixel = sample.imageBuffer {
            lastVideo = now
            CVPixelBufferLockBaseAddress(pixel, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
            guard let base = CVPixelBufferGetBaseAddress(pixel), CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_32BGRA else { return }
            let width = CVPixelBufferGetWidth(pixel), height = CVPixelBufferGetHeight(pixel), stride = CVPixelBufferGetBytesPerRow(pixel)
            let bytes = Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: stride*height))
            guard let colors = ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: stride, mapping: mapping) else { return }
            Task { @MainActor in onColors(colors) }
        } else if type == .audio, now-lastAudio >= 0.08 {
            lastAudio = now
            guard let format = sample.formatDescription,
                  let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
                  asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0, asbd.mBitsPerChannel == 32,
                  let block = sample.dataBuffer else { return }
            var length = 0, pointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer) == noErr,
                  let pointer else { return }
            let interleaved = asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0
            let channelStride = interleaved ? max(1,Int(asbd.mChannelsPerFrame)) : 1
            let count = min(sample.numSamples, length/4/channelStride)
            let floats = UnsafeRawPointer(pointer).assumingMemoryBound(to: Float.self)
            let values = (0..<count).map { floats[$0*channelStride] }
            let levels = LiveColors.audioLevels(values, sampleRate: asbd.mSampleRate)
            Task { @MainActor in onLevels(levels) }
        }
    }
}

@MainActor final class CaptureService {
    private var stream: SCStream?
    private var sink: CaptureSink?
    private var microphone: AVAudioEngine?
    private let queue = DispatchQueue(label: "community.goveemac.capture", qos: .userInitiated)
    static func displays() async throws -> [CaptureDisplay] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { throw ControlError.message("Could not enumerate displays.") }
        var identifiers = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { throw ControlError.message("Could not enumerate displays.") }
        return identifiers.prefix(Int(count)).map { id in CaptureDisplay(id: id, name: "Display \(id) · \(CGDisplayPixelsWide(id)) × \(CGDisplayPixelsHigh(id))") }
    }
    func start(screen: Bool, source: String, displayID: UInt32?, mapping: String,
               onColors: @escaping @MainActor @Sendable ([RGB]) -> Void,
               onLevels: @escaping @MainActor @Sendable ([Double]) -> Void,
               onError: @escaping @MainActor @Sendable (String) -> Void) async throws {
        if !screen && source == "microphone" {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else { throw ControlError.message("Allow Microphone access for Govee Mac in System Settings → Privacy & Security.") }
            let engine = AVAudioEngine()
            let node = engine.inputNode, format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw ControlError.message("No microphone input is available.") }
            node.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
                guard let samples = buffer.floatChannelData?[0] else { return }
                let values = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
                let levels = LiveColors.audioLevels(values, sampleRate: format.sampleRate)
                Task { @MainActor in onLevels(levels) }
            }
            engine.prepare(); try engine.start(); microphone = engine
            return
        }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { throw ControlError.message("Allow Govee Mac in System Settings → Privacy & Security → Screen & System Audio Recording, then restart Govee Mac and retry.") }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = displayID.flatMap({ id in content.displays.first { $0.displayID == id } }) ?? (displayID == nil ? content.displays.first : nil) else {
            throw ControlError.message("The selected display is unavailable.")
        }
        let excluded = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: excluded, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = 144; config.height = 90
        config.minimumFrameInterval = CMTime(value: 1, timescale: screen ? 5 : 1)
        config.queueDepth = 3; config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = !screen; config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 1
        let sink = CaptureSink(mapping: mapping, onColors: onColors, onLevels: onLevels, onError: onError)
        let stream = SCStream(filter: filter, configuration: config, delegate: sink)
        try stream.addStreamOutput(sink, type: screen ? .screen : .audio, sampleHandlerQueue: queue)
        self.sink = sink; self.stream = stream
        try await stream.startCapture()
    }
    func stop() async {
        if let microphone { microphone.inputNode.removeTap(onBus: 0); microphone.stop() }
        microphone = nil
        let oldStream = stream; stream = nil; sink = nil
        try? await oldStream?.stopCapture()
    }
}
