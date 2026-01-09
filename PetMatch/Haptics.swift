//
//  Haptics.swift
//  PetMatch
//

import UIKit
import AVFoundation

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
    }
}

/// Tiny “premium” whoosh synthesized at runtime (no bundled audio files).
final class WhooshSynth {
    static let shared = WhooshSynth()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isReady = false

    private init() {}

    func play() {
        prepareIfNeeded()
        guard isReady else { return }

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let duration: Double = 0.12
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        let channels = Int(format.channelCount)
        let count = Int(frameCount)

        let alpha: Float = 0.10 // low-pass smoothness
        var lp: Float = 0

        if let data = buffer.floatChannelData {
            for i in 0..<count {
                let t = Float(i) / Float(count)
                let envAttack = min(1, t / 0.08)
                let envDecay = exp(-t * 6.5)
                let env = envAttack * envDecay

                let white = Float.random(in: -1...1)
                lp = lp + alpha * (white - lp)
                let sample = lp * env * 0.55

                for ch in 0..<channels {
                    data[ch][i] = sample
                }
            }
        }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop, completionHandler: nil)
        player.play()
    }

    private func prepareIfNeeded() {
        guard !isReady else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true, options: [])

            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: nil)

            try engine.start()
            isReady = true
        } catch {
            isReady = false
        }
    }
}

