//
//  Vertex.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 7/14/25.
//

import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
    var normal: simd_float3
    var tangent: simd_float4
}
