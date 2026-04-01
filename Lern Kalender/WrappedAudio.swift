import AVFoundation
import UIKit

// MARK: - Wrapped Audio (Chill Ambient Arpeggio)

final class WrappedAudio {
    static let shared = WrappedAudio()

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var isPlaying = false
    private var fadeTimer: Timer?
    private let synth = AmbientSynth()

    private init() {}

    func play() {
        guard !isPlaying else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { return }

        let engine = AVAudioEngine()
        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        synth.sampleRate = sampleRate
        synth.reset()

        let synthRef = synth
        let node = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let buf = UnsafeMutableBufferPointer<Float>(
                start: bufferList.pointee.mBuffers.mData?.assumingMemoryBound(to: Float.self),
                count: Int(frameCount)
            )
            synthRef.render(into: buf, frameCount: Int(frameCount))
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0

        do {
            try engine.start()
            audioEngine = engine
            sourceNode = node
            isPlaying = true
            fadeVolume(to: 0.9, duration: 2.0)
        } catch { }
    }

    func stop() {
        guard isPlaying else { return }
        fadeVolume(to: 0, duration: 1.0) {
            self.audioEngine?.stop()
            if let node = self.sourceNode { self.audioEngine?.detach(node) }
            self.audioEngine = nil
            self.sourceNode = nil
            self.isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    func onSlideChange() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func fadeVolume(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let steps = 25
        let stepDuration = duration / Double(steps)
        let startVol = audioEngine?.mainMixerNode.outputVolume ?? 0
        var step = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            step += 1
            let p = Float(step) / Float(steps)
            self.audioEngine?.mainMixerNode.outputVolume = startVol + (target - startVol) * p
            if step >= steps { timer.invalidate(); completion?() }
        }
    }
}

// MARK: - Ambient Synthesizer

private final class AmbientSynth {
    var sampleRate: Double = 44100

    // Am - F - C - G
    private let chordFreqs: [[Double]] = [
        [220.00, 261.63, 329.63],
        [174.61, 220.00, 261.63],
        [261.63, 329.63, 392.00],
        [196.00, 246.94, 293.66],
    ]

    private let chordDuration: Double = 4.0
    private let arpSpeed: Double = 0.4

    private var phases = [Double](repeating: 0, count: 6)
    private var globalSample: Int = 0

    func reset() {
        phases = [Double](repeating: 0, count: 6)
        globalSample = 0
    }

    func render(into buffer: UnsafeMutableBufferPointer<Float>, frameCount: Int) {
        let totalCycleSamples = Int(chordDuration * Double(chordFreqs.count) * sampleRate)

        for frame in 0..<frameCount {
            let pos = globalSample % totalCycleSamples
            let timeInCycle = Double(pos) / sampleRate
            let chordIndex = Int(timeInCycle / chordDuration) % chordFreqs.count
            let chord = chordFreqs[chordIndex]
            let timeInChord = timeInCycle - Double(chordIndex) * chordDuration
            let arpIndex = Int(timeInChord / arpSpeed) % chord.count

            let arpTime = timeInChord - Double(Int(timeInChord / arpSpeed)) * arpSpeed
            let arpProgress = arpTime / arpSpeed

            var sample: Float = 0

            // Arpeggio-Noten
            for i in 0..<chord.count {
                let env: Float = (i == arpIndex) ? Float(exp(-arpProgress * 3.0)) : Float(exp(-3.0))
                let sinVal = Float(sin(2.0 * .pi * phases[i]))
                sample += sinVal * env * 0.07
                phases[i] += chord[i] / sampleRate
                if phases[i] > 1.0 { phases[i] -= 1.0 }
            }

            // Sub-Bass
            let bassFreq = chord[0] / 2.0
            let bassVal = Float(sin(2.0 * .pi * phases[3]))
            sample += bassVal * 0.03
            phases[3] += bassFreq / sampleRate
            if phases[3] > 1.0 { phases[3] -= 1.0 }

            // Shimmer
            let shimmerFreq = chord[2] * 2.0
            let lfo = Float(sin(2.0 * .pi * Double(globalSample) * 0.15 / sampleRate))
            let shimmerEnv = lfo * 0.5 + 0.5
            let shimmerVal = Float(sin(2.0 * .pi * phases[4]))
            sample += shimmerVal * 0.015 * shimmerEnv
            phases[4] += shimmerFreq / sampleRate
            if phases[4] > 1.0 { phases[4] -= 1.0 }

            buffer[frame] = sample
            globalSample += 1
        }
    }
}
