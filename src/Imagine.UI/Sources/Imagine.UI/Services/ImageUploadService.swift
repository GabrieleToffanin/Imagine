//
//  ImageUploadService.swift
//  Imagine.UI
//
//  Created by Gabriele Toffanin on 11/07/25.
//

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(macOS 15.0, *)
actor ImageUploadService {
    
    static func create() async throws -> ImageUploadService {
        return ImageUploadService()
    }
    
    func uploadImage(imageData: Data, imageName: String, exposure: Float = 0.0, brightness: Float = 0.0, contrast: Float = 0.0, saturation: Float = 0.0, hue: Float = 0.0, gamma: Float = 1.0, blur: Float = 0.0, sharpen: Float = 0.0) async throws -> UploadImageResponse {
        return try await withGRPCClient(
            transport: .http2NIOPosix(
                target: .ipv4(host: "127.0.0.1", port: 5062),
                transportSecurity: .plaintext
            )
        ) { client in
            let uploadService = UploadService.Client(wrapping: client)
            
            var options = GRPCCore.CallOptions.defaults
            options.timeout = .seconds(60)
            
            let response = try await uploadService.uploadImageStream(
                metadata: [:],
                options: options,
                requestProducer: { writer in
                    let chunkSize = 64 * 1024 // 64KB chunks
                    var chunkIndex: Int32 = 0
                    var offset = 0
                    
                    while offset < imageData.count {
                        let remainingBytes = imageData.count - offset
                        let currentChunkSize = min(chunkSize, remainingBytes)
                        let chunkData = imageData.subdata(in: offset..<(offset + currentChunkSize))
                        
                        var chunk = UploadImageChunk()
                        chunk.imageName = imageName
                        chunk.imageData = chunkData
                        chunk.chunkIndex = chunkIndex
                        chunk.exposure = exposure
                        chunk.brightness = brightness
                        chunk.contrast = contrast
                        chunk.saturation = saturation
                        chunk.hue = hue
                        chunk.gamma = gamma
                        chunk.blur = blur
                        chunk.sharpen = sharpen
                        
                        try await writer.write(chunk)
                        
                        offset += currentChunkSize
                        chunkIndex += 1
                    }
                }
            )
            return response
        }
    }
}