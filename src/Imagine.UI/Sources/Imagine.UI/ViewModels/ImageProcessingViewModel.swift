//
//  ImageProcessingViewModel.swift
//  Imagine.UI
//
//  Created by Gabriele Toffanin on 11/07/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

@available(macOS 15.0, *)
@MainActor
class ImageProcessingViewModel: ObservableObject {
    @Published var selectedImage: NSImage?
    @Published var processedImage: NSImage?
    @Published var isImagePickerPresented = false
    @Published var uploadStatus = ""
    @Published var isUploading = false
    @Published var exposure: Float = 0.0
    @Published var brightness: Float = 0.0
    @Published var contrast: Float = 0.0
    @Published var saturation: Float = 0.0
    @Published var hue: Float = 0.0
    @Published var gamma: Float = 1.0
    @Published var blur: Float = 0.0
    @Published var sharpen: Float = 0.0
    @Published var isDownloading = false
    @Published var isProcessingLive = false
    
    private var processingDebounceTimer: Timer?
    private let imageUploadService = ImageUploadService()
    
    func selectImage() {
        isImagePickerPresented = true
    }
    
    func handleImageSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            if let image = NSImage(contentsOf: url) {
                selectedImage = image
                processedImage = nil
                uploadStatus = ""
                processingDebounceTimer?.invalidate()
                resetAllParameters()
            }
        case .failure(let error):
            uploadStatus = "Error selecting image: \(error.localizedDescription)"
        }
    }
    
    func processImage() {
        processImageWithParameters(showProgress: true)
    }
    
    func resetAllParameters() {
        exposure = 0.0
        brightness = 0.0
        contrast = 0.0
        saturation = 0.0
        hue = 0.0
        gamma = 1.0
        blur = 0.0
        sharpen = 0.0
    }
    
    func updateParameter() {
        debouncedProcessImage()
    }
    
    private func debouncedProcessImage() {
        guard selectedImage != nil else { return }
        
        processingDebounceTimer?.invalidate()
        
        processingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            Task { @MainActor in
                self.processImageWithParameters(showProgress: false)
            }
        }
    }
    
    private func processImageWithParameters(showProgress: Bool = false) {
        guard let image = selectedImage,
              let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            uploadStatus = "Error processing image"
            return
        }
        
        if isProcessingLive || isUploading { return }
        
        if showProgress {
            isUploading = true
            uploadStatus = "Processing image..."
        } else {
            isProcessingLive = true
        }
        
        Task {
            do {
                let service = try await ImageUploadService.create()
                let response = try await service.uploadImage(
                    imageData: pngData,
                    imageName: "processed_image.png",
                    exposure: exposure,
                    brightness: brightness,
                    contrast: contrast,
                    saturation: saturation,
                    hue: hue,
                    gamma: gamma,
                    blur: blur,
                    sharpen: sharpen
                )
                
                await MainActor.run {
                    isUploading = false
                    isProcessingLive = false
                    
                    if showProgress {
                        uploadStatus = response.message
                    }
                    
                    if !response.processedImage.isEmpty {
                        let processedImageData = Data(response.processedImage)
                        processedImage = NSImage(data: processedImageData)
                    }
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    isProcessingLive = false
                    
                    if showProgress {
                        uploadStatus = "Processing failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
    
    func downloadImage() {
        guard let processedImage = processedImage else { return }
        
        isDownloading = true
        uploadStatus = "Preparing download..."
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png, .jpeg]
        savePanel.nameFieldStringValue = "processed_image.png"
        savePanel.title = "Save Processed Image"
        
        savePanel.begin { result in
            Task { @MainActor in
                self.isDownloading = false
                
                if result == .OK, let url = savePanel.url {
                    self.saveImageToFile(image: processedImage, url: url)
                } else {
                    self.uploadStatus = "Download cancelled"
                }
            }
        }
    }
    
    private func saveImageToFile(image: NSImage, url: URL) {
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData) else {
            uploadStatus = "Error preparing image for download"
            return
        }
        
        let fileExtension = url.pathExtension.lowercased()
        var data: Data?
        
        switch fileExtension {
        case "png":
            data = bitmap.representation(using: .png, properties: [:])
        case "jpg", "jpeg":
            data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        default:
            data = bitmap.representation(using: .png, properties: [:])
        }
        
        guard let finalData = data else {
            uploadStatus = "Error converting image for download"
            return
        }
        
        do {
            try finalData.write(to: url)
            uploadStatus = "Image saved successfully"
        } catch {
            uploadStatus = "Error saving image: \(error.localizedDescription)"
        }
    }
}