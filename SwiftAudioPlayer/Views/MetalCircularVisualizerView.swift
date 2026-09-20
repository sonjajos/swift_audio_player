//
//  MetalCircularVisualizerView.swift
//  SwiftAudioPlayer
//
//  GPU renderer for the circular FFT visualizer using Metal + MTKView.
//  Uses the same VisualizerModel (CADisplayLink smoothing) as the CPU renderer,
//  but replaces SwiftUI Canvas with a single Metal draw call per frame.
//
//  CPU work per frame:
//    - memcpy of bandCount floats → MTLBuffer  (~64–256 bytes, < 1 µs)
//    - One MTLCommandBuffer encode + commit
//  All geometry (positions, colors) is computed in the vertex shader on the GPU.
//

import SwiftUI
import MetalKit
import simd

// MARK: - UIViewRepresentable wrapper

struct MetalCircularVisualizerView: UIViewRepresentable {
    let fftData: FFTData?
    let bandCount: Int

    func makeCoordinator() -> MetalVisualizerCoordinator {
        MetalVisualizerCoordinator(bandCount: bandCount)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = context.coordinator.device
        view.delegate = context.coordinator
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        let coordinator = context.coordinator
        // Forward new FFT target to the shared VisualizerModel
        if let bands = fftData?.bands {
            coordinator.model.updateTarget(bands)
        }
        // Handle band count change
        if bandCount != coordinator.currentBandCount {
            coordinator.resize(to: bandCount)
        }
    }
}

// MARK: - Coordinator (MTKViewDelegate + render state)

@MainActor
final class MetalVisualizerCoordinator: NSObject, MTKViewDelegate {

    // MARK: Shared model (same smoothing logic as CPU renderer)
    let model: VisualizerModel

    // MARK: Metal objects
    let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState

    // MARK: GPU buffers
    // bandsBuffer    — float[]   written every frame from model.bands
    // colorsBuffer   — float4[]  written once at init / on resize
    // uniformsBuffer — float[6]  geometry uniforms, written every frame
    private var bandsBuffer: MTLBuffer
    private var colorsBuffer: MTLBuffer
    private var uniformsBuffer: MTLBuffer

    private(set) var currentBandCount: Int

    // MARK: Geometry constants (recomputed when drawable size or bandCount changes)
    private var drawableHalfShort: Float = 0  // half of shorter drawable dimension, in pixels
    private var innerRadius: Float = 0
    private var maxBarLength: Float = 0
    private var minBarLength: Float = 0
    private var barHalfWidth: Float = 0

    // MARK: Init

    init(bandCount: Int) {
        guard let dev = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        guard let queue = dev.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        self.device = dev
        self.commandQueue = queue
        self.currentBandCount = bandCount
        self.model = VisualizerModel(bandCount: bandCount)

        // Build render pipeline from the .metal shader
        let library = dev.makeDefaultLibrary()!
        let vertexFn   = library.makeFunction(name: "visualizer_vertex")!
        let fragmentFn = library.makeFunction(name: "visualizer_fragment")!

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction   = vertexFn
        descriptor.fragmentFunction = fragmentFn
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // Alpha blending so the black background shows through
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor      = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor  = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor     = .sourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        self.pipelineState = try! dev.makeRenderPipelineState(descriptor: descriptor)

        // Allocate GPU buffers — sized for max supported bandCount (256)
        // so we never reallocate on band count changes; just update the uniform.
        let maxBands = 256
        self.bandsBuffer   = dev.makeBuffer(length: maxBands * MemoryLayout<Float>.stride,
                                            options: .storageModeShared)!
        self.colorsBuffer  = dev.makeBuffer(length: maxBands * MemoryLayout<SIMD4<Float>>.stride,
                                            options: .storageModeShared)!
        self.uniformsBuffer = dev.makeBuffer(length: 6 * MemoryLayout<Float>.stride,
                                             options: .storageModeShared)!

        super.init()

        // Upload initial color palette and start the CADisplayLink
        uploadColors(bandCount: bandCount)
        model.start()
    }

    // MARK: Resize

    func resize(to newCount: Int) {
        model.resize(to: newCount)
        uploadColors(bandCount: newCount)
        currentBandCount = newCount
        recomputeGeometry(bandCount: newCount)
    }

    /// Recomputes all NDC-space geometry constants.
    /// Must be called whenever drawable size OR bandCount changes.
    private func recomputeGeometry(bandCount: Int) {
        let halfShort = drawableHalfShort
        guard halfShort > 0 else { return }
        let side = halfShort * 2
        let innerRadiusPx  = side * 0.28
        let maxBarLengthPx = side * 0.22
        let minBarLengthPx = side * 0.01   // same as CPU: + side * 0.01
        let n = max(bandCount, 1)
        let barWidthPx = Float(2 * Float.pi * innerRadiusPx) / Float(n * 2) * 0.55
        innerRadius  = innerRadiusPx / halfShort
        maxBarLength = maxBarLengthPx / halfShort
        minBarLength = minBarLengthPx / halfShort
        barHalfWidth = (barWidthPx / 2.0) / halfShort
    }

    // MARK: MTKViewDelegate

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let halfShort = Float(min(size.width, size.height) / 2)
        MainActor.assumeIsolated {
            self.drawableHalfShort = halfShort
            self.recomputeGeometry(bandCount: self.currentBandCount)
        }
    }

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            drawOnMain(in: view)
        }
    }

    // MARK: - Render

    private func drawOnMain(in view: MTKView) {
        let n = currentBandCount
        guard n > 0,
              let drawable = view.currentDrawable,
              let passDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else { return }

        // 1. Upload band amplitudes (CPU → GPU, one memcpy, ~n*4 bytes)
        let bandsPtr = bandsBuffer.contents().bindMemory(to: Float.self, capacity: n)
        model.bands.withUnsafeBufferPointer { buf in
            let count = min(buf.count, n)
            bandsPtr.update(from: buf.baseAddress!, count: count)
        }

        // 2. Upload uniforms
        let uniformsPtr = uniformsBuffer.contents().bindMemory(to: Float.self, capacity: 6)
        uniformsPtr[0] = Float(n)
        uniformsPtr[1] = innerRadius
        uniformsPtr[2] = maxBarLength
        uniformsPtr[3] = barHalfWidth
        uniformsPtr[4] = Float(model.rotationFraction * 2 * .pi)
        uniformsPtr[5] = minBarLength

        // 3. Encode single draw call:
        //    totalBars = n * 2 (right half + left mirror)
        //    6 vertices per bar (2 triangles)
        let totalVertices = n * 2 * 6

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(bandsBuffer,    offset: 0, index: 0)
        encoder.setVertexBuffer(colorsBuffer,   offset: 0, index: 1)
        encoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: totalVertices)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // MARK: - Helpers

    private func uploadColors(bandCount: Int) {
        let rawColors = VisualizerModel.computeRawColors(bandCount: bandCount)
        let colorsPtr = colorsBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: bandCount)
        rawColors.withUnsafeBufferPointer { buf in
            colorsPtr.update(from: buf.baseAddress!, count: buf.count)
        }
    }
}

#Preview {
    MetalCircularVisualizerView(
        fftData: FFTData(bands: (0..<BandCount.default).map { _ in Float.random(in: 0.2...0.9) }),
        bandCount: BandCount.default
    )
    .frame(width: 350, height: 350)
    .background(Color.black)
}
