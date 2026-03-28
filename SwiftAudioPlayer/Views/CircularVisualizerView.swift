//
//  CircularVisualizerView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI
import QuartzCore
import Combine

// MARK: - Smoothing model

/// Owns the smoothed band buffer and drives frame updates via CADisplayLink.
/// Equivalent to Flutter's AnimationController + _onTick listener.
@MainActor
final class VisualizerModel: ObservableObject {
    @Published private(set) var bands: [Float]
    @Published private(set) var rotationFraction: Double = 0  // 0...1

    private var targetBands: [Float]
    private var bandCount: Int
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private let alpha: Float = 0.3

    /// Pre-computed per-band colors — only depend on band count, not amplitude.
    /// Recomputed only when bandCount changes.
    private(set) var colors: [Color] = []

    init(bandCount: Int) {
        self.bandCount = bandCount
        self.bands = [Float](repeating: 0, count: bandCount)
        self.targetBands = [Float](repeating: 0, count: bandCount)
        self.colors = Self.computeColors(bandCount: bandCount)
    }

    private static func computeColors(bandCount: Int) -> [Color] {
        guard bandCount > 1 else { return [Color(hue: 340.0/360.0, saturation: 0.8, brightness: 0.85)] }
        return (0..<bandCount).map { i in
            let t = Double(i) / Double(bandCount - 1)
            let hue = (340.0 - t * 160.0) / 360.0
            return Color(hue: hue, saturation: 0.8, brightness: 0.85)
        }
    }

    func start() {
        guard displayLink == nil else { return }
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Called by the parent view when new FFT data arrives.
    func updateTarget(_ newBands: [Float]) {
        let count = min(newBands.count, bandCount)
        for i in 0..<count { targetBands[i] = newBands[i] }
        for i in count..<bandCount { targetBands[i] = 0 }
    }

    /// Resize buffers when bandCount changes — no crash, smooth transition.
    func resize(to newCount: Int) {
        guard newCount != bandCount else { return }
        bandCount = newCount
        bands = resized(bands, to: newCount)
        targetBands = resized(targetBands, to: newCount)
        colors = Self.computeColors(bandCount: newCount)
    }

    @objc private func tick(_ link: CADisplayLink) {
        // Rotation: one full revolution every 12 s
        let elapsed = CACurrentMediaTime() - startTime
        rotationFraction = (elapsed / 12.0).truncatingRemainder(dividingBy: 1.0)

        // Lerp each band toward its target in-place (no CoW copy).
        // bands is uniquely owned here so Swift mutates the backing storage directly.
        for i in 0..<bandCount {
            bands[i] += (targetBands[i] - bands[i]) * alpha
        }
    }

    private func resized(_ array: [Float], to count: Int) -> [Float] {
        if array.count == count { return array }
        if array.count > count { return Array(array.prefix(count)) }
        return array + [Float](repeating: 0, count: count - array.count)
    }
}

// MARK: - View

struct CircularVisualizerView: View {
    let fftData: FFTData?
    let bandCount: Int

    @StateObject private var model = VisualizerModel(bandCount: 32)

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            drawVisualizer(context: context, size: size,
                           bands: model.bands,
                           colors: model.colors,
                           rotation: model.rotationFraction * 2 * .pi)
        }
        .onChange(of: fftData) { newData in
            if let bands = newData?.bands {
                model.updateTarget(bands)
            }
        }
        .onChange(of: bandCount) { newCount in
            model.resize(to: newCount)
        }
        .onAppear {
            model.resize(to: bandCount)
            model.start()
        }
        .onDisappear { model.stop() }
    }

    // MARK: - Drawing

    private func drawVisualizer(
        context: GraphicsContext,
        size: CGSize,
        bands: [Float],
        colors: [Color],
        rotation: Double
    ) {
        let n = bands.count
        guard n > 1, colors.count == n else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let side = min(size.width, size.height)
        let innerRadius = side * 0.28
        let maxBarLength = side * 0.22
        let barWidth = (2 * .pi * innerRadius) / Double(n * 2) * 0.55
        let angleStep = Double.pi / Double(n - 1)

        var ctx = context
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: .radians(rotation))

        for i in 0..<n {
            let amplitude = Double(bands[i]).clamped(to: 0...1)
            let barHeight = amplitude * maxBarLength + side * 0.01
            let color = colors[i]  // pre-computed, no allocation

            let angleR = angleStep * Double(i) - .pi / 2
            drawBar(&ctx, angle: angleR, innerRadius: innerRadius,
                    barHeight: barHeight, barWidth: barWidth, color: color)

            let angleL = -angleStep * Double(i) - .pi / 2
            drawBar(&ctx, angle: angleL, innerRadius: innerRadius,
                    barHeight: barHeight, barWidth: barWidth, color: color)
        }
    }

    private func drawBar(
        _ context: inout GraphicsContext,
        angle: Double,
        innerRadius: Double,
        barHeight: Double,
        barWidth: Double,
        color: Color
    ) {
        let cosA = cos(angle)
        let sinA = sin(angle)
        var path = Path()
        path.move(to: CGPoint(x: innerRadius * cosA, y: innerRadius * sinA))
        path.addLine(to: CGPoint(x: (innerRadius + barHeight) * cosA,
                                 y: (innerRadius + barHeight) * sinA))
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: barWidth, lineCap: .round))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

#Preview {
    CircularVisualizerView(
        fftData: FFTData(bands: (0..<32).map { _ in Float.random(in: 0.2...0.9) }),
        bandCount: 32
    )
    .frame(width: 350, height: 350)
    .background(Color.black)
}
