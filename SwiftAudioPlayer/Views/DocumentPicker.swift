//
//  DocumentPicker.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
/// Allows users to pick audio files from their device
struct DocumentPicker: UIViewControllerRepresentable {
    
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define supported audio types
        let audioTypes: [UTType] = [
            .mp3,
            .mpeg4Audio,
            .wav,
            .aiff,
            UTType(importedAs: "public.aac-audio"),
            UTType(importedAs: "org.xiph.flac")
        ]
        
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: audioTypes,
            asCopy: true  // Important: copy the file instead of opening in place
        )
        
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        let onCancel: () -> Void
        
        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - View Modifier for Easy Usage

extension View {
    /// Present a document picker for selecting audio files
    func documentPicker(
        isPresented: Binding<Bool>,
        onPick: @escaping ([URL]) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            DocumentPicker(
                onPick: { urls in
                    isPresented.wrappedValue = false
                    onPick(urls)
                },
                onCancel: {
                    isPresented.wrappedValue = false
                }
            )
            .ignoresSafeArea()
        }
    }
}
