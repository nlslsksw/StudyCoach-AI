import Foundation
import AVFoundation
import SwiftUI

// MARK: - Ambient Player
//
// Spielt Hintergrund-Geräusche während des Lerntimers. Geräusche werden
// algorithmisch erzeugt (kein Bundle-Asset nötig) — Brown Noise, White
// Noise, Regen-ähnliches gefiltertes Rauschen.

@MainActor
@Observable
final class AmbientPlayer {
    static let shared = AmbientPlayer()

    enum Sound: String, CaseIterable, Identifiable {
        case off = "Aus"
        case brown = "Brown Noise"
        case white = "White Noise"
        case rain = "Regen"
        case wind = "Wind"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .off: return "speaker.slash"
            case .brown: return "waveform"
            case .white: return "dot.radiowaves.left.and.right"
            case .rain: return "cloud.rain.fill"
            case .wind: return "wind"
            }
        }
    }

    var sound: Sound = .off
    var volume: Float = 0.35 {
        didSet { /* volume gilt sofort über nextSample */ }
    }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var brownLast: Float = 0
    private var phase: Float = 0
    private var noiseBuf: [Float] = Array(repeating: 0, count: 64)
    private var noiseIdx: Int = 0

    func play(_ sound: Sound) {
        stop(silent: true)
        guard sound != .off else { self.sound = .off; return }
        self.sound = sound

        let format = engine.outputNode.outputFormat(forBus: 0)
        let sampleRate = Float(format.sampleRate)

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
        engine.connect(src, to: engine.mainMixerNode, format: format)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            source = src
        } catch {
            // Audio konnte nicht starten — leise scheitern.
        }
    }

    func stop(silent: Bool = false) {
        if let s = source {
            engine.detach(s)
            source = nil
        }
        if engine.isRunning { engine.stop() }
        if !silent { sound = .off }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func nextSample(sampleRate: Float) -> Float {
        let white = Float.random(in: -1...1)
        let value: Float
        switch sound {
        case .off:
            value = 0
        case .white:
            value = white * 0.3
        case .brown:
            // Integrator-Filter → tiefe Frequenzen dominieren
            brownLast += white * 0.02
            brownLast = max(-1, min(1, brownLast))
            value = brownLast * 3.5
        case .rain:
            // White-Noise mit Tiefpass und sehr langsamer Amplituden-Modulation
            noiseBuf[noiseIdx] = white
            noiseIdx = (noiseIdx + 1) % noiseBuf.count
            let avg = noiseBuf.reduce(0, +) / Float(noiseBuf.count)
            phase += 1 / sampleRate
            let mod = (sin(phase * 0.7) * 0.15 + 0.85)
            value = avg * 1.6 * mod
        case .wind:
            // Brown Noise + LFO-Schwell-Effekt
            brownLast += white * 0.015
            brownLast = max(-1, min(1, brownLast))
            phase += 1 / sampleRate
            let swell = (sin(phase * 0.5) + 1) * 0.5  // 0…1
            value = brownLast * 3.0 * swell
        }
        return value * volume
    }
}

// MARK: - Player UI

struct AmbientPlayerBar: View {
    @Bindable private var player = AmbientPlayer.shared
    @State private var expanded: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: player.sound.icon)
                    .foregroundStyle(player.sound == .off ? Color.secondary : Color.blue)
                Text(player.sound.rawValue)
                    .font(.caption.bold())
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expanded.toggle()
                    }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if expanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AmbientPlayer.Sound.allCases) { sound in
                            Button {
                                if sound == .off {
                                    player.stop()
                                } else {
                                    player.play(sound)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: sound.icon)
                                        .font(.subheadline)
                                    Text(sound.rawValue)
                                        .font(.caption2)
                                }
                                .foregroundStyle(player.sound == sound ? .white : .primary)
                                .frame(width: 70, height: 56)
                                .background(
                                    player.sound == sound
                                    ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Color(.tertiarySystemFill)),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if player.sound != .off {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Slider(value: Binding(
                            get: { Double(player.volume) },
                            set: { player.volume = Float($0) }
                        ), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}
