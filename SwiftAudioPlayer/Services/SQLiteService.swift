//
//  SQLiteService.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation
import SQLite3

/// Service for managing persistent storage of audio tracks using SQLite
actor SQLiteService {
    
    private var db: OpaquePointer?
    private let dbPath: String
    private static let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = urls[0]
        dbPath = documentsDirectory.appendingPathComponent("audio_tracks.db").path
    }
    
    // MARK: - Setup
    
    func setup() throws {
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(
                domain: "SQLiteService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to open database"])
        }
        
        try createTable()
    }
    
    private func createTable() throws {
        let createTableQuery = """
        CREATE TABLE IF NOT EXISTS audio_tracks (
            id TEXT PRIMARY KEY,
            file_path TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            date_added REAL NOT NULL
        );
        """
        
        var createTableStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, createTableQuery, -1, &createTableStatement, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SQLiteService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare create table statement"])
        }
        
        defer {
            sqlite3_finalize(createTableStatement)
        }
        
        guard sqlite3_step(createTableStatement) == SQLITE_DONE else {
            throw NSError(
                domain: "SQLiteService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create table"])
        }
    }
    
    // MARK: - CRUD Operations
    
    func insertTrack(_ track: AudioTrack) throws {
        guard let db else { throw NSError(domain: "SQLiteService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"]) }
        let insertQuery = """
        INSERT INTO audio_tracks (id, file_path, title, artist, duration_ms, date_added)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var insertStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertQuery, -1, &insertStatement, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SQLiteService",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare insert statement"])
        }
        
        defer {
            sqlite3_finalize(insertStatement)
        }
        
        sqlite3_bind_text(insertStatement, 1, track.id.uuidString, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 2, track.filePath, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 3, track.title, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_text(insertStatement, 4, track.artist, -1, Self.SQLITE_TRANSIENT)
        sqlite3_bind_int64(insertStatement, 5, Int64(track.durationMs))
        sqlite3_bind_double(insertStatement, 6, track.dateAdded.timeIntervalSince1970)
        
        guard sqlite3_step(insertStatement) == SQLITE_DONE else {
            throw NSError(
                domain: "SQLiteService",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Unable to insert track"])
        }
    }
    
    func getAllTracks() throws -> [AudioTrack] {
        guard let db else { throw NSError(domain: "SQLiteService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"]) }
        let queryString = "SELECT id, file_path, title, artist, duration_ms, date_added FROM audio_tracks ORDER BY date_added DESC;"

        var queryStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SQLiteService",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare query statement"])
        }
        
        defer {
            sqlite3_finalize(queryStatement)
        }
        
        var tracks: [AudioTrack] = []
        
        while sqlite3_step(queryStatement) == SQLITE_ROW {
            guard let idString = sqlite3_column_text(queryStatement, 0),
                  let id = UUID(uuidString: String(cString: idString)),
                  let filePathCString = sqlite3_column_text(queryStatement, 1),
                  let titleCString = sqlite3_column_text(queryStatement, 2),
                  let artistCString = sqlite3_column_text(queryStatement, 3)
            else {
                continue
            }
            
            let filePath = String(cString: filePathCString)
            let title = String(cString: titleCString)
            let artist = String(cString: artistCString)
            let durationMs = Int(sqlite3_column_int64(queryStatement, 4))
            let dateAddedTimestamp = sqlite3_column_double(queryStatement, 5)
            let dateAdded = Date(timeIntervalSince1970: dateAddedTimestamp)
            
            let track = AudioTrack(
                id: id,
                filePath: filePath,
                title: title,
                artist: artist,
                durationMs: durationMs,
                dateAdded: dateAdded
            )
            tracks.append(track)
        }
        
        return tracks
    }
    
    func deleteTrack(id: UUID) throws {
        guard let db else { throw NSError(domain: "SQLiteService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Database not initialized"]) }
        let deleteQuery = "DELETE FROM audio_tracks WHERE id = ?;"

        var deleteStatement: OpaquePointer?
        guard sqlite3_prepare_v2(db, deleteQuery, -1, &deleteStatement, nil) == SQLITE_OK else {
            throw NSError(
                domain: "SQLiteService",
                code: 7,
                userInfo: [NSLocalizedDescriptionKey: "Unable to prepare delete statement"])
        }
        
        defer {
            sqlite3_finalize(deleteStatement)
        }
        
        sqlite3_bind_text(deleteStatement, 1, id.uuidString, -1, Self.SQLITE_TRANSIENT)
        
        guard sqlite3_step(deleteStatement) == SQLITE_DONE else {
            throw NSError(
                domain: "SQLiteService",
                code: 8,
                userInfo: [NSLocalizedDescriptionKey: "Unable to delete track"])
        }
    }
    
    deinit {
        sqlite3_close(db)
    }
}
