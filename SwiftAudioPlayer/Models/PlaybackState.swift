//
//  PlaybackState.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation

enum PlaybackState: String, Codable {
    case idle
    case playing
    case paused
    case stopped
}
