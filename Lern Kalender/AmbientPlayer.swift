import Foundation
import AVFoundation
import SwiftUI

// MARK: - Ambient Player
//
// Spielt Hintergrund-Sound während des Lerntimers. Für die "richtigen"
// Sounds nutzen wir kuratierte SomaFM-Streams (royalty-free Internet-
// Radio); zusätzlich gibt's Brown-Noise und Regen, die wir lokal
// synthetisieren und auch offline funktionieren.

@MainActor
@Observable
final class AmbientPlayer {
    static let shared = AmbientPlayer()

    enum Sound: String, CaseIterable, Identifiable {
        case off = "Aus"
        case lofi = "Lo-Fi Beats"
        case ambient = "Ambient"
        case deepSpace = "Deep Space"
        case lush = "Lush"
        case brown = "Brown Noise"
        case rain = "Regen"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .off: return "speaker.slash"
            case .lofi: return "music.note"
            case .ambient: return "circle.hexagongrid.fill"
            case .deepSpace: return "moon.stars.fill"
            case .lush: return "leaf.fill"
            case .brown: return "waveform"
            case .rain: return "cloud.rain.fill"
            }
        }

        var subtitle: String {
            switch self {
            case .off: return ""
            case .lofi: return "SomaFM · Groove Salad"
            case .ambient: return "SomaFM · Drone Zone"
            case .deepSpace: return "SomaFM · Deep Space One"
            case .lush: return "SomaFM · Lush"
            case .brown: return "Lokal, ohne Internet"
            case .rain: return "Lokal, ohne Internet"
            }
        }

        var streamURL: URL? {
            switch self {
            case .lofi: return URL(string: "https://ice2.somafm.com/groovesalad-128-mp3")
            case .ambient: return URL(string: "https://ice2.somafm.com/dronezone-128-mp3")
            case .deepSpace: return URL(string: "https://ice2.somafm.com/deepspaceone-128-mp3")
            case .lush: return URL(string: "https://ice2.somafm.com/lush-128-mp3")
            default: return nil
            }
        }

        var isSynthesized: Bool {
            self == .brown || self == .rain
        }
    }

    var sound: Sound = .off
    var volume: Float = 0.5 {
        didSet {
            player?.volume = volume
            engineMixer?.outputVolume = volume
        }
    }

    /// Wird true, sobald ein Stream tatsächlich Audio liefert.
    var isLoading: Bool = false
    var lastError: String?

    // Stream-Pfad
    private var player: AVPlayer?

    // Synthese-Pfad
    private let engine = AVAudioEngine()
    private weak var engineMixer: AVAudioMixerNode?
    private var source: AVAudioSourceNode?
    private var brownLast: Float = 0
    private var phase: Float = 0
    private var noiseBuf: [Float] = Array(repeating: 0, count: 64)
    private var noiseIdx: Int = 0

    func play(_ sound: Sound) {
        stop(silent: true)
        guard sound != .off else { self.sound = .off; return }
        self.sound = sound
        lastError = nil

        configureSession()

        if sound.isSynthesized {
            startSynthesis(sound)
        } else if let url = sound.streamURL {
            startStream(url: url)
        }
    }

    func stop(silent: Bool = false) {
        player?.pause()
        player = nil

        if let s = source {
            engine.detach(s)
            source = nil
        }
        if engine.isRunning { engine.stop() }
        engineMixer = nil

        isLoading = false
        if !silent {
            sound = .off
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            lastError = "Audio konnte nicht starten."
        }
    }

    // MARK: Streaming

    private func startStream(url: URL) {
        isLoading = true
        let p = AVPlayer(url: url)
        p.volume = volume
        p.automaticallyWaitsToMinimizeStalling = true
        p.play()
        player = p
        // Loading-Flag zurücksetzen, sobald der Player Items hat
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { self?.isLoading = false }
        }
    }

    // MARK: Synthese

    private func startSynthesis(_ sound: Sound) {
        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)
        let mixer = engine.mainMixerNode
        mixer.outputVolume = volume

        let src = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = self.nextSample(sampleRate: sampleRate)
                for buffer in buffers {
                    let buf = buffer.mData!.assumingMemoryBound(to: Float.self)
                    buf[frame] = value
                }
            }
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: mixer, format: format)
        do {
            try engine.start()
            source = src
            engineMixer = mixer
        } catch {
            lastError = "Synthese konnte nicht starten."
        }
    }

    private func nextSample(sampleRate: Float) -> Float {
        let white = Float.random(in: -1...1)
        switch sound {
        case .brown:
            brownLast += white * 0.02
            brownLast = max(-1, min(1, brownLast))
            return brownLast * 3.5
        case .rain:
            noiseBuf[noiseIdx] = white
            noiseIdx = (noiseIdx + 1) % noiseBuf.count
            let avg = noiseBuf.reduce(0, +) / Float(noiseBuf.count)
            phase += 1 / sampleRate
            let mod = (sin(phase * 0.7) * 0.15 + 0.85)
            return avg * 1.6 * mod
        default:
            return 0
        }
    }
}

// MARK: - Player UI

struct AmbientPlayerBar: View {
    @Bindable private var player = AmbientPlayer.shared

    private var isPlaying: Bool { player.sound != .off }

    /// Hintergrund-Farbpalette pro Sound
    private func gradient(for sound: AmbientPlayer.Sound) -> [Color] {
        switch sound {
        case .off: return [.gray, .gray.opacity(0.6)]
        case .lofi: return [Color(red: 0.91, green: 0.43, blue: 0.49), Color(red: 0.55, green: 0.20, blue: 0.45)]
        case .ambient: return [.indigo, .purple]
        case .deepSpace: return [Color(red: 0.10, green: 0.05, blue: 0.35), .blue]
        case .lush: return [.green, .teal]
        case .brown: return [.brown, .orange]
        case .rain: return [.blue, .indigo]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // "Now Playing"-Header mit animiertem Visualizer
            HStack(spacing: 12) {
                ZStack {
                    if isPlaying {
                        SoundVisualizer(color: gradient(for: player.sound).first ?? .blue)
                            .frame(width: 28, height: 22)
                    } else {
                        Image(systemName: "speaker.slash.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 22)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(isPlaying ? "Läuft" : "Stille")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(player.sound.rawValue)
                        .font(.subheadline.bold())
                        .contentTransition(.opacity)
                }
                Spacer()
                if isPlaying {
                    Button {
                        player.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.red.gradient, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sound-Tiles als großes Grid
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                ForEach(AmbientPlayer.Sound.allCases.filter { $0 != .off }) { sound in
                    soundTile(sound)
                }
            }

            // Volume — nur sichtbar wenn etwas läuft
            if isPlaying {
                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: Binding(
                        get: { Double(player.volume) },
                        set: { player.volume = Float($0) }
                    ), in: 0...1)
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(14)
        .background(
            ZStack {
                Color(.secondarySystemGroupedBackground)
                if isPlaying {
                    LinearGradient(
                        colors: gradient(for: player.sound).map { $0.opacity(0.10) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.sound)
    }

    private func soundTile(_ sound: AmbientPlayer.Sound) -> some View {
        let isSelected = player.sound == sound
        let colors = gradient(for: sound)
        return Button {
            if isSelected {
                player.stop()
            } else {
                player.play(sound)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: sound.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        LinearGradient(colors: colors,
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: colors.first?.opacity(0.35) ?? .clear, radius: 4, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(sound.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(sound.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isSelected {
                    if player.isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "waveform")
                            .font(.caption.bold())
                            .foregroundStyle(colors.first ?? .blue)
                            .symbolEffect(.variableColor.iterative.reversing)
                    }
                }
            }
            .padding(10)
            .background(
                Color(.tertiarySystemFill),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                        ? AnyShapeStyle(LinearGradient(colors: colors,
                                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Color.clear),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// Mini-Sound-Visualizer: 4 animierte Balken (TimelineView).
struct SoundVisualizer: View {
    var color: Color = .blue
    private let bars = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let seed = Double(i)
                    let raw = sin(t * 4 + seed * 1.7) * 0.5 + 0.5
                    let h = CGFloat(0.3 + raw * 0.7)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3)
                        .scaleEffect(y: h, anchor: .center)
                }
            }
            .frame(height: 22)
        }
    }
}
