//
//  ContentView.swift
//  Imagine.UI
//
//  Created by Gabriele Toffanin on 11/07/25.
//

import SwiftUI
import UniformTypeIdentifiers

@available(macOS 15.0, *)
struct ContentView: View {
    @State private var selectedImage: NSImage?
    @State private var processedImage: NSImage?
    @State private var isImagePickerPresented = false
    @State private var uploadStatus = ""
    @State private var isUploading = false
    @State private var exposure: Float = 0.0
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Photo Editor")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let selectedImage = selectedImage {
                VStack(spacing: 20) {
                    // Images side by side
                    HStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(nsImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 250, maxHeight: 250)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                            
                            Text("Original")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let processedImage = processedImage {
                            VStack(spacing: 10) {
                                Image(nsImage: processedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 250, maxHeight: 250)
                                    .cornerRadius(12)
                                    .shadow(radius: 8)
                                
                                Text("Processed")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                        } else {
                            VStack(spacing: 10) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(maxWidth: 250, maxHeight: 250)
                                    .cornerRadius(12)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "wand.and.stars")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("Processed image\nwill appear here")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .multilineTextAlignment(.center)
                                        }
                                    )
                                
                                Text("Processed")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Exposure slider
                    VStack(spacing: 10) {
                        Text("Exposure")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            Text("-2.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(exposure) },
                                set: { exposure = Float($0) }
                            ), in: -2.0...2.0, step: 0.1)
                            .accentColor(.blue)
                            
                            Text("+2.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(String(format: "%.1f", exposure))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "photo")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                    
                    Text("No image selected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    isImagePickerPresented = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Select Image")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    uploadImage()
                }) {
                    HStack {
                        if isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Process")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(selectedImage != nil ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
                .disabled(selectedImage == nil || isUploading)
            }
            
            if !uploadStatus.isEmpty {
                Text(uploadStatus)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.primary)
            }
        }
        .padding(40)
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $isImagePickerPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleImageSelection(result: result)
        }
    }
    
    private func handleImageSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if let image = NSImage(contentsOf: url) {
                selectedImage = image
                processedImage = nil // Reset processed image when new image is selected
                uploadStatus = ""
            }
        case .failure(let error):
            uploadStatus = "Error selecting image: \(error.localizedDescription)"
        }
    }
    
    private func uploadImage() {
        guard let image = selectedImage,
              let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            uploadStatus = "Error processing image"
            return
        }
        
        isUploading = true
        uploadStatus = "Processing image..."
        
        Task {
            do {
                let service = try await ImageUploadService.create()
                let response = try await service.uploadImage(
                    imageData: pngData,
                    imageName: "processed_image.png",
                    exposure: exposure
                )
                
                await MainActor.run {
                    isUploading = false
                    uploadStatus = "✅ \(response.message)"
                    
                    // Convert the processed image data to NSImage
                    if !response.processedImage.isEmpty {
                        let processedImageData = Data(response.processedImage)
                        processedImage = NSImage(data: processedImageData)
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadStatus = "❌ Processing failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    if #available(macOS 15.0, *) {
        ContentView()
    } else {
        Text("Requires macOS 15.0 or later")
    }
}
