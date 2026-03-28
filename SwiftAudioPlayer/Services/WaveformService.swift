//
//  WaveformService.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import AVFoundation
import Accelerate

/// Decodes an audio file to mono PCM float32 and generates normalized
/// RMS waveform peaks via the C++ waveform_peaks engine.
///
/// Mirrors Flutter's decodePCM + WaveformFFI.generatePeaks flow.
struct WaveformService {

    static let barCount: Int = 300

    /// Generates waveform peaks for the file at `absolutePath`.
    /// Returns `barCount` floats in [0, 1], or throws on error.
    func generatePeaks(absolutePath: String) async throws -> [Float] {
        return try await Task.detached(priority: .userInitiated) {
            // autoreleasepool ensures the large native AVAudioPCMBuffer (which is
            // an ObjC object) is released immediately after decode, before the C++
            // peak computation runs. Without this, both buffers would coexist in
            // memory until the Task's autorelease pool drains.
            let pcm = try autoreleasepool {
                try Self.decodePCMMono(absolutePath: absolutePath)
            }
            return try Self.computePeaks(pcm: pcm)
        }.value
    }

    // MARK: - PCM Decode

    /// Decodes the audio file to a flat mono Float32 array in [-1, 1].
    /// Mirrors Flutter's AudioPlayerService.decodePCM platform channel handler.
    private static func decodePCMMono(absolutePath: String) throws -> [Float] {
        let url = URL(fileURLWithPath: absolutePath)
        let audioFile = try AVAudioFile(forReading: url)

        let fileFormat = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0 else {
            throw NSError(domain: "WaveformService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"])
        }

        // Target: mono, float32, same sample rate as the file
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: fileFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "WaveformService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create mono format"])
        }

        // Read into a buffer in the file's native format first
        guard let nativeBuffer = AVAudioPCMBuffer(
            pcmFormat: fileFormat,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "WaveformService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to allocate native buffer"])
        }
        try audioFile.read(into: nativeBuffer)

        // Convert to mono float32 via AVAudioConverter
        guard let monoBuffer = AVAudioPCMBuffer(
            pcmFormat: monoFormat,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "WaveformService", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to allocate mono buffer"])
        }

        guard let converter = AVAudioConverter(from: fileFormat, to: monoFormat) else {
            // Fallback: manual downmix if AVAudioConverter can't handle the format
            return manualDownmix(buffer: nativeBuffer)
        }

        var error: NSError?
        var inputDone = false
        let status = converter.convert(to: monoBuffer, error: &error) { _, outStatus in
            if inputDone {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputDone = true
            outStatus.pointee = .haveData
            return nativeBuffer
        }

        if status == .error {
            // Fallback on conversion error
            return manualDownmix(buffer: nativeBuffer)
        }

        guard let channelData = monoBuffer.floatChannelData else {
            throw NSError(domain: "WaveformService", code: 5,
                          userInfo: [NSLocalizedDescriptionKey: "No channel data after conversion"])
        }

        let count = Int(monoBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData[0], count: count))
    }

    /// Manual stereo→mono downmix fallback when AVAudioConverter is unavailable.
    private static func manualDownmix(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let count = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return [] }

        var mono = [Float](repeating: 0, count: count)
        for ch in 0..<channelCount {
            let ptr = channelData[ch]
            vDSP_vadd(mono, 1, ptr, 1, &mono, 1, vDSP_Length(count))
        }
        if channelCount > 1 {
            var divisor = Float(channelCount)
            vDSP_vsdiv(mono, 1, &divisor, &mono, 1, vDSP_Length(count))
        }
        return mono
    }

    // MARK: - Peak Computation

    /// Calls the C++ waveform engine via the ObjC bridge.
    private static func computePeaks(pcm: [Float]) throws -> [Float] {
        guard !pcm.isEmpty else {
            return [Float](repeating: 0, count: barCount)
        }

        // withUnsafeBufferPointer keeps `pcm` alive across the bridge call.
        // Capture error separately to avoid closure return-type constraints.
        // Swift auto-converts ObjC NSError** methods to `throws` — no error: label needed.
        var peaks: [NSNumber]?

        try pcm.withUnsafeBufferPointer { ptr in
            peaks = try WaveformCppBridge.generatePeaks(
                fromBuffer: ptr.baseAddress!,
                frameCount: UInt64(pcm.count),
                sampleRate: 44100.0,
                barCount: UInt32(barCount)
            )
        }

        guard let peaks else {
            throw NSError(domain: "WaveformService", code: 6,
                          userInfo: [NSLocalizedDescriptionKey: "Waveform bridge returned nil"])
        }

        return peaks.map { $0.floatValue }
    }
}
