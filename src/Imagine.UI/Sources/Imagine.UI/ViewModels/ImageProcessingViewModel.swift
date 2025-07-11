//
//  ImageProcessingViewModel.swift
//  Imagine.UI
//
//  Created by Gabriele Toffanin on 11/07/25.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers
import CoreImage
import PhotosUI
import Combine

@available(macOS 15.0, *)
@MainActor
class ImageProcessingViewModel: ObservableObject {
    @Published var selectedImage: NSImage?
    @Published var processedImage: NSImage?
    @Published var isImagePickerPresented = false
    @Published var selectedPhotoItem: PhotosPickerItem?
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
    private var originalImageURL: URL?
    private var originalImageName: String?
    private var processedImageName: String?
    private var originalImageData: Data?
    
    init() {
        // Observer for PhotosPicker selection
        $selectedPhotoItem
            .compactMap { $0 }
            .sink { [weak self] photoItem in
                Task {
                    await self?.loadImageFromPhotos(photoItem)
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func selectImage() {
        isImagePickerPresented = true
    }
    
    func handleImageSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            let fileExtension = url.pathExtension.lowercased()
            var image: NSImage?
            
            // Check if it's a RAW format
            let rawExtensions = ["dng", "raw", "cr2", "nef", "arw", "orf", "rw2"]
            if rawExtensions.contains(fileExtension) {
                // Handle RAW files using Core Image
                image = loadRawImage(from: url)
            } else {
                // Handle standard image formats
                image = NSImage(contentsOf: url)
            }
            
            if let loadedImage = image {
                selectedImage = loadedImage
                originalImageURL = url
                originalImageName = url.lastPathComponent
                originalImageData = nil // Clear Photos data when loading file
                processedImage = nil
                uploadStatus = ""
                processingDebounceTimer?.invalidate()
                resetAllParameters()
            } else {
                uploadStatus = "Error loading image: Unsupported format or corrupted file"
            }
        case .failure(let error):
            uploadStatus = "Error selecting image: \(error.localizedDescription)"
        }
    }
    
    private func loadRawImage(from url: URL) -> NSImage? {
        // Try to create CIImage from the RAW file
        guard let ciImage = CIImage(contentsOf: url) else {
            print("Failed to create CIImage from RAW file: \(url.lastPathComponent)")
            return nil
        }
        
        // Apply RAW processing options for better quality
        let options: [CIImageOption: Any] = [
            .applyOrientationProperty: true,
            .properties: [:]
        ]
        
        // Re-create with options if needed
        let processedImage = CIImage(contentsOf: url, options: options) ?? ciImage
        
        // Log RAW metadata for debugging
        if let metadata = processedImage.properties as? [String: Any] {
            print("RAW file loaded: \(url.lastPathComponent)")
            print("Image dimensions: \(processedImage.extent.size)")
            
            // Extract common RAW metadata
            if let exifData = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                if let cameraMake = exifData[kCGImagePropertyExifMakerNote as String] {
                    print("Camera make: \(cameraMake)")
                }
            }
            
            if let rawData = metadata[kCGImagePropertyRawDictionary as String] as? [String: Any] {
                print("RAW processing data available")
            }
        }
        
        // Use appropriate color space for RAW processing
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let context = CIContext(options: [.workingColorSpace: colorSpace])
        
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            print("Failed to create CGImage from processed RAW data")
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    private func loadImageFromPhotos(_ photoItem: PhotosPickerItem) async {
        do {
            // Try to load as data first to preserve original format
            if let data = try await photoItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    if let image = NSImage(data: data) {
                        selectedImage = image
                        originalImageName = photoItem.itemIdentifier ?? "photos_image"
                        originalImageURL = nil // Photos don't have file URLs
                        originalImageData = data // Store Photos data
                        processedImage = nil
                        uploadStatus = "Image loaded from Photos"
                        processingDebounceTimer?.invalidate()
                        resetAllParameters()
                    } else {
                        uploadStatus = "Error loading image from Photos"
                    }
                }
            } else {
                await MainActor.run {
                    uploadStatus = "Error loading image from Photos"
                }
            }
        } catch {
            await MainActor.run {
                uploadStatus = "Error loading image from Photos: \(error.localizedDescription)"
            }
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
        guard let image = selectedImage else {
            uploadStatus = "No image selected"
            return
        }
        
        // Get image data in original format if possible
        var imageData: Data?
        
        // Try to get original data first
        if let originalData = getOriginalImageData() {
            imageData = originalData
        } else {
            // Fallback to TIFF representation and convert to PNG
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                uploadStatus = "Error processing image"
                return
            }
            imageData = pngData
        }
        
        guard let finalImageData = imageData else {
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
                    imageData: finalImageData,
                    imageName: originalImageName ?? "processed_image.png",
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
                        processedImageName = response.originalFilename.isEmpty ? originalImageName : response.originalFilename
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
        savePanel.allowedContentTypes = [.png, .jpeg, .tiff]
        savePanel.nameFieldStringValue = processedImageName ?? "processed_image.png"
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
    
    private func getOriginalImageData() -> Data? {
        // Return Photos data if available
        if let photosData = originalImageData {
            return photosData
        }
        
        // Otherwise try to read from file URL
        guard let url = originalImageURL else { return nil }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Error reading original image data: \(error)")
            return nil
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
        case "tiff", "tif":
            data = bitmap.representation(using: .tiff, properties: [:])
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