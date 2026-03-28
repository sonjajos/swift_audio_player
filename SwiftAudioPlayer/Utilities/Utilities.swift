//
//  Utilities.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation

// MARK: - Time Formatting

extension Int {
    /// Converts milliseconds to MM:SS format
    var formattedTime: String {
        let totalSeconds = self / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - URL Handling

extension String {
    /// Converts a file path (plain or file:// URI) to a URL
    func toFileURL() throws -> URL {
        if self.hasPrefix("file://") {
            guard let url = URL(string: self) else {
                throw URLError(.badURL)
            }
            return url
        } else {
            return URL(fileURLWithPath: self)
        }
    }
}

// MARK: - Array Extensions

extension Array where Element == Float {
    /// Normalizes float array to 0...1 range
    func normalized() -> [Float] {
        guard !isEmpty else { return [] }
        guard let max = self.max(), max > 0 else {
            return map { _ in 0 }
        }
        return map { $0 / max }
    }
    
    /// Smooths array using simple moving average
    func smoothed(windowSize: Int = 3) -> [Float] {
        guard count >= windowSize else { return self }
        
        var result = [Float]()
        result.reserveCapacity(count)
        
        for i in 0..<count {
            let start = Swift.max(0, i - windowSize / 2)
            let end = Swift.min(count, i + windowSize / 2 + 1)
            let window = self[start..<end]
            let average = window.reduce(0, +) / Float(window.count)
            result.append(average)
        }
        
        return result
    }
}
