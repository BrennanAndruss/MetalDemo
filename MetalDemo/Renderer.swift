//
//  Renderer.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 6/28/25.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd
import GameController

class Renderer : NSObject, MTKViewDelegate {
    // Metal objects
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var depthStencilState: MTLDepthStencilState?
    
    // Passes
    var mainPass: MainPass
    var shadowPass: ShadowPass
    
    // Models
    var sponzaModel: Model?
    
    // Window objects
    var windowSize: CGSize = CGSizeZero
    var aspectRatio: Float = 1.0
    
    // Camera
    var camera = Camera()
    
    // Light
    let lightDirection = simd_float3(0.436436, -0.872872, 0.218218)
    
    // Input devices
    var keyboards = Array<GCKeyboard>()
    var rightJoystick = simd_float2(0.0, 0.0)
    
    // Time
    var lastTime: Double
    
    init?(metalKitView: MTKView) {
        // Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        
        // Library
        let library = device.makeDefaultLibrary()!
        
        // Passes
        self.mainPass = MainPass(device: self.device, library: library, view: metalKitView)
        self.shadowPass = ShadowPass(device: self.device, library: library)
        
        // Depth stencil state
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = self.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        // Loading models
        let textureLoader = MTKTextureLoader(device: self.device)
        
        let sponzaURL = Bundle.main.url(forResource: "Sponza_Scene", withExtension: "usdz")!
        self.sponzaModel = Model()
        self.sponzaModel?.scale = simd_float3(repeating: 0.004)
        self.sponzaModel?.loadModel(device: self.device, url: sponzaURL, vertexDescriptor: self.mainPass.vertexDescriptor, textureLoader: textureLoader)
        
        // Time
        lastTime = Date().timeIntervalSince1970
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        // Delta time
        let currentTime = Date().timeIntervalSince1970
        let deltaTime = Float(currentTime - lastTime)
        lastTime = currentTime
        
        var moveDirection = simd_float3(0.0, 0.0, 0.0)
        for keyboard in keyboards {
            if keyboard.keyboardInput!.button(forKeyCode: .keyW)!.value > 0.5 {
                moveDirection.y += 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyA)!.value > 0.5 {
                moveDirection.x -= 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyS)!.value > 0.5 {
                moveDirection.y -= 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyD)!.value > 0.5 {
                moveDirection.x += 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyE)!.value > 0.5 {
                moveDirection.z += 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyQ)!.value > 0.5 {
                moveDirection.z -= 1.0
            }
        }
        
        // Move the camera
        if moveDirection.x != 0.0 || moveDirection.y != 0.0 || moveDirection.z != 0.0 {
            moveDirection = normalize(moveDirection)
        }
        
        camera.position += camera.right * moveDirection.x * deltaTime * camera.speed
        camera.position += camera.forward * moveDirection.y * deltaTime * camera.speed
        camera.position += camera.up * moveDirection.z * deltaTime * camera.speed
        
        // Rotate the camera
        camera.rotate(rotationAngles: simd_float2(-rightJoystick.x, rightJoystick.y))
        rightJoystick = simd_float2(0.0, 0.0)
        
        // Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        // Create perspective and view matrices from the camera
        let projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: self.aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        let viewMatrix = self.camera.getViewMatrix()
        var viewProjMatrix = projectionMatrix * viewMatrix
        
        // Create perspective and view matrices from the light
        let lightProjectionMatrix = createOrthographicMatrix(left: -10.0, right: 10.0, bottom: -10.0, top: 10.0, zNear: -25.0, zFar: 25.0)
        let lightViewMatrix = createViewMatrix(eyePosition: -lightDirection, targetPosition: simd_float3(repeating: 0.0), upVec: simd_float3.up)
        var lightViewProjMatrix = lightProjectionMatrix * lightViewMatrix

        // Render passes
        self.shadowPass.encode(commandBuffer: commandBuffer, depthStencilState: self.depthStencilState!,
                               render: { (renderEncoder: MTLRenderCommandEncoder) in
            self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: false)
        }, viewProjMatrix: &lightViewProjMatrix)
        
        self.mainPass.encode(commandBuffer: commandBuffer, view: view, depthStencilState: self.depthStencilState!,
                             render: { (renderEncoder: MTLRenderCommandEncoder) in
            self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: true)
        }, viewPosition: &self.camera.position, viewProjMatrix: &viewProjMatrix, lightViewProjMatrix: &lightViewProjMatrix, shadowMap: self.shadowPass.shadowMap)
        
        // Retrieve drawable and present it to the screen
        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
        
        // Send commands to the GPU
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.windowSize = size
        self.aspectRatio = Float(self.windowSize.width) / Float(self.windowSize.height)
    }
}
