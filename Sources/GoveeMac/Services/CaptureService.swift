import AVFoundation
import AppKit
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import GoveeKit

final class CaptureSink: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let onColors: @MainActor @Sendable ([RGB]) -> Void
    let onLevels: @MainActor @Sendable ([Double]) -> Void
    let onError: @MainActor @Sendable (String) -> Void
    let onFrame: @MainActor @Sendable (CGImage) -> Void
    let mapping: String
    let style: String
    private var lastVideo = 0.0
    private var lastAudio = 0.0
    private var bands = AudioBands()
    private var audioPeak = [0.0, 0.0, 0.0]
    init(mapping: String, onColors: @escaping @MainActor @Sendable ([RGB]) -> Void,
         onLevels: @escaping @MainActor @Sendable ([Double]) -> Void,
         onError: @escaping @MainActor @Sendable (String) -> Void,
         onFrame: @escaping @MainActor @Sendable (CGImage) -> Void = { _ in }, style: String = "vivid") {
        self.mapping = mapping; self.style = style; self.onColors = onColors; self.onLevels = onLevels; self.onError = onError; self.onFrame = onFrame
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in onError(message) }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sample.isValid else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if type == .screen, now-lastVideo >= 0.08, let pixel = sample.imageBuffer {
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let status = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: status) == .complete else { return }
            lastVideo = now
            CVPixelBufferLockBaseAddress(pixel, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixel, .readOnly) }
            guard let base = CVPixelBufferGetBaseAddress(pixel), CVPixelBufferGetPixelFormatType(pixel) == kCVPixelFormatType_32BGRA else { return }
            let width = CVPixelBufferGetWidth(pixel), height = CVPixelBufferGetHeight(pixel), stride = CVPixelBufferGetBytesPerRow(pixel)
            let bytes = Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: stride*height))
            guard let colors = ScreenColors.sample(bgra: bytes, width: width, height: height, rowBytes: stride, mapping: mapping, style: style) else { return }
            let provider = CGDataProvider(data: Data(bytes) as CFData)
            let image = provider.flatMap { CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: stride, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little),
                provider: $0, decode: nil, shouldInterpolate: true, intent: .defaultIntent) }
            Task { @MainActor in onColors(colors); if let image { onFrame(image) } }
        } else if type == .audio {
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
            consumeAudio(values, sampleRate: asbd.mSampleRate, now: now)
        }
    }
    func consumeAudio(_ values: [Float], sampleRate: Double, now: Double) {
        let levels = bands.levels(values, sampleRate: sampleRate)
        for i in 0..<3 { audioPeak[i] = max(audioPeak[i], levels[i]) }
        guard now - lastAudio >= 1.0 / 30 else { return }
        lastAudio = now
        let peak = audioPeak; audioPeak = [0, 0, 0]
        Task { @MainActor in onLevels(peak) }
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
        return identifiers.prefix(Int(count)).map { id in
            let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) == id }
            let name = screen?.localizedName ?? "Display \(id)"
            return CaptureDisplay(id: id, name: "\(name)\(id == CGMainDisplayID() ? " · Main" : "") · \(CGDisplayPixelsWide(id)) × \(CGDisplayPixelsHigh(id))")
        }
    }
    func start(screen: Bool, source: String, displayID: UInt32?, mapping: String, style: String,
               onColors: @escaping @MainActor @Sendable ([RGB]) -> Void,
               onLevels: @escaping @MainActor @Sendable ([Double]) -> Void,
               onError: @escaping @MainActor @Sendable (String) -> Void,
               onFrame: @escaping @MainActor @Sendable (CGImage) -> Void = { _ in }) async throws {
        if !screen && source == "microphone" {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            guard granted else { throw ControlError.message("Allow Microphone access for Govee Mac in System Settings → Privacy & Security.") }
            let engine = AVAudioEngine()
            let node = engine.inputNode, format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw ControlError.message("No microphone input is available.") }
            let sink = CaptureSink(mapping: mapping, onColors: onColors, onLevels: onLevels, onError: onError)
            let audioQueue = queue
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                guard let samples = buffer.floatChannelData?[0] else { return }
                let values = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
                audioQueue.async { sink.consumeAudio(values, sampleRate: format.sampleRate, now: ProcessInfo.processInfo.systemUptime) }
            }
            engine.prepare(); try engine.start(); microphone = engine; self.sink = sink
            return
        }
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else { throw ControlError.message("Allow Govee Mac in System Settings → Privacy & Security → Screen & System Audio Recording, then restart Govee Mac and retry.") }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = displayID.flatMap({ id in content.displays.first { $0.displayID == id } }) ?? (displayID == nil ? content.displays.first { $0.displayID == CGMainDisplayID() } ?? content.displays.first : nil) else {
            throw ControlError.message("The selected display is unavailable.")
        }
        // Match the visible screen. Excluding our window replaces it with the
        // often-dark windows behind it and makes the preview misleading.
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = 192; config.height = max(1, Int((192.0 * Double(display.height) / Double(display.width)).rounded()))
        config.scalesToFit = true
        config.colorSpaceName = CGColorSpace.sRGB
        config.minimumFrameInterval = CMTime(value: 1, timescale: screen ? 12 : 1)
        config.queueDepth = 3; config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.capturesAudio = !screen; config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 1
        let sink = CaptureSink(mapping: mapping, onColors: onColors, onLevels: onLevels, onError: onError, onFrame: onFrame, style: style)
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
