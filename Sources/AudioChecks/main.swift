import AudioCore
import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ description: String) {
    guard condition() else {
        print("FAIL: \(description)")
        exit(1)
    }
    checks += 1
    print("PASS: \(description)")
}

func pcm(_ samples: [Int16]) -> Data {
    var data = Data()
    for sample in samples {
        let bits = UInt16(bitPattern: sample)
        data.append(UInt8(bits & 255))
        data.append(UInt8(bits >> 8))
    }
    return data
}

func read(_ buffer: PCMBuffer, frames: Int) -> ([Float], [Float]) {
    var left = Array(repeating: Float(99), count: frames)
    var right = left
    left.withUnsafeMutableBufferPointer { l in
        right.withUnsafeMutableBufferPointer { r in
            buffer.render(left: l.baseAddress!, right: r.baseAddress!, frames: frames)
        }
    }
    return (left, right)
}

let fragmented = PCMBuffer()
let input = pcm([Int16.min, Int16.max, 16384, -16384])
fragmented.receive(input.prefix(3))
check(fragmented.statistics.receivedFrames == 0, "incomplete stereo frame waits for the next packet")
fragmented.receive(Data(input.dropFirst(3).prefix(2)))
check(fragmented.statistics.receivedFrames == 1, "packet completes exactly one frame")
fragmented.receive(Data(input.dropFirst(5)))
let channels = read(fragmented, frames: 3)
check(channels.0 == [-1, 0.5, 0], "left channel preserves signed PCM and fills underflow with silence")
check(channels.1 == [Float(Int16.max) / 32768, -0.5, 0], "right channel preserves stereo ordering")
check(fragmented.statistics.playedFrames == 2, "render statistics count real frames, excluding underrun silence")

let bounded = PCMBuffer(capacity: 2)
bounded.receive(pcm([100, 200, 300, 400, 500, 600]))
check(bounded.statistics.queuedFrames == 2 && bounded.statistics.droppedFrames == 1, "overflow discards oldest audio and bounds latency")
let newest = read(bounded, frames: 2)
check(newest.0 == [Float(300) / 32768, Float(500) / 32768], "overflow keeps newest frames in order")
bounded.receive(pcm([700, 800]))
check(read(bounded, frames: 1).1 == [Float(800) / 32768], "ring wraps and can be refilled after draining")

let silent = PCMBuffer()
silent.receive(Data(repeating: 0, count: 1920))
check(silent.statistics.receivedFrames == 480 && silent.statistics.peak == 0 && silent.statistics.lastPacket > 0,
      "silent remote output still establishes a live transport")

let jitter = PCMBuffer(capacity: 8, prebuffer: 2)
jitter.receive(pcm([100, 200]))
check(read(jitter, frames: 1).0 == [0] && jitter.statistics.queuedFrames == 1, "jitter buffer waits without consuming the initial cushion")
jitter.receive(pcm([300, 400]))
check(read(jitter, frames: 3).0 == [Float(100) / 32768, Float(300) / 32768, 0], "primed jitter buffer renders in order and fills underrun")
jitter.receive(pcm([500, 600]))
check(read(jitter, frames: 1).0 == [0] && jitter.statistics.queuedFrames == 1, "network underrun rearms prebuffering")

check(SSHConnection.validHost("arch") && SSHConnection.validHost("user@example.com"), "SSH alias and user@host accepted")
check(!SSHConnection.validHost("-oProxyCommand=bad") && !SSHConnection.validHost("arch; echo bad") && !SSHConnection.validHost(""),
      "option and shell injection rejected in host field")
let arguments = SSHConnection.arguments(host: "arch")
check(arguments.contains("BatchMode=yes") && arguments.contains("ControlPath=none") && arguments[arguments.count - 2] == "arch",
      "dedicated SSH transport uses existing config without password prompts")

// Exercise producer and consumer together; all received frames must be either
// played, dropped by the bounded queue, or still queued.
let concurrent = PCMBuffer(capacity: 256)
let group = DispatchGroup()
group.enter()
DispatchQueue.global().async {
    for _ in 0..<2000 { concurrent.receive(Data(repeating: 0, count: 128)) }
    group.leave()
}
group.enter()
DispatchQueue.global().async {
    for _ in 0..<2000 { _ = read(concurrent, frames: 32) }
    group.leave()
}
group.wait()
let stats = concurrent.statistics
check(stats.receivedFrames == 64_000 && stats.receivedFrames == stats.playedFrames + stats.droppedFrames + UInt64(stats.queuedFrames),
      "concurrent capture and render preserve frame accounting")
print("\(checks) checks passed.")
