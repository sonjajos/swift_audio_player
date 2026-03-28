//
//  AudioTrack.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation

struct AudioTrack: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let filePath: String
    let title: String
    let artist: String
    let durationMs: Int
    let dateAdded: Date
    
    init(
        id: UUID = UUID(),
        filePath: String,
        title: String,
        artist: String = "Unknown Artist",
        durationMs: Int,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.artist = artist
        self.durationMs = durationMs
        self.dateAdded = dateAdded
    }
    
    var durationFormatted: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
