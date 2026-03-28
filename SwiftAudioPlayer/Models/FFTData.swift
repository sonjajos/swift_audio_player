//
//  FFTData.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import Foundation

struct FFTData: Equatable {
    let bands: [Float]
    let nativeFftTimeUs: Int64

    init(bands: [Float], nativeFftTimeUs: Int64 = 0) {
        self.bands = bands
        self.nativeFftTimeUs = nativeFftTimeUs
    }

    static func == (lhs: FFTData, rhs: FFTData) -> Bool {
        lhs.nativeFftTimeUs == rhs.nativeFftTimeUs && lhs.bands == rhs.bands
    }
}
