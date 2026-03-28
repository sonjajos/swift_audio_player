//
//  ContentView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 26. 3. 2026..
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showingFilePicker = false
    @State private var nowPlayingTrack: AudioTrack? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Audio list with mini player pinned below the nav bar
                AudioListView()
                    .environmentObject(store)
                    .navigationDestination(for: AudioTrack.self) { track in
                        NowPlayingView(initialTrack: track)
                            .environmentObject(store)
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        if store.currentTrack != nil {
                            MiniPlayerBarView(nowPlayingTrack: $nowPlayingTrack)
                                .environmentObject(store)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                // Floating + button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingFilePicker = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Audio Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.1), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
            // Programmatic navigation from mini bar tap
            .navigationDestination(isPresented: Binding(
                get: { nowPlayingTrack != nil },
                set: { if !$0 { nowPlayingTrack = nil } }
            )) {
                if let track = nowPlayingTrack {
                    NowPlayingView(initialTrack: track)
                        .environmentObject(store)
                }
            }
            .documentPicker(isPresented: $showingFilePicker) { urls in
                Task {
                    await store.importFiles(urls)
                }
            }
            .alert("Error", isPresented: .constant(store.error != nil)) {
                Button("OK") {
                    store.error = nil
                }
            } message: {
                if let error = store.error {
                    Text(error)
                }
            }
            .overlay {
                if store.isLoading {
                    ZStack {
                        Color.black.opacity(0.7)
                            .ignoresSafeArea()
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.currentTrack != nil)
        }
    }
}

#Preview {
    ContentView()
}
