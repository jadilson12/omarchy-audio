import AppKit
import AVFoundation
import AudioCore
import Combine

@MainActor
final class AudioController: ObservableObject {
    static let shared = AudioController()
    enum State: Equatable { case idle, connecting, listening, failed }

    @Published private(set) var state: State = .idle
    @Published private(set) var message = "O som do Omarchy, aqui no seu Mac."
    @Published private(set) var levels = Array(repeating: Float(0), count: 36)
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var outputName = NativeAudio.outputName
    @Published private(set) var receivedFrames: UInt64 = 0
    @Published private(set) var playedFrames: UInt64 = 0
    private(set) var droppedFrames: UInt64 = 0
    @Published private(set) var signalPresent = false
    @Published var host: String {
        didSet { UserDefaults.standard.set(host, forKey: "sshHost") }
    }
    @Published var volume: Double {
        didSet {
            UserDefaults.standard.set(volume, forKey: "volume")
            player?.engine.mainMixerNode.outputVolume = muted ? 0 : Float(volume)
        }
    }
    @Published var muted = false {
        didSet { player?.engine.mainMixerNode.outputVolume = muted ? 0 : Float(volume) }
    }

    private var player: NativeAudio?
    private var process: Process?
    private var audioPipe: Pipe?
    private var errorPipe: Pipe?
    private var timer: Timer?
    private var session: UUID?
    private var startedAt: TimeInterval = 0
    private var lastSignalAt: TimeInterval = 0
    private var configurationObserver: NSObjectProtocol?

    private init() {
        host = UserDefaults.standard.string(forKey: "sshHost") ?? "arch"
        volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.75
    }

    var active: Bool { state == .connecting || state == .listening }
    var hostIsValid: Bool { SSHConnection.validHost(host.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var statusLabel: String {
        switch state {
        case .idle: return "Pronto para conectar"
        case .connecting: return "Conectando…"
        case .listening: return "Conectado"
        case .failed: return "Conexão interrompida"
        }
    }
    var duration: String {
        let seconds = Int(elapsed)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func toggle() { active ? disconnect() : connect() }

    func connect() {
        guard !active else { return }
        let destination = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SSHConnection.validHost(destination) else {
            state = .failed
            message = "Informe um alias SSH válido, como arch, ou usuário@host."
            return
        }
        host = destination
        state = .connecting
        message = "Abrindo a conexão com \(destination)…"
        elapsed = 0
        receivedFrames = 0
        playedFrames = 0
        droppedFrames = 0
        levels = Array(repeating: 0, count: 36)
        let id = UUID()
        session = id
        startedAt = ProcessInfo.processInfo.systemUptime
        lastSignalAt = 0
        let native = NativeAudio()
        player = native
        do {
            try native.start(volume: muted ? 0 : Float(volume))
            let process = Process()
            let audio = Pipe()
            let errors = Pipe()
            let errorBuffer = ErrorBuffer()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = SSHConnection.arguments(host: destination)
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = audio
            process.standardError = errors
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
            audio.fileHandleForReading.readabilityHandler = { handle in
                // FileHandle can wait for the requested count. A 4 KB read is
                // only 21 ms of PCM; 64 KB would introduce bursts and dropouts.
                if let data = try? handle.read(upToCount: 4096), !data.isEmpty {
                    native.buffer.receive(data)
                } else { handle.readabilityHandler = nil }
            }
            errors.fileHandleForReading.readabilityHandler = { handle in
                if let data = try? handle.read(upToCount: 4096), !data.isEmpty {
                    errorBuffer.append(data)
                } else { handle.readabilityHandler = nil }
            }
            process.terminationHandler = { _ in
                Task { @MainActor [weak self] in
                    guard let self, self.session == id else { return }
                    let detail = errorBuffer.text
                    self.fail(detail.isEmpty ? "O Omarchy encerrou a transmissão. Tente conectar novamente." : Self.friendlyError(detail))
                }
            }
            self.process = process
            audioPipe = audio
            errorPipe = errors
            try process.run()
            // Closing the parent's write ends lets the readers observe remote EOF.
            try? audio.fileHandleForWriting.close()
            try? errors.fileHandleForWriting.close()
            outputName = NativeAudio.outputName
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: native.engine, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.session == id else { return }
                    do {
                        try self.player?.engine.start()
                        self.outputName = NativeAudio.outputName
                    } catch { self.fail("A saída de áudio mudou. Conecte novamente: \(error.localizedDescription)") }
                }
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        } catch { fail("Não foi possível iniciar: \(error.localizedDescription)") }
    }

    func disconnect() {
        tearDown()
        state = .idle
        message = "O som do Omarchy, aqui no seu Mac."
        levels = Array(repeating: 0, count: 36)
        signalPresent = false
        elapsed = 0
    }

    private func fail(_ message: String) {
        tearDown()
        state = .failed
        self.message = message
        levels = Array(repeating: 0, count: 36)
        signalPresent = false
    }

    private func tearDown() {
        session = nil
        timer?.invalidate()
        timer = nil
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        audioPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        if let process, process.isRunning {
            process.terminate()
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        process = nil
        player?.stop()
        player = nil
        audioPipe = nil
        errorPipe = nil
    }

    private func refresh() {
        guard let player, active else { return }
        let stats = player.buffer.statistics
        let now = ProcessInfo.processInfo.systemUptime
        receivedFrames = stats.receivedFrames
        playedFrames = stats.playedFrames
        droppedFrames = stats.droppedFrames
        if stats.receivedFrames > 0 {
            state = .listening
            elapsed = now - startedAt
            let hasSignal = stats.peak > 0.001 && now - stats.lastPacket < 1
            if hasSignal { lastSignalAt = now }
            signalPresent = now - lastSignalAt < 1.5
            message = signalPresent ? "Reproduzindo a saída de áudio do Omarchy." : "Conectado. Coloque algo para tocar no Omarchy."
            let level = hasSignal ? max(0, min(1, (20 * log10(max(stats.peak, 0.0001)) + 55) / 55)) : 0
            levels.removeFirst()
            levels.append(level)
            if now - stats.lastPacket > 10 { fail("A transmissão parou de enviar áudio. Verifique a rede e tente novamente.") }
        } else if now - startedAt > 15 {
            fail("O Omarchy não enviou áudio. Confira se o PipeWire está ativo e se o SSH conecta sem pedir senha.")
        }
    }

    private static func friendlyError(_ error: String) -> String {
        if error.contains("Permission denied") {
            return "O SSH não autorizou a conexão. Teste ssh arch no Terminal e confira a chave de acesso."
        }
        if error.contains("Host key verification failed") {
            return "Confirme a identidade deste host pelo Terminal antes de conectar pelo app."
        }
        if error.contains("Could not resolve") || error.contains("Connection refused") || error.contains("timed out") || error.contains("No route to host") {
            return "Não foi possível alcançar o Omarchy. Confira se a máquina está ligada e acessível pela rede."
        }
        if error.contains("not found") { return "O Omarchy precisa dos comandos pactl e parec instalados para transmitir o áudio." }
        return String(error.prefix(500))
    }

    func openSoundSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") { NSWorkspace.shared.open(url) }
    }
}
