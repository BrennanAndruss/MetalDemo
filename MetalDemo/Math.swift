//
//  Math.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 7/2/25.
//

import Foundation
import simd

func toRadians(from angle: Float) -> Float {
    return angle * Float.pi / 180.0
}

func toRadians(from rotation: simd_float3) -> simd_float3 {
    // return simd_float3(toRadians(from: rotation.x), toRadians(from: rotation.y), toRadians(from: rotation.z))
    return rotation * simd_float3(repeating: Float.pi / 180.0)
}

func toFloat3(_ vector: simd_float4) -> simd_float3 {
    return simd_float3(vector[0], vector[1], vector[2])
}

func toFloat3x3(_ matrix: simd_float4x4) -> simd_float3x3 {
    return simd_float3x3(toFloat3(matrix[0]), toFloat3(matrix[1]), toFloat3(matrix[2]))
}

func translateMatrix(matrix: inout simd_float4x4, position: simd_float3) {
    var translationMatrix = matrix_identity_float4x4
    translationMatrix[3] = simd_float4(position.x, position.y, position.z, 1.0)
    matrix *= translationMatrix
}

func rotateMatrix(matrix: inout simd_float4x4, rotation: simd_float3) {
    
    // Create a quaternion from Euler angles
    let qx = simd_quatf(angle: rotation.x, axis: simd_float3(1, 0, 0))
    let qy = simd_quatf(angle: rotation.y, axis: simd_float3(0, 1, 0))
    let qz = simd_quatf(angle: rotation.z, axis: simd_float3(0, 0, 1))
    
    let quat = qx * qy * qz
    
    // Convert quaterion to rotation matrix
    let rotationMatrix = simd_float4x4(quat)
    
    matrix *= rotationMatrix
}

func scaleMatrix(matrix: inout simd_float4x4, scale: simd_float3) {
    matrix[0] *= scale.x
    matrix[1] *= scale.y
    matrix[2] *= scale.z
}

func createViewMatrix(eyePosition: simd_float3, targetPosition: simd_float3, upVec: simd_float3) -> simd_float4x4 {
    let forward = normalize(targetPosition - eyePosition)
    let right = normalize(simd_cross(forward, upVec))
    let up = simd_cross(right, forward)
    
    var matrix = matrix_identity_float4x4
    matrix[0][0] = right.x
    matrix[1][0] = right.y
    matrix[2][0] = right.z
    matrix[0][1] = up.x
    matrix[1][1] = up.y
    matrix[2][1] = up.z
    matrix[0][2] = forward.x
    matrix[1][2] = forward.y
    matrix[2][2] = forward.z
    matrix[3][0] = -dot(right, eyePosition)
    matrix[3][1] = -dot(up, eyePosition)
    matrix[3][2] = -dot(forward, eyePosition)
    
    return matrix
}

func createPerspectiveMatrix(fov: Float, aspectRatio: Float, nearPlane: Float, farPlane: Float) -> simd_float4x4 {
    let tanHalfFov = tan(fov / 2.0)

    var matrix = simd_float4x4(0.0)
    matrix[0][0] = 1.0 / (aspectRatio * tanHalfFov)
    matrix[1][1] = 1.0 / (tanHalfFov)
    matrix[2][2] = farPlane / (farPlane - nearPlane)
    matrix[2][3] = 1.0
    matrix[3][2] = -(farPlane * nearPlane) / (farPlane - nearPlane)
    
    return matrix
}

func createOrthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, zNear: Float, zFar: Float) -> simd_float4x4 {
    var matrix = matrix_identity_float4x4
    matrix[0][0] = 2.0 / (right - left)
    matrix[1][1] = 2.0 / (top - bottom)
    matrix[2][2] = 1.0 / (zFar - zNear)
    matrix[3][0] = -(right + left) / (right - left)
    matrix[3][1] = -(top + bottom) / (top - bottom)
    matrix[3][2] = -zNear / (zFar - zNear)
    
    return matrix
}

func rotateVectorAroundNormal(vec: simd_float3, angle: Float, normal: simd_float3) -> simd_float3 {
    let c = cos(angle)
    let s = sin(angle)

    let axis = normalize(normal)
    let tmp = (1.0 - c) * axis

    var rotationMat = simd_float3x3(1.0)
    rotationMat[0][0] = c + tmp[0] * axis[0]
    rotationMat[0][1] = tmp[0] * axis[1] + s * axis[2]
    rotationMat[0][2] = tmp[0] * axis[2] - s * axis[1]

    rotationMat[1][0] = tmp[1] * axis[0] - s * axis[2]
    rotationMat[1][1] = c + tmp[1] * axis[1]
    rotationMat[1][2] = tmp[1] * axis[2] + s * axis[0]

    rotationMat[2][0] = tmp[2] * axis[0] + s * axis[1]
    rotationMat[2][1] = tmp[2] * axis[1] - s * axis[0]
    rotationMat[2][2] = c + tmp[2] * axis[2]

    return rotationMat * vec
}

extension simd_float3 {
    static let up = simd_float3(0.0, 1.0, 0.0)
}
