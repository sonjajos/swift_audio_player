//
//  AudioPlayerService.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation
import Combine

/// Service that wraps AudioEnginePlayer and exposes a Combine-friendly interface
@MainActor
class AudioPlayerService: ObservableObject {
    
    @Published private(set) var playbackState: PlaybackState = .idle
    @Published private(set) var currentPositionMs: Int = 0
    @Published private(set) var durationMs: Int = 0
    @Published private(set) var fftData: FFTData?
    @Published private(set) var currentTrack: AudioTrack?

    var onTrackCompleted: (() -> Void)?

    private let engine = AudioEnginePlayer()
    
    init() {
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        engine.onStateChanged = { [weak self] state, positionMs, durationMs in
            Task { @MainActor in
                guard let self = self else { return }
                self.playbackState = PlaybackState(rawValue: state) ?? .idle
                self.currentPositionMs = positionMs
                self.durationMs = durationMs
            }
        }
        
        engine.onFFTData = { [weak self] bands, nativeFftTimeUs in
            Task { @MainActor in
                guard let self = self else { return }
                self.fftData = FFTData(bands: bands, nativeFftTimeUs: nativeFftTimeUs)
            }
        }
        
        engine.onTrackCompleted = { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.onTrackCompleted?()
            }
        }
    }
    
    // MARK: - Public API
    
    func load(track: AudioTrack) throws {
        try engine.load(filePath: track.filePath)
        currentTrack = track
    }
    
    func play() {
        engine.play()
    }
    
    func pause() {
        engine.pause()
    }
    
    func resume() {
        engine.resume()
    }
    
    func stop() {
        engine.stop()
        currentTrack = nil
    }
    
    func seek(to positionMs: Int) {
        engine.seek(to: positionMs)
    }
    
    func setBandCount(_ count: Int) {
        engine.setBandCount(count)
    }
    
    var isPlaying: Bool {
        playbackState == .playing
    }
}
