//
//  MiniPlayerBarView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

struct MiniPlayerBarView: View {
    @Environment(AppStore.self) var store

    @Binding var navigationPath: NavigationPath

    var body: some View {
        if let track = store.currentTrack {
            HStack(spacing: 0) {
                // Mini circular visualizer
                CircularVisualizerView(fftData: store.fftData, bandCount: 16)
                    .frame(width: 64, height: 64)
                    .padding(.leading, 8)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.54))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)

                Spacer()

                // Previous
                Button { store.playPrevious() } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(width: 36)

                // Play / Pause
                Button { store.togglePlayPause() } label: {
                    Image(systemName: store.playbackState == .playing ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                }
                .frame(width: 44)

                // Next
                Button { store.playNext() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .frame(width: 36)

                Spacer().frame(width: 8)
            }
            .frame(height: 72)
            .background(Color(white: 0.1))
            .contentShape(Rectangle())
            .onTapGesture {
                navigationPath.append(track)
            }
        }
    }
}
