//
//  AppStore.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation
import Combine

/// Central state management for the application
/// Inspired by TCA (The Composable Architecture) pattern
@MainActor
class AppStore: ObservableObject {
    
    // MARK: - State
    
    @Published var tracks: [AudioTrack] = []
    @Published var bandCount: Int = 32
    @Published var currentTrack: AudioTrack?
    @Published var playbackState: PlaybackState = .idle
    @Published var currentPositionMs: Int = 0
    @Published var durationMs: Int = 0
    @Published var fftData: FFTData?
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var waveformPeaks: [Float]? = nil
    @Published var isLoadingWaveform: Bool = false

    // MARK: - Services

    private let sqliteService = SQLiteService()
    private let audioPlayerService = AudioPlayerService()
    private let metadataService = AudioMetadataService()
    private let sessionManager = AudioSessionManager()
    private let waveformService = WaveformService()
    private var fileImportService: FileImportService?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        setupAudioSession()
        setupBindings()
        Task {
            do {
                try await sqliteService.setup()
            } catch {
                self.error = "Database initialization failed: \(error.localizedDescription)"
                return
            }
            await initializeFileImportService()
            await loadTracks()
            await cleanupOrphanedFiles()
        }
    }
    
    private func initializeFileImportService() async {
        do {
            fileImportService = try await FileImportService()
        } catch {
            self.error = "Failed to initialize file import service: \(error.localizedDescription)"
        }
    }
    
    private func setupAudioSession() {
        do {
            try sessionManager.configure()
            
            // Handle audio interruptions (phone calls, Siri, etc.)
            sessionManager.onInterruption = { [weak self] began, shouldResume in
                Task { @MainActor in
                    guard let self = self else { return }
                    if began {
                        // Interruption began - pause playback
                        self.audioPlayerService.pause()
                    } else if shouldResume {
                        // Interruption ended - resume if system suggests
                        self.audioPlayerService.resume()
                    }
                }
            }
        } catch {
            self.error = "Failed to configure audio session: \(error.localizedDescription)"
        }
    }
    
    private func setupBindings() {
        // Bind audio player service to app state
        audioPlayerService.$playbackState
            .assign(to: &$playbackState)
        
        audioPlayerService.$currentPositionMs
            .assign(to: &$currentPositionMs)
        
        audioPlayerService.$durationMs
            .assign(to: &$durationMs)
        
        audioPlayerService.$fftData
            .assign(to: &$fftData)
        
        audioPlayerService.$currentTrack
            .assign(to: &$currentTrack)

        audioPlayerService.onTrackCompleted = { [weak self] in
            self?.playNext()
        }
    }
    
    // MARK: - Actions
    
    func loadTracks() async {
        do {
            let loadedTracks = try await sqliteService.getAllTracks()
            tracks = loadedTracks
        } catch {
            self.error = "Failed to load tracks: \(error.localizedDescription)"
        }
    }
    
    /// Import audio files from the document picker
    /// Mirrors Flutter's uploadTrack() logic
    func importFiles(_ urls: [URL]) async {
        guard let fileImportService = fileImportService else {
            self.error = "File import service not initialized"
            return
        }

        isLoading = true
        defer { isLoading = false }

        var successCount = 0
        var failedFiles: [String] = []

        for url in urls {
            do {
                // Step 1: Copy file — returns relative path e.g. "audio_files/foo.mp3"
                let relativePath = try await fileImportService.copyToDocuments(from: url)

                // Step 2: Resolve to absolute path for metadata extraction
                let absolutePath = FileImportService.resolvedPath(for: relativePath)
                let metadata = try await metadataService.getMetadata(filePath: absolutePath)
                
                // Step 3: Create AudioTrack — store relative path
                let track = AudioTrack(
                    filePath: relativePath,
                    title: metadata.title,
                    artist: metadata.artist,
                    durationMs: metadata.durationMs
                )
                
                // Step 4: Save to SQLite
                try await sqliteService.insertTrack(track)
                
                // Step 5: Add to UI state (insert at top like Flutter app)
                tracks.insert(track, at: 0)
                
                successCount += 1
            } catch {
                failedFiles.append(url.lastPathComponent)
                print("Failed to import \(url.lastPathComponent): \(error)")
            }
        }
        
        // Show result message
        if !failedFiles.isEmpty {
            self.error = "Failed to import \(failedFiles.count) file(s): \(failedFiles.joined(separator: ", "))"
        } else if successCount > 0 {
            // Success - no error message needed
            print("Successfully imported \(successCount) file(s)")
        }
    }
    
    /// Import files that exist on disk but not in database
    /// Mirrors Flutter's _scanLocalFiles() reconciliation logic
    private func cleanupOrphanedFiles() async {
        guard let fileImportService = fileImportService else { return }
        
        do {
            let existingPaths = Set(tracks.map { $0.filePath })
            let orphanedFiles = try await fileImportService.findOrphanedFiles(excluding: existingPaths)
            
            // Import orphaned files into database
            for relativePath in orphanedFiles {
                do {
                    let absolutePath = FileImportService.resolvedPath(for: relativePath)
                    let metadata = try await metadataService.getMetadata(filePath: absolutePath)

                    // Store relative path in DB
                    let track = AudioTrack(
                        filePath: relativePath,
                        title: metadata.title,
                        artist: metadata.artist,
                        durationMs: metadata.durationMs
                    )
                    
                    // Save to SQLite
                    try await sqliteService.insertTrack(track)
                    
                    // Add to UI state
                    tracks.insert(track, at: 0)
                    
                    print("Imported orphaned file: \(relativePath)")
                } catch {
                    print("Failed to import orphaned file \(relativePath): \(error)")
                }
            }
            
            if !orphanedFiles.isEmpty {
                print("Imported \(orphanedFiles.count) orphaned file(s)")
            }
        } catch {
            print("Failed to scan for orphaned files: \(error)")
        }
    }
    
    func addTrack(filePath: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let metadata = try await metadataService.getMetadata(filePath: filePath)
            let track = AudioTrack(
                filePath: filePath,
                title: metadata.title,
                artist: metadata.artist,
                durationMs: metadata.durationMs
            )
            
            try await sqliteService.insertTrack(track)
            tracks.insert(track, at: 0)
        } catch {
            self.error = "Failed to add track: \(error.localizedDescription)"
        }
    }
    
    func deleteTrack(_ track: AudioTrack) async {
        guard let fileImportService = fileImportService else {
            self.error = "File import service not initialized"
            return
        }
        
        do {
            // Delete from SQLite
            try await sqliteService.deleteTrack(id: track.id)
            
            // Delete file from disk
            try await fileImportService.deleteFile(at: track.filePath)
            
            // Remove from UI state
            tracks.removeAll { $0.id == track.id }
            
            // Stop playback if this was the current track
            if currentTrack?.id == track.id {
                audioPlayerService.stop()
            }
        } catch {
            self.error = "Failed to delete track: \(error.localizedDescription)"
        }
    }
    
    func playTrack(_ track: AudioTrack) {
        let absolutePath = FileImportService.resolvedPath(for: track.filePath)
        let resolved = AudioTrack(
            id: track.id,
            filePath: absolutePath,
            title: track.title,
            artist: track.artist,
            durationMs: track.durationMs,
            dateAdded: track.dateAdded
        )
        do {
            try audioPlayerService.load(track: resolved)
            audioPlayerService.play()
        } catch {
            self.error = "Failed to play track: \(error.localizedDescription)"
        }

        // Load waveform in background whenever the track changes
        loadWaveform(absolutePath: absolutePath)
    }

    private func loadWaveform(absolutePath: String) {
        waveformPeaks = nil
        isLoadingWaveform = true
        Task {
            do {
                let peaks = try await waveformService.generatePeaks(absolutePath: absolutePath)
                waveformPeaks = peaks
            } catch {
                print("Waveform generation failed: \(error)")
                waveformPeaks = nil
            }
            isLoadingWaveform = false
        }
    }
    
    func togglePlayPause() {
        if playbackState == .playing {
            audioPlayerService.pause()
        } else if playbackState == .paused {
            audioPlayerService.resume()
        } else if let track = currentTrack {
            playTrack(track)
        }
    }
    
    func stop() {
        audioPlayerService.stop()
    }
    
    func seek(to positionMs: Int) {
        audioPlayerService.seek(to: positionMs)
    }
    
    func setBandCount(_ count: Int) {
        audioPlayerService.setBandCount(count)
    }
    
    func playNext() {
        guard let current = currentTrack,
              let currentIndex = tracks.firstIndex(where: { $0.id == current.id }),
              currentIndex + 1 < tracks.count else {
            return
        }
        
        let nextTrack = tracks[currentIndex + 1]
        playTrack(nextTrack)
    }
    
    func playPrevious() {
        guard let current = currentTrack,
              let currentIndex = tracks.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else {
            return
        }
        
        let previousTrack = tracks[currentIndex - 1]
        playTrack(previousTrack)
    }
}
