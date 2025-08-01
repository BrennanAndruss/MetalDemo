//
//  MainPass.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 7/14/25.
//

import Metal
import MetalKit
import simd

class MainPass {
    var vertexDescriptor: MTLVertexDescriptor
    
    var renderPipelineState: MTLRenderPipelineState?
    
    var shadowSampler: MTLSamplerState
    
    init(device: MTLDevice, library: MTLLibrary, view: MTKView) {
        // Vertex descriptor
        self.vertexDescriptor = MTLVertexDescriptor()
        
        self.vertexDescriptor.layouts[30].stride = MemoryLayout<Vertex>.stride
        self.vertexDescriptor.layouts[30].stepRate = 1
        self.vertexDescriptor.layouts[30].stepFunction = MTLVertexStepFunction.perVertex

        self.vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        self.vertexDescriptor.attributes[0].offset = MemoryLayout.offset(of: \Vertex.position)!
        self.vertexDescriptor.attributes[0].bufferIndex = 30

        self.vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
        self.vertexDescriptor.attributes[1].offset = MemoryLayout.offset(of: \Vertex.texCoord)!
        self.vertexDescriptor.attributes[1].bufferIndex = 30
        
        self.vertexDescriptor.attributes[2].format = MTLVertexFormat.float3
        self.vertexDescriptor.attributes[2].offset = MemoryLayout.offset(of: \Vertex.normal)!
        self.vertexDescriptor.attributes[2].bufferIndex = 30
        
        self.vertexDescriptor.attributes[3].format = MTLVertexFormat.float4
        self.vertexDescriptor.attributes[3].offset = MemoryLayout.offset(of: \Vertex.tangent)!
        self.vertexDescriptor.attributes[3].bufferIndex = 30
        
        // Functions
        let vertexFunction = library.makeFunction(name: "vertexFunction")!
        let fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        // Render pipeline descriptor
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state")
        }
        
        // Shadow sampler
        let shadowSamplerDescriptor = MTLSamplerDescriptor()
        shadowSamplerDescriptor.minFilter = MTLSamplerMinMagFilter.linear
        shadowSamplerDescriptor.magFilter = MTLSamplerMinMagFilter.linear
        shadowSamplerDescriptor.compareFunction = MTLCompareFunction.less
        self.shadowSampler = device.makeSamplerState(descriptor: shadowSamplerDescriptor)!
    }
    
    func encode(commandBuffer: MTLCommandBuffer, view: MTKView, depthStencilState: MTLDepthStencilState,
                render: (MTLRenderCommandEncoder) -> Void, viewPosition: inout simd_float3, viewProjMatrix: inout float4x4,
                lightViewProjMatrix: inout float4x4, shadowMap: MTLTexture) {
        
        // Configure render pass descriptor
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.42, green: 0.64, blue: 0.72, alpha: 1.0)
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        // Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Bind render pipeline state and depth stencil state
        renderEncoder.setRenderPipelineState(self.renderPipelineState!)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Discard back faces
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setCullMode(.back)
        
        // Upload view projection matrix
        renderEncoder.setVertexBytes(&viewProjMatrix, length: MemoryLayout.stride(ofValue: viewProjMatrix), index: 0)
        
        // Upload light view projection matrix
        renderEncoder.setFragmentBytes(&lightViewProjMatrix, length: MemoryLayout.stride(ofValue: lightViewProjMatrix), index: 1)
        
        // Upload view position
        renderEncoder.setFragmentBytes(&viewPosition, length: MemoryLayout.stride(ofValue: viewPosition), index: 0)
        
        // Bind the shadow map and shadow sampler
        renderEncoder.setFragmentTexture(shadowMap, index: 0)
        renderEncoder.setFragmentSamplerState(self.shadowSampler, index: 0)
        
        // Render
        render(renderEncoder)
        
        // End encoding
        renderEncoder.endEncoding()
    }
}
