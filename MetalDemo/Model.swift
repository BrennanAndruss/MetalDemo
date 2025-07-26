//
//  Model.swift
//  MetalDemo
//
//  Created by Brennan Andruss on 7/12/25.
//

import MetalKit

struct Material {
    var diffuseTexture: MTLTexture?
    var specularTexture: MTLTexture?
    var normalTexture: MTLTexture?
    
    var alphaClipped: Bool = false
    
    static var textureMap: [MDLTexture?: MTLTexture?] = [:]
    
    init(mdlMaterial: MDLMaterial?, textureLoader: MTKTextureLoader) {
        self.diffuseTexture = loadTexture(.baseColor, mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        self.specularTexture = loadTexture(.specular, mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        self.normalTexture = loadTexture(.tangentSpaceNormal, mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        
        if let alphaMode = mdlMaterial?.property(with: .opacity), alphaMode.floatValue < 1.0 {
            self.alphaClipped = true
        }
    }
    
    func loadTexture(_ semantic: MDLMaterialSemantic, mdlMaterial: MDLMaterial?, textureLoader: MTKTextureLoader) -> MTLTexture? {
        guard let materialProperty = mdlMaterial?.property(with: semantic) else { return nil }
        guard let sourceTexture = materialProperty.textureSamplerValue?.texture else { return nil } 
        
        if let texture = Material.textureMap[sourceTexture] {
            return texture
        }
        
        let wantsMips = sourceTexture.dimensions.x >= 2 && sourceTexture.dimensions.y >= 2
        let texture = try? textureLoader.newTexture(texture: sourceTexture, options: [.generateMipmaps: wantsMips])
        Material.textureMap[sourceTexture] = texture
        
        return texture
    }
}

class Mesh {
    var mesh: MTKMesh
    var materials: [Material]
    
    init(mesh: MTKMesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}

struct ModelMatrix {
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

struct MaterialInfo {
    var hasDiffuseTexture: Bool
    var hasSpecularTexture: Bool
    var hasNormalTexture: Bool
}

class Model {
    var meshes = [Mesh]()
    
    var position = simd_float3(repeating: 0.0)
    var rotation = simd_float3(repeating: 0.0)
    var scale = simd_float3(repeating: 1.0)
    
    func loadModel(device: MTLDevice, url: URL, vertexDescriptor: MTLVertexDescriptor, textureLoader: MTKTextureLoader) {
        let modelVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        
        // Tell the model loader what the attributes represent
        let attrPosition = modelVertexDescriptor.attributes[0] as! MDLVertexAttribute
        attrPosition.name = MDLVertexAttributePosition
        modelVertexDescriptor.attributes[0] = attrPosition
        
        let attrTexCoord = modelVertexDescriptor.attributes[1] as! MDLVertexAttribute
        attrTexCoord.name = MDLVertexAttributeTextureCoordinate
        modelVertexDescriptor.attributes[1] = attrTexCoord
        
        let attrNormal = modelVertexDescriptor.attributes[2] as! MDLVertexAttribute
        attrNormal.name = MDLVertexAttributeNormal
        modelVertexDescriptor.attributes[2] = attrNormal
        
        let attrTangent = modelVertexDescriptor.attributes[3] as! MDLVertexAttribute
        attrTangent.name = MDLVertexAttributeTangent
        modelVertexDescriptor.attributes[3] = attrTangent
        
        // Load the model
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: modelVertexDescriptor, bufferAllocator: bufferAllocator)
        
        // Load data for the textures
        asset.loadTextures()
        
        // Retrieve the meshes
        guard let (mdlMeshes, mtkMeshes) = try? MTKMesh.newMeshes(asset: asset, device: device) else {
            print("Failed to create meshes")
            return
        }
        
        self.meshes.reserveCapacity(mdlMeshes.count)
        
        // Create the meshes
        for (mdlMesh, mtkMesh) in zip(mdlMeshes, mtkMeshes) {
            mdlMesh.addOrthTanBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate, normalAttributeNamed: MDLVertexAttributeNormal, tangentAttributeNamed: MDLVertexAttributeTangent)
            var materials = [Material]()
            for mdlSubmesh in mdlMesh.submeshes as! [MDLSubmesh] {
                let material = Material(mdlMaterial: mdlSubmesh.material, textureLoader: textureLoader)
                materials.append(material)
            }
            
            let mesh = Mesh(mesh: mtkMesh, materials: materials)
            self.meshes.append(mesh)
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder, bindTextures: Bool) {
        // Create the model matrix and normal matrix
        var modelMatrix = matrix_identity_float4x4
        translateMatrix(matrix: &modelMatrix, position: self.position)
        rotateMatrix(matrix: &modelMatrix, rotation: toRadians(from: self.rotation))
        scaleMatrix(matrix: &modelMatrix, scale: self.scale)
        let normalMatrix = simd_transpose(simd_inverse(toFloat3x3(modelMatrix)))
        
        var model = ModelMatrix(modelMatrix: modelMatrix, normalMatrix: normalMatrix)
        renderEncoder.setVertexBytes(&model, length: MemoryLayout.stride(ofValue: model), index: 1)
        
        for mesh in self.meshes {
            // Bind vertex buffer
            let vertexBuffer = mesh.mesh.vertexBuffers[0]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 30)
            for (submesh, material) in zip(mesh.mesh.submeshes, mesh.materials) {
                // Set cull mode
                if material.alphaClipped {
                    renderEncoder.setCullMode(.none)
                } else {
                    renderEncoder.setCullMode(.back)
                }
                
                // Bind textures
                if bindTextures {
                    renderEncoder.setFragmentTexture(material.diffuseTexture, index: 1)
                    renderEncoder.setFragmentTexture(material.specularTexture, index: 2)
                    renderEncoder.setFragmentTexture(material.normalTexture, index: 3)
                }
                
                // Upload material info
                var materialInfo = MaterialInfo(hasDiffuseTexture: material.diffuseTexture != nil, hasSpecularTexture: material.specularTexture != nil, hasNormalTexture: material.normalTexture != nil)
                renderEncoder.setFragmentBytes(&materialInfo, length: MemoryLayout.stride(ofValue: materialInfo), index: 2)
                
                // Draw
                let indexBuffer = submesh.indexBuffer
                renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: 0)
            }
        }
    }
}
