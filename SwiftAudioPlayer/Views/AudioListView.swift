//
//  AudioListView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

struct AudioListView: View {
    @Environment(AppStore.self) var store

    var body: some View {
        ZStack {
            if store.tracks.isEmpty {
                VStack(spacing: 12) {
                    Text("No audio files yet.")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.6))

                    Text("Tap + to upload.")
                        .font(.body)
                        .foregroundColor(Color.white.opacity(0.6))
                }
            } else {
                List {
                    ForEach(store.tracks) { track in
                        NavigationLink(value: track) {
                            AudioTrackRow(
                                track: track,
                                isCurrentTrack: store.currentTrack?.id == track.id,
                                isPlaying: store.currentTrack?.id == track.id && store.playbackState == .playing
                            )
                        }
                        .listRowBackground(Color.black)
                        .listRowSeparator(.visible, edges: .all)
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteTrack(track)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
        }
    }
}

struct AudioTrackRow: View {
    let track: AudioTrack
    let isCurrentTrack: Bool
    let isPlaying: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Music note icon
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundColor(Color.white.opacity(0.6))
                .frame(width: 30)
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(track.durationFormatted)
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.5))
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .background(Color.black)
    }
}

#Preview {
    NavigationStack {
        ZStack {
            Color.black.ignoresSafeArea()
            AudioListView()
                .environment({
                    let store = AppStore()
                    // Mock data for preview
                    store.tracks = [
                        AudioTrack(
                            filePath: "/mock/path1.mp3",
                            title: "sample5",
                            artist: "Unknown Artist",
                            durationMs: 203000
                        ),
                        AudioTrack(
                            filePath: "/mock/path2.mp3",
                            title: "sample4",
                            artist: "Unknown Artist",
                            durationMs: 162000
                        )
                    ]
                    return store
                }())
        }
        .navigationTitle("Audio Player")
        .navigationBarTitleDisplayMode(.large)
        .preferredColorScheme(.dark)
    }
}
