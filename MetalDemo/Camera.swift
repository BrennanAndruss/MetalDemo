//
//  Camera.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 7/10/25.
//

import Foundation
import simd

class Camera {
    var position = simd_float3(0.0, 1.0, 0.0)
    var yaw: Float = 0.0
    var pitch: Float = 0.0
    
    private(set) var forward = simd_float3.zero
    private(set) var right = simd_float3.zero
    private(set) var up = simd_float3.zero
    
    var speed: Float = 5.0
    
    func rotate(rotationAngles: simd_float2) {
        yaw += rotationAngles.x
        pitch += rotationAngles.y
        
        // Clamp pitch to avoid flipping at vertical
        pitch = max(min(pitch, Float.pi / 2 - 0.01), -Float.pi / 2 + 0.01)
        
        self.updateVectors()
    }
    
    func updateVectors() {
        forward = normalize(simd_float3(
            cos(pitch) * sin(yaw),
            sin(pitch),
            cos(pitch) * cos(yaw)
        ))
        right = normalize(cross(forward, simd_float3.up))
        up = normalize(cross(right, forward))
    }
    
    func getViewMatrix() -> simd_float4x4 {
        let center = position + forward
        return createViewMatrix(eyePosition: position, targetPosition: center, upVec: simd_float3.up)
    }
}
