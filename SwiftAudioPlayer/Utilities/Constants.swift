//
//  Constants.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

enum BandCount {
    /// Default band count used across the app and audio engine.
    static let `default`: Int = 128
}

enum VisualizerRenderer {
    /// Set to `true` to render the circular visualizer on the GPU via Metal + MTKView.
    /// Set to `false` to use the SwiftUI Canvas (CPU / Core Graphics) renderer.
    /// Change this value before building to switch between renderers for performance comparison.
    static var useMetal: Bool = true
}
