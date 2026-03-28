//
//  NowPlayingView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

struct NowPlayingView: View {
    @Environment(AppStore.self) var store
    let initialTrack: AudioTrack

    private static let bandCounts = [16, 32, 64, 128]

    private var bandCountIndex: Int {
        Self.bandCounts.firstIndex(of: store.bandCount) ?? 1
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Track info
                VStack(spacing: 6) {
                    Text(store.currentTrack?.title ?? initialTrack.title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(store.currentTrack?.artist ?? initialTrack.artist)
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
                .padding(.top, 16)
                .padding(.horizontal)

                // Circular visualizer
                CircularVisualizerView(fftData: store.fftData, bandCount: store.bandCount)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)

                // Waveform seeker
                WaveformSeekerView(
                    peaks: store.waveformPeaks,
                    currentPositionMs: store.currentPositionMs,
                    durationMs: store.durationMs,
                    isPlaying: store.playbackState == .playing
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                // Playback controls
                HStack(spacing: 48) {
                    Button {
                        store.playPrevious()
                    } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    Button {
                        store.togglePlayPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 72, height: 72)
                            Image(systemName: store.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundColor(.black)
                                .offset(x: store.playbackState == .playing ? 0 : 2)
                        }
                    }

                    Button {
                        store.playNext()
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Now Playing")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    cycleBandCount()
                } label: {
                    Text("\(store.bandCount * 2)b")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.7))
                }
            }
        }
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if store.currentTrack?.id != initialTrack.id {
                store.playTrack(initialTrack)
            }
        }
    }

    private func cycleBandCount() {
        let nextIndex = (bandCountIndex + 1) % Self.bandCounts.count
        let next = Self.bandCounts[nextIndex]
        store.bandCount = next
        store.setBandCount(next)
    }
}

#Preview {
    NavigationStack {
        NowPlayingView(initialTrack: AudioTrack(
            filePath: "/mock/path.mp3",
            title: "sample6",
            artist: "Unknown Artist",
            durationMs: 184000
        ))
        .environment({
            let store = AppStore()
            store.playbackState = .playing
            return store
        }())
    }
}
