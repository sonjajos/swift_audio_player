//
//  FileImportService.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation
import AVFoundation

/// Service for managing audio file imports and storage
/// Mirrors the Flutter app's file management in AudioEnginePlugin.swift
actor FileImportService {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let audioDirectory: URL
    
    // MARK: - Supported Formats
    
    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "wav", "aac", "flac", "aiff", "aif", "caf"
    ]
    
    // MARK: - Init
    
    init() throws {
        // Create audio_files directory in Documents
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        audioDirectory = documentsDirectory.appendingPathComponent("audio_files", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(
                at: audioDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    // MARK: - Public API

    /// Resolve a relative path (e.g. "audio_files/foo.mp3") to a full absolute path.
    /// Always call this before passing a stored path to the audio engine or file system.
    static func resolvedPath(for relativePath: String) -> String {
        guard !relativePath.hasPrefix("/") else { return relativePath }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        return (docs as NSString).appendingPathComponent(relativePath)
    }

    /// Copy a file from the system picker to the app's audio directory.
    /// Returns a relative path ("audio_files/filename.mp3") — not an absolute path,
    /// so it stays valid across app reinstalls and container UUID changes.
    func copyToDocuments(from sourceURL: URL) throws -> String {
        // Validate file extension
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw ImportError.unsupportedFormat(fileExtension)
        }
        
        // Start accessing security-scoped resource
        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Check if file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw ImportError.fileNotFound(sourceURL.path)
        }
        
        // Generate unique filename if necessary
        let destinationURL = generateUniqueDestination(for: sourceURL)
        
        // Copy file
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        // Return relative path only — never store absolute container paths
        return "audio_files/\(destinationURL.lastPathComponent)"
    }
    
    /// Delete an audio file from the app's audio directory.
    /// Accepts either a relative path ("audio_files/foo.mp3") or absolute path.
    func deleteFile(at filePath: String) throws {
        let absolutePath = Self.resolvedPath(for: filePath)
        let url = URL(fileURLWithPath: absolutePath)

        guard url.standardizedFileURL.path.starts(with: audioDirectory.standardizedFileURL.path) else {
            throw ImportError.invalidPath(filePath)
        }

        guard fileManager.fileExists(atPath: absolutePath) else { return }
        try fileManager.removeItem(atPath: absolutePath)
    }

    /// List all audio files in the audio directory as relative paths ("audio_files/foo.mp3").
    func listAudioFiles() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(
            at: audioDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return contents
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map { "audio_files/\($0.lastPathComponent)" }
    }

    /// Scan the audio directory and return relative paths not already in the DB.
    func findOrphanedFiles(excluding existingRelativePaths: Set<String>) throws -> [String] {
        let allFiles = try listAudioFiles()
        return allFiles.filter { !existingRelativePaths.contains($0) }
    }
    
    // MARK: - Private Helpers
    
    private func generateUniqueDestination(for sourceURL: URL) -> URL {
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var destinationURL = audioDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1
        
        // If file already exists, append a counter
        while fileManager.fileExists(atPath: destinationURL.path) {
            let newName = "\(originalName)_\(counter).\(fileExtension)"
            destinationURL = audioDirectory.appendingPathComponent(newName)
            counter += 1
        }
        
        return destinationURL
    }
}

// MARK: - Errors

extension FileImportService {
    enum ImportError: LocalizedError {
        case unsupportedFormat(String)
        case fileNotFound(String)
        case invalidPath(String)
        
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                return "Unsupported audio format: .\(ext)"
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .invalidPath(let path):
                return "Invalid file path: \(path)"
            }
        }
    }
}
