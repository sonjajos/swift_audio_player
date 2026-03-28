//
//  AudioEnginePlayer.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import AVFoundation
import Accelerate

/// Callback types for communicating state and data back to the service layer.
typealias StateCallback = (_ state: String, _ positionMs: Int, _ durationMs: Int) -> Void
typealias FFTCallback = (_ bands: [Float], _ nativeFftTimeUs: Int64) -> Void
typealias CompletionCallback = () -> Void

class AudioEnginePlayer {
    
    // MARK: - Audio Engine
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    
    // MARK: - Playback State
    
    private(set) var playbackState: PlaybackState = .idle
    private var seekFrameOffset: AVAudioFramePosition = 0
    private var fileDurationMs: Int = 0
    private var fileSampleRate: Double = 44100.0
    private var fileTotalFrames: AVAudioFramePosition = 0
    private var loadGeneration: Int = 0
    
    // MARK: - Position Timer
    
    private var positionTimer: DispatchSourceTimer?
    private let positionTimerQueue = DispatchQueue(label: "com.audioplayer.position", qos: .utility)
    
    // MARK: - FFT Configuration
    
    private var bandCount: Int = 32
    private let fftSize: Int = 4096
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0
    private var window: [Float] = []
    private let fftQueue = DispatchQueue(label: "com.audioplayer.fft", qos: .userInteractive)
    
    // Pre-allocated FFT buffers
    private var fftRealp: [Float] = []
    private var fftImagp: [Float] = []
    private var magnitudes: [Float] = []
    
    // Pre-allocated sample buffers (reused to avoid per-frame heap allocations)
    private var monoBuffer: [Float] = []
    private var windowedBuffer: [Float] = []
    
    // Backpressure: skip FFT if the previous frame is still processing.
    private var fftProcessing = false
    private let fftLock: UnsafeMutablePointer<os_unfair_lock> = {
        let ptr = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        ptr.initialize(to: os_unfair_lock())
        return ptr
    }()
    
    // MARK: - Callbacks
    
    var onStateChanged: StateCallback?
    var onFFTData: FFTCallback?
    var onTrackCompleted: CompletionCallback?
    
    // MARK: - Init
    
    init() {
        setupFFT()
        setupEngine()
    }
    
    deinit {
        positionTimer?.cancel()
        removeTap()
        engine.stop()
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        fftLock.deinitialize(count: 1)
        fftLock.deallocate()
    }
    
    // MARK: - Engine Setup
    
    private func setupEngine() {
        engine.attach(playerNode)
    }
    
    private func connectNodes(format: AVAudioFormat) {
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }
    
    // MARK: - FFT Setup
    
    private func setupFFT() {
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        // Hann window
        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        // Pre-allocate buffers
        let halfN = fftSize / 2
        fftRealp = [Float](repeating: 0, count: halfN)
        fftImagp = [Float](repeating: 0, count: halfN)
        magnitudes = [Float](repeating: 0, count: halfN)
        monoBuffer = [Float](repeating: 0, count: fftSize)
        windowedBuffer = [Float](repeating: 0, count: fftSize)
    }
    
    // MARK: - Public API
    
    func load(filePath: String) throws {
        // Invalidate any pending completion callbacks from the previous track
        loadGeneration += 1
        
        // Stop current playback and engine before loading a new track
        playerNode.stop()
        stopPositionTimer()
        removeTap()
        engine.disconnectNodeOutput(playerNode)
        if engine.isRunning {
            engine.stop()
        }
        
        // Handle both file:// URIs and plain paths
        let url: URL
        if filePath.hasPrefix("file://") {
            guard let parsedURL = URL(string: filePath) else {
                throw NSError(
                    domain: "AudioEnginePlayer", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid file URI"])
            }
            url = parsedURL
        } else {
            url = URL(fileURLWithPath: filePath)
        }
        
        audioFile = try AVAudioFile(forReading: url)
        
        guard let file = audioFile else { return }
        
        fileSampleRate = file.processingFormat.sampleRate
        fileTotalFrames = file.length
        fileDurationMs = Int(Double(fileTotalFrames) / fileSampleRate * 1000.0)
        seekFrameOffset = 0
        playbackState = .idle
        
        // Connect nodes with the file's format
        connectNodes(format: file.processingFormat)
        
        // Install tap for FFT / PCM data
        installTap(format: file.processingFormat)
        
        // Prepare and start engine
        engine.prepare()
        try engine.start()
        
        notifyState()
    }
    
    func play() {
        guard let file = audioFile else { return }
        
        // Schedule from current offset
        scheduleFile(from: seekFrameOffset)
        
        playerNode.play()
        playbackState = .playing
        
        startPositionTimer()
        notifyState()
    }
    
    func pause() {
        playerNode.pause()
        // Capture current position before pausing
        seekFrameOffset = currentFramePosition()
        playbackState = .paused
        
        stopPositionTimer()
        notifyState()
    }
    
    func resume() {
        guard let file = audioFile else { return }
        
        // If engine was stopped, do a cold restart.
        if !engine.isRunning {
            let fmt = file.processingFormat
            engine.disconnectNodeOutput(playerNode)
            connectNodes(format: fmt)
            installTap(format: fmt)
            engine.prepare()
            try? engine.start()
            scheduleFile(from: seekFrameOffset)
        }
        
        playerNode.play()
        playbackState = .playing
        
        startPositionTimer()
        notifyState()
    }
    
    func stop() {
        playerNode.stop()
        seekFrameOffset = 0
        playbackState = .stopped
        
        stopPositionTimer()
        notifyState()
    }
    
    func seek(to positionMs: Int) {
        let wasPlaying = playbackState == .playing
        playerNode.stop()
        
        let targetFrame = AVAudioFramePosition(Double(positionMs) / 1000.0 * fileSampleRate)
        seekFrameOffset = Swift.min(targetFrame, fileTotalFrames)
        
        scheduleFile(from: seekFrameOffset)
        
        if wasPlaying {
            playerNode.play()
            playbackState = .playing
            startPositionTimer()
        } else {
            playbackState = .paused
        }
        
        notifyState()
    }
    
    func setBandCount(_ count: Int) {
        bandCount = count
    }
    
    // MARK: - Position Tracking
    
    func currentPositionMs() -> Int {
        let frame = currentFramePosition()
        return Int(Double(frame) / fileSampleRate * 1000.0)
    }
    
    private func currentFramePosition() -> AVAudioFramePosition {
        guard playbackState == .playing || playbackState == .paused else {
            return seekFrameOffset
        }
        
        guard let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return seekFrameOffset
        }
        
        let currentFrame = seekFrameOffset + playerTime.sampleTime
        return Swift.min(Swift.max(currentFrame, 0), fileTotalFrames)
    }
    
    private func startPositionTimer() {
        positionTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: positionTimerQueue)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1, leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            self?.notifyState()
        }
        timer.resume()
        positionTimer = timer
    }
    
    private func stopPositionTimer() {
        positionTimer?.cancel()
        positionTimer = nil
    }
    
    // MARK: - Schedule Playback
    
    private func scheduleFile(from frameOffset: AVAudioFramePosition) {
        guard let file = audioFile else { return }
        
        let remainingFrames = fileTotalFrames - frameOffset
        guard remainingFrames > 0 else { return }
        
        let generation = loadGeneration
        
        playerNode.scheduleSegment(
            file,
            startingFrame: frameOffset,
            frameCount: AVAudioFrameCount(remainingFrames),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      self.loadGeneration == generation,
                      self.playbackState == .playing
                else { return }
                self.playbackState = .stopped
                self.seekFrameOffset = 0
                self.stopPositionTimer()
                self.notifyState()
                self.onTrackCompleted?()
            }
        }
    }
    
    // MARK: - Audio Tap + FFT
    
    private func installTap(format: AVAudioFormat) {
        removeTap()
        
        // Tap with the mixer's native format (preserves stereo)
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: AVAudioFrameCount(fftSize),
            format: nil
        ) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0,
                  let channelData = buffer.floatChannelData
            else { return }
            
            let count = Swift.min(frameLength, self.fftSize)
            let channelCount = Int(buffer.format.channelCount)
            
            // Mix all channels to mono using pre-allocated buffer
            vDSP_vclr(&self.monoBuffer, 1, vDSP_Length(self.fftSize))
            for ch in 0..<channelCount {
                let chPtr = channelData[ch]
                for i in 0..<count {
                    self.monoBuffer[i] += chPtr[i]
                }
            }
            if channelCount > 1 {
                var divisor = Float(channelCount)
                vDSP_vsdiv(self.monoBuffer, 1, &divisor, &self.monoBuffer, 1, vDSP_Length(count))
            }
            
            // Backpressure: drop this frame if the previous one is still processing.
            // Use trylock (non-blocking) so the real-time audio thread never blocks
            // in the kernel waiting for the lock — avoids audio glitches.
            guard os_unfair_lock_trylock(self.fftLock) else { return }
            let busy = self.fftProcessing
            if !busy { self.fftProcessing = true }
            os_unfair_lock_unlock(self.fftLock)
            
            // Snapshot mono samples into windowedBuffer
            for i in 0..<self.fftSize {
                self.windowedBuffer[i] = self.monoBuffer[i]
            }
            
            self.fftQueue.async { [weak self] in
                guard let self = self else { return }
                self.processFFT()
                os_unfair_lock_lock(self.fftLock)
                self.fftProcessing = false
                os_unfair_lock_unlock(self.fftLock)
            }
        }
    }
    
    private func removeTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
    }
    
    private func processFFT() {
        let startTime = CACurrentMediaTime()
        let halfN = fftSize / 2
        
        // Apply Hann window in-place
        vDSP_vmul(windowedBuffer, 1, window, 1, &windowedBuffer, 1, vDSP_Length(fftSize))
        
        // Convert real signal to split complex form
        windowedBuffer.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                var split = DSPSplitComplex(realp: &self.fftRealp, imagp: &self.fftImagp)
                vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(halfN))
            }
        }
        
        // Execute real FFT in-place
        guard let setup = fftSetup else { return }
        var splitComplex = DSPSplitComplex(realp: &fftRealp, imagp: &fftImagp)
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Compute squared magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))
        
        // Convert to dB
        var one: Float = 1.0e-10
        vDSP_vdbcon(magnitudes, 1, &one, &magnitudes, 1, vDSP_Length(halfN), 0)
        
        // Logarithmic band grouping
        let bands = logarithmicBandGrouping(
            magnitudes: magnitudes, bandCount: bandCount, binCount: halfN)
        
        let endTime = CACurrentMediaTime()
        let fftTimeUs = Int64((endTime - startTime) * 1_000_000)
        
        onFFTData?(bands, fftTimeUs)
    }
    
    private func logarithmicBandGrouping(magnitudes: [Float], bandCount: Int, binCount: Int)
        -> [Float]
    {
        var bandDbValues = [Float](repeating: -Float.infinity, count: bandCount)
        
        let minBin: Float = 3.0
        let maxBin = Float(binCount - 1)
        let logMin = log2(minBin)
        let logMax = log2(maxBin)
        
        var binEdges = [Int]()
        for i in 0...bandCount {
            let t = Float(i) / Float(bandCount)
            let edge = Int(pow(2.0, logMin + t * (logMax - logMin)))
            if let last = binEdges.last {
                binEdges.append(Swift.max(edge, last + 1))
            } else {
                binEdges.append(Swift.max(edge, Int(minBin)))
            }
        }
        
        for i in 0..<bandCount {
            let start = binEdges[i]
            let clampedEnd = Swift.min(binEdges[i + 1], binCount)
            
            var sum: Float = 0
            var count = 0
            for j in start..<clampedEnd {
                sum += magnitudes[j]
                count += 1
            }
            
            if count > 0 {
                bandDbValues[i] = sum / Float(count)
            }
        }
        
        let validValues = bandDbValues.filter { $0 > -Float.infinity }
        guard !validValues.isEmpty else {
            return [Float](repeating: 0, count: bandCount)
        }
        
        let frameMax = validValues.max()!
        let dbFloor = frameMax - 60.0
        
        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            if bandDbValues[i] > -Float.infinity {
                let normalized = (bandDbValues[i] - dbFloor) / 60.0
                let clamped = Swift.max(0.0, Swift.min(1.0, normalized))
                bands[i] = clamped * clamped
            }
        }
        
        return bands
    }
    
    // MARK: - State Notification
    
    private func notifyState() {
        let posMs = currentPositionMs()
        onStateChanged?(playbackState.rawValue, posMs, fileDurationMs)
    }
}
