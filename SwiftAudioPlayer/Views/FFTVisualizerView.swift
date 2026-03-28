//
//  FFTVisualizerView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

struct FFTVisualizerView: View {
    let fftData: FFTData?
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                if let data = fftData, !data.bands.isEmpty {
                    ForEach(0..<data.bands.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(
                                width: (geometry.size.width / CGFloat(data.bands.count)) - 2,
                                height: Swift.max(2, CGFloat(data.bands[index]) * geometry.size.height)
                            )
                            .animation(.easeOut(duration: 0.1), value: data.bands[index])
                    }
                } else {
                    // Placeholder bars when no FFT data
                    ForEach(0..<32, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(
                                width: (geometry.size.width / 32) - 2,
                                height: 4
                            )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(.horizontal)
    }
}

#Preview {
    VStack {
        // With FFT data
        FFTVisualizerView(fftData: FFTData(
            bands: (0..<32).map { _ in Float.random(in: 0.1...0.9) }
        ))
        .frame(height: 200)
        .background(Color.black)
        
        // Without FFT data
        FFTVisualizerView(fftData: nil)
            .frame(height: 200)
            .background(Color.black)
    }
}
