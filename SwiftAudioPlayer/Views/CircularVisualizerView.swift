//
//  CircularVisualizerView.swift
//  SwiftAudioPlayer
//
//  Router that switches between the GPU (Metal + MTKView) and CPU (SwiftUI Canvas)
//  renderers based on the `VisualizerRenderer.useMetal` flag in Constants.swift.
//
//  To compare renderers:
//    VisualizerRenderer.useMetal = true   → MetalCircularVisualizerView  (GPU)
//    VisualizerRenderer.useMetal = false  → CPUCircularVisualizerView    (CPU / Core Graphics)
//

import SwiftUI

struct CircularVisualizerView: View {
    let fftData: FFTData?
    let bandCount: Int

    var body: some View {
        if VisualizerRenderer.useMetal {
            MetalCircularVisualizerView(fftData: fftData, bandCount: bandCount)
        } else {
            CPUCircularVisualizerView(fftData: fftData, bandCount: bandCount)
        }
    }
}

#Preview {
    CircularVisualizerView(
        fftData: FFTData(bands: (0..<BandCount.default).map { _ in Float.random(in: 0.2...0.9) }),
        bandCount: BandCount.default
    )
    .frame(width: 350, height: 350)
    .background(Color.black)
}
