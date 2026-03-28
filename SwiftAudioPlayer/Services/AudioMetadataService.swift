//
//  AudioMetadataService.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation
import AVFoundation

/// Service for extracting metadata from audio files
struct AudioMetadataService {
    
    struct Metadata {
        let title: String
        let artist: String
        let durationMs: Int
    }
    
    /// Extract metadata from an audio file at the given path
    func getMetadata(filePath: String) async throws -> Metadata {
        let url: URL
        if filePath.hasPrefix("file://") {
            guard let parsedURL = URL(string: filePath) else {
                throw NSError(
                    domain: "AudioMetadataService", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid file URI"])
            }
            url = parsedURL
        } else {
            url = URL(fileURLWithPath: filePath)
        }
        
        let asset = AVAsset(url: url)
        var title: String?
        var artist: String?
        var durationMs: Int = 0

        if let cmDuration = try? await asset.load(.duration) {
            durationMs = Int(cmDuration.seconds * 1000.0)
        }

        if let commonMetadata = try? await asset.load(.commonMetadata) {
            for item in commonMetadata {
                if item.commonKey == .commonKeyTitle {
                    title = try? await item.load(.stringValue)
                } else if item.commonKey == .commonKeyArtist {
                    artist = try? await item.load(.stringValue)
                }
            }
        }
        
        if title == nil || title!.isEmpty {
            title = url.deletingPathExtension().lastPathComponent
        }
        
        return Metadata(
            title: title ?? "Unknown",
            artist: artist ?? "Unknown Artist",
            durationMs: durationMs
        )
    }
}
