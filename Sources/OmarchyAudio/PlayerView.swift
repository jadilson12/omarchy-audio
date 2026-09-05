import SwiftUI

private let mint = Color(red: 0.36, green: 0.85, blue: 0.69)

struct PlayerView: View {
    @ObservedObject var controller: AudioController
    var inMenu = false

    private var statusColor: Color {
        switch controller.state {
        case .listening: return mint
        case .failed: return .orange
        case .connecting: return .yellow
        case .idle: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 11) {
                Image(systemName: "waveform")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(mint)
                    .frame(width: 42, height: 42)
                    .background(mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Omarchy Audio").font(.system(size: 17, weight: .semibold))
                    Text("Your Linux. Your sound. Your Mac.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    AppWindows.shared.showSettings()
                } label: { Image(systemName: "gearshape").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help("Connection settings").accessibilityLabel("Connection settings")
            }

            VStack(spacing: 20) {
                HStack(spacing: 7) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(controller.statusLabel).font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(statusColor.opacity(0.10), in: Capsule())

                HStack(spacing: 18) {
                    endpoint("desktopcomputer", name: "Omarchy", detail: controller.host)
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .medium)).foregroundStyle(mint.opacity(controller.active ? 1 : 0.35))
                    endpoint("headphones", name: "This Mac", detail: "Local audio")
                }

                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array(controller.levels.enumerated()), id: \.offset) { _, level in
                        Capsule()
                            .fill(mint.opacity(level > 0 ? 0.85 : 0.19))
                            .frame(width: 4, height: CGFloat(4 + level * 35))
                    }
                }
                .frame(height: 43)
                .animation(.easeOut(duration: 0.12), value: controller.levels)
                .accessibilityLabel(controller.signalPresent ? "Receiving audio signal" : "No audio signal")

                Text(controller.message)
                    .font(.system(size: 12))
                    .foregroundStyle(controller.state == .failed ? Color.orange : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.065)))

            Button(action: controller.toggle) {
                HStack(spacing: 9) {
                    if controller.state == .connecting {
                        ProgressView().controlSize(.small).tint(Color.black.opacity(0.8))
                    } else {
                        Image(systemName: controller.active ? "stop.fill" : "play.fill").font(.system(size: 12, weight: .bold))
                    }
                    Text(controller.active ? (controller.state == .connecting ? "Cancel connection" : "Disconnect") : "Listen to Omarchy")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.05, green: 0.16, blue: 0.12))
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(mint, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
            .accessibilityIdentifier("connectionButton")

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button { controller.muted.toggle() } label: {
                        Image(systemName: controller.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .frame(width: 19)
                    }
                    .buttonStyle(.plain).foregroundStyle(controller.muted ? .secondary : mint)
                    .help(controller.muted ? "Unmute" : "Mute")
                    .accessibilityLabel(controller.muted ? "Unmute" : "Mute")
                    Slider(value: $controller.volume, in: 0...1).tint(mint)
                        .accessibilityLabel("Playback volume")
                    Text("\(Int(controller.volume * 100))%")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
                HStack(spacing: 5) {
                    Text("Output:").foregroundStyle(.tertiary)
                    Text(controller.outputName).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button(action: controller.openSoundSettings) { Image(systemName: "arrow.up.right") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                        .help("Choose an output in Sound settings").accessibilityLabel("Choose audio output")
                }
                .font(.system(size: 10))
            }

            Divider().overlay(Color.white.opacity(0.03))
            HStack {
                Label(controller.state == .listening ? "Stereo · 48 kHz" : "SSH connection", systemImage: "lock.shield")
                Spacer()
                if controller.state == .listening {
                    Text(controller.duration).monospacedDigit()
                }
                if inMenu {
                    Button("Open") {
                        AppWindows.shared.showPlayer()
                    }.buttonStyle(.plain)
                }
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain)
                    .keyboardShortcut("q", modifiers: .command)
            }
            .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.top, inMenu ? 24 : 30).padding(.bottom, 20)
        .frame(width: 380)
        .background(Color(red: 0.065, green: 0.085, blue: 0.085))
        .preferredColorScheme(.dark)
    }

    private func endpoint(_ icon: String, name: String, detail: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.white.opacity(0.86)).frame(height: 37)
            Text(name).font(.system(size: 12, weight: .medium))
            Text(detail).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }.frame(width: 100)
    }
}

struct ConnectionSettings: View {
    @ObservedObject var controller: AudioController
    var body: some View {
        Form {
            Section("Connect to Omarchy") {
                TextField("SSH host", text: $controller.host)
                    .disabled(controller.active)
                Text("Use an SSH alias such as arch. The app uses the same key, user, and port as your Terminal connection.")
                    .font(.caption).foregroundStyle(.secondary)
                if !controller.hostIsValid {
                    Text("Enter an alias or user@host, without spaces.").font(.caption).foregroundStyle(.orange)
                }
                if controller.active {
                    Text("Disconnect audio before changing the host.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("How to listen") {
                Text("1. Click Listen to Omarchy.\n2. Play music or a video on Linux.\n3. Audio plays through your selected Mac output.")
                Text("If you change the audio output on Omarchy, disconnect and reconnect. Network streaming may add audio delay.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).padding(8).frame(width: 440, height: 430)
    }
}
