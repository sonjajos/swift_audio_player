//
//  AudioPlayerView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

struct AudioPlayerView: View {
    @Environment(AppStore.self) var store
    
    var body: some View {
        VStack(spacing: 0) {
            if let track = store.currentTrack {
                // Track info
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                // FFT Visualizer placeholder
                FFTVisualizerView(fftData: store.fftData)
                    .frame(height: 200)
                    .padding(.vertical, 20)
                
                // Progress slider
                VStack(spacing: 8) {
                    ProgressSlider(
                        currentPosition: Double(store.currentPositionMs),
                        duration: Double(store.durationMs),
                        onSeek: { newPosition in
                            store.seek(to: Int(newPosition))
                        }
                    )
                    
                    HStack {
                        Text(formatTime(store.currentPositionMs))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text(formatTime(store.durationMs))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        store.playPrevious()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                    }
                    .disabled(store.tracks.isEmpty)
                    
                    Button {
                        store.togglePlayPause()
                    } label: {
                        Image(systemName: store.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                    }
                    
                    Button {
                        store.playNext()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                    }
                    .disabled(store.tracks.isEmpty)
                }
                .padding(.vertical, 24)
                
                Spacer()
            } else {
                // No track selected state
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No track selected")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Select a track from the list to start playing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func formatTime(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ProgressSlider: View {
    let currentPosition: Double
    let duration: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var tempPosition: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let progress = isDragging ? tempPosition : (duration > 0 ? currentPosition / duration : 0)
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
                
                // Progress track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let newProgress = Swift.max(0, Swift.min(1, value.location.x / geometry.size.width))
                        tempPosition = newProgress
                    }
                    .onEnded { value in
                        isDragging = false
                        let newProgress = Swift.max(0, Swift.min(1, value.location.x / geometry.size.width))
                        let newPosition = newProgress * duration
                        onSeek(newPosition)
                    }
            )
        }
        .frame(height: 20)
    }
}

#Preview {
    AudioPlayerView()
        .environment({
            let store = AppStore()
            store.currentTrack = AudioTrack(
                filePath: "/mock/path.mp3",
                title: "Sample Track",
                artist: "Artist Name",
                durationMs: 180000
            )
            store.currentPositionMs = 45000
            store.durationMs = 180000
            store.playbackState = .playing
            return store
        }())
}
