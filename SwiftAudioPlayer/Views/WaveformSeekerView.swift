//
//  WaveformSeekerView.swift
//  SwiftAudioPlayer
//
//  Created by Sonja Josanov on 28. 3. 2026.
//

import SwiftUI

/// Waveform seeker — renders normalized RMS peaks as vertical bars split into
/// played (active, cyan) and remaining (inactive, dim cyan) sections.
/// Mirrors Flutter's WaveformSeeker widget pixel-for-pixel.
struct WaveformSeekerView: View {

    /// Normalized peaks in [0, 1]. Nil triggers a loading placeholder.
    let peaks: [Float]?
    let currentPositionMs: Int
    let durationMs: Int
    let isPlaying: Bool

    /// Frozen progress value — only updates while playing so the waveform
    /// doesn't animate/ease when paused.
    @State private var frozenProgress: Double = 0

    private var liveProgress: Double {
        guard durationMs > 0 else { return 0 }
        return Double(currentPositionMs) / Double(durationMs)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Border container matching Flutter's BoxDecoration
            WaveformCanvas(peaks: peaks, progress: frozenProgress)
                .onChange(of: currentPositionMs) { _ in
                    if isPlaying { frozenProgress = liveProgress }
                }
                .onChange(of: isPlaying) { playing in
                    // Snap to current position when resuming
                    if playing { frozenProgress = liveProgress }
                }
                .onAppear {
                    frozenProgress = liveProgress
                }
                .frame(height: 50)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: 0x364EF2C1)).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(hex: 0x364EF2C1)).frame(height: 1)
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(hex: 0xFF4EF2C1)).frame(width: 3)
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(Color(hex: 0xFF4EF2C1)).frame(width: 3)
                }

            // Time labels
            HStack {
                Text(formatMs(currentPositionMs))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.white)
                Spacer()
                Text(formatMs(durationMs))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4)
        }
    }

    private func formatMs(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let m = totalSec / 60
        let s = totalSec % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

// MARK: - Canvas

private struct WaveformCanvas: View {
    let peaks: [Float]?
    let progress: Double

    var body: some View {
        Canvas { ctx, size in
            if let peaks = peaks, !peaks.isEmpty {
                drawBars(ctx: ctx, size: size, peaks: peaks)
            } else {
                drawPlaceholder(ctx: ctx, size: size)
            }
        }
    }

    private func drawBars(ctx: GraphicsContext, size: CGSize, peaks: [Float]) {
        let cw = size.width
        let midY = size.height / 2
        let progressX = progress.clamped(to: 0...1) * cw

        let barCount = peaks.count
        let barW = cw / CGFloat(barCount)
        let gap = max(1.0, barW * 0.25)
        let bW = max(1.0, barW - gap)
        let radius = bW / 2

        let activeColor = Color(hex: 0xFF00E5FF)
        let inactiveColor = Color(hex: 0x2200E5FF)
        let tipColor = Color(hex: 0x59FFFFFF)

        for i in 0..<barCount {
            let peak = Double(peaks[i]).clamped(to: 0...1)
            let barH = max(3.0, peak * Double(midY) * 0.85)
            let x = CGFloat(i) * barW + gap / 2
            let barCenter = x + bW / 2

            let rect = CGRect(x: x, y: midY - barH, width: bW, height: barH * 2)
            let rrect = RoundedRectangle(cornerRadius: radius)

            if barCenter <= progressX {
                // Active bar
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: radius),
                    with: .color(activeColor)
                )
                // White tip
                let tipH = max(2.0, barH * 0.2)
                ctx.fill(
                    Path(roundedRect: CGRect(x: x, y: midY - barH, width: bW, height: tipH * 2),
                         cornerRadius: bW / 2),
                    with: .color(tipColor)
                )
                _ = rrect // suppress warning
            } else {
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: radius),
                    with: .color(inactiveColor)
                )
            }
        }
    }

    private func drawPlaceholder(ctx: GraphicsContext, size: CGSize) {
        let cw = size.width
        let midY = size.height / 2
        let lineColor = Color(hex: 0x3300E5FF)
        let tickColor = Color(hex: 0x5500E5FF)

        // Center line
        ctx.stroke(
            Path { p in
                p.move(to: CGPoint(x: 0, y: midY))
                p.addLine(to: CGPoint(x: cw, y: midY))
            },
            with: .color(lineColor),
            lineWidth: 1
        )

        // Loading ticks
        let tickCount = 60
        for i in 0..<tickCount {
            let x = (CGFloat(i) / CGFloat(tickCount - 1)) * cw
            let envelope = 0.18 + 0.22 * abs(sin(Double(i) * 0.53))
            let tickH = envelope * Double(midY)
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: x, y: midY - tickH))
                    p.addLine(to: CGPoint(x: x, y: midY + tickH))
                },
                with: .color(tickColor),
                lineWidth: 1.5
            )
        }
    }
}

// MARK: - Helpers

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    /// Initialize from a hex integer, e.g. 0xFF00E5FF (ARGB)
    init(hex: UInt32) {
        let a = Double((hex >> 24) & 0xFF) / 255.0
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
