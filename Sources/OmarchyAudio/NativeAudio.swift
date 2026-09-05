import AVFoundation
import AudioCore
import CoreAudio

final class NativeAudio {
    let buffer = PCMBuffer(capacity: 24_000, prebuffer: 4_800)
    let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?

    func start(volume: Float) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = self.buffer
        let node = AVAudioSourceNode(format: format) { _, _, frames, audio in
            let buffers = UnsafeMutableAudioBufferListPointer(audio)
            guard buffers.count >= 2,
                  let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            buffer.render(left: left, right: right, frames: Int(frames))
            return noErr
        }
        source = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = volume
        engine.prepare()
        try engine.start()
    }

    func stop() { engine.stop() }

    static var outputName: String {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else {
            return "Default macOS output"
        }
        address.mSelector = kAudioObjectPropertyName
        var name: CFString = "" as CFString
        size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(device, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else {
            return "Default macOS output"
        }
        return name as String
    }
}

final class ErrorBuffer {
    private let lock = NSLock()
    private var data = Data()
    func append(_ part: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(part)
        if data.count > 4096 { data = Data(data.suffix(4096)) }
    }
    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
