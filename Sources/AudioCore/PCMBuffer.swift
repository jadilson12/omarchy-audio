import Foundation

public struct AudioStatistics {
    public let receivedFrames: UInt64
    public let playedFrames: UInt64
    public let queuedFrames: Int
    public let droppedFrames: UInt64
    public let peak: Float
    public let lastPacket: TimeInterval
}

/// Bounded stereo PCM queue. Old audio is discarded if the network catches up
/// in a burst, so a slow connection cannot accumulate minutes of playback delay.
public final class PCMBuffer {
    private let lock = NSLock()
    private var left: [Float]
    private var right: [Float]
    private let capacity: Int
    private let prebuffer: Int
    private var primed = false
    private var readIndex = 0
    private var count = 0
    private var pending = Data()
    private var received: UInt64 = 0
    private var played: UInt64 = 0
    private var dropped: UInt64 = 0
    private var peak: Float = 0
    private var lastPacket: TimeInterval = 0

    public init(capacity: Int = 24_000, prebuffer: Int = 0) {
        precondition(capacity > 0 && prebuffer >= 0 && prebuffer <= capacity)
        self.capacity = capacity
        self.prebuffer = prebuffer
        left = Array(repeating: 0, count: capacity)
        right = Array(repeating: 0, count: capacity)
    }

    public func receive(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        // SSH reads do not preserve sample or channel boundaries.
        pending.append(data)
        let frames = pending.count / 4
        guard frames > 0 else { return }
        var packetPeak: Float = 0
        pending.withUnsafeBytes { bytes in
            for frame in 0..<frames {
                let a = Int16(bitPattern: UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: frame * 4, as: UInt16.self)))
                let b = Int16(bitPattern: UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: frame * 4 + 2, as: UInt16.self)))
                let l = Float(a) / 32768
                let r = Float(b) / 32768
                if count == capacity {
                    readIndex = (readIndex + 1) % capacity
                    count -= 1
                    dropped += 1
                }
                let index = (readIndex + count) % capacity
                left[index] = l
                right[index] = r
                count += 1
                packetPeak = max(packetPeak, abs(l), abs(r))
            }
        }
        pending = Data(pending.suffix(pending.count - frames * 4))
        received += UInt64(frames)
        peak = packetPeak
        lastPacket = ProcessInfo.processInfo.systemUptime
    }

    /// The audio thread must never wait for a network writer to release its lock.
    public func render(left outputLeft: UnsafeMutablePointer<Float>, right outputRight: UnsafeMutablePointer<Float>, frames: Int) {
        outputLeft.update(repeating: 0, count: frames)
        outputRight.update(repeating: 0, count: frames)
        guard lock.try() else { return }
        defer { lock.unlock() }
        // A small initial cushion absorbs SSH packet timing without making the
        // render thread wait. Refill that cushion after a network underrun.
        if !primed {
            guard count >= prebuffer else { return }
            primed = true
        }
        let available = min(frames, count)
        for frame in 0..<available {
            let index = (readIndex + frame) % capacity
            outputLeft[frame] = left[index]
            outputRight[frame] = right[index]
        }
        readIndex = (readIndex + available) % capacity
        count -= available
        played += UInt64(available)
        if available < frames { primed = false }
    }

    public var statistics: AudioStatistics {
        lock.lock()
        defer { lock.unlock() }
        return AudioStatistics(receivedFrames: received, playedFrames: played,
                               queuedFrames: count, droppedFrames: dropped,
                               peak: peak, lastPacket: lastPacket)
    }
}

public enum SSHConnection {
    public static func validHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253, host.first != "-" else { return false }
        return host.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_@").contains($0)
        }
    }

    public static func arguments(host: String) -> [String] {
        ["-T", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
         "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
         "-o", "ControlMaster=no", "-o", "ControlPath=none", host,
         "sink=$(pactl get-default-sink) || exit; [ -n \"$sink\" ] || exit 1; exec parec --device=\"${sink}.monitor\" --raw --format=s16le --rate=48000 --channels=2 --latency-msec=50"]
    }
}
