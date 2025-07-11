//
//  ContentView.swift
//  Imagine.UI
//
//  Created by Gabriele Toffanin on 11/07/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: step < 1 ? "%.1f" : "%.0f", value))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

@available(macOS 15.0, *)
struct ContentView: View {
    @StateObject private var viewModel = ImageProcessingViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar with controls
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 0) {
                        HStack {
                            Text("Imagine")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(.regularMaterial)
                        
                        Divider()
                    }
                    
                    // Controls panel
                    ScrollView {
                        VStack(spacing: 24) {
                            // File operations
                            VStack(spacing: 8) {
                                Button(action: {
                                    viewModel.selectImage()
                                }) {
                                    HStack {
                                        Image(systemName: "folder")
                                        Text("Import File")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                                
                                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                        Text("Photos")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                                
                                Button(action: {
                                    viewModel.downloadImage()
                                }) {
                                    HStack {
                                        if viewModel.isDownloading {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "square.and.arrow.down")
                                            Text("Export")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(viewModel.processedImage != nil ? .orange : .gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                                .disabled(viewModel.processedImage == nil || viewModel.isDownloading)
                            }
                            
                            // Image editing controls
                            VStack(spacing: 12) {
                                Text("Adjustments")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(.secondary)
                                
                                VStack(spacing: 16) {
                                    ParameterSlider(
                                        title: "Exposure",
                                        value: Binding(
                                            get: { Double(viewModel.exposure) },
                                            set: { newValue in
                                                viewModel.exposure = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: -2.0...2.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Brightness",
                                        value: Binding(
                                            get: { Double(viewModel.brightness) },
                                            set: { newValue in
                                                viewModel.brightness = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: -1.0...1.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Contrast",
                                        value: Binding(
                                            get: { Double(viewModel.contrast) },
                                            set: { newValue in
                                                viewModel.contrast = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: -1.0...1.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Saturation",
                                        value: Binding(
                                            get: { Double(viewModel.saturation) },
                                            set: { newValue in
                                                viewModel.saturation = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: -1.0...1.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Hue",
                                        value: Binding(
                                            get: { Double(viewModel.hue) },
                                            set: { newValue in
                                                viewModel.hue = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: -180.0...180.0,
                                        step: 1.0
                                    )
                                    
                                    ParameterSlider(
                                        title: "Gamma",
                                        value: Binding(
                                            get: { Double(viewModel.gamma) },
                                            set: { newValue in
                                                viewModel.gamma = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: 0.1...3.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Blur",
                                        value: Binding(
                                            get: { Double(viewModel.blur) },
                                            set: { newValue in
                                                viewModel.blur = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: 0.0...10.0,
                                        step: 0.1
                                    )
                                    
                                    ParameterSlider(
                                        title: "Sharpen",
                                        value: Binding(
                                            get: { Double(viewModel.sharpen) },
                                            set: { newValue in
                                                viewModel.sharpen = Float(newValue)
                                                viewModel.updateParameter()
                                            }
                                        ),
                                        range: 0.0...10.0,
                                        step: 0.1
                                    )
                                }
                                
                                Button("Reset All") {
                                    viewModel.resetAllParameters()
                                    viewModel.updateParameter()
                                }
                                .buttonStyle(.borderless)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(.regularMaterial)
                    
                    // Status bar
                    if !viewModel.uploadStatus.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            Text(viewModel.uploadStatus)
                                .font(.caption)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(width: 280)
                
                // Main image area
                ZStack {
                    Rectangle()
                        .fill(.background)
                    
                    if let selectedImage = viewModel.selectedImage {
                        HStack(spacing: 32) {
                            // Original image
                            VStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.background)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    Image(nsImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(12)
                                        .clipped()
                                }
                                .frame(maxWidth: (geometry.size.width - 280) / 2 - 40, maxHeight: geometry.size.height - 120)
                                
                                Text("Original")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Processed image
                            VStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.background)
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                    
                                    if let processedImage = viewModel.processedImage {
                                        ZStack {
                                            Image(nsImage: processedImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .cornerRadius(12)
                                                .clipped()
                                            
                                            if viewModel.isProcessingLive {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(.black.opacity(0.3))
                                                
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.2)
                                            }
                                        }
                                    } else {
                                        VStack(spacing: 16) {
                                            if viewModel.isProcessingLive {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                                    .scaleEffect(1.5)
                                                Text("Processing...")
                                                    .font(.subheadline)
                                                    .foregroundColor(.accentColor)
                                            } else {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.system(size: 48))
                                                    .foregroundStyle(.quaternary)
                                                Text("Processed image\nwill appear here")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: (geometry.size.width - 280) / 2 - 40, maxHeight: geometry.size.height - 120)
                                
                                Text("Processed")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(viewModel.processedImage != nil ? .green : .secondary)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 72))
                                .foregroundStyle(.quaternary)
                            
                            VStack(spacing: 8) {
                                Text("No image selected")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Import an image to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1200, minHeight: 800)
        .fileImporter(
            isPresented: $viewModel.isImagePickerPresented,
            allowedContentTypes: [
                .image,
                UTType(filenameExtension: "dng")!,
                UTType(filenameExtension: "raw")!,
                UTType(filenameExtension: "cr2")!,
                UTType(filenameExtension: "nef")!,
                UTType(filenameExtension: "arw")!,
                UTType(filenameExtension: "orf")!,
                UTType(filenameExtension: "rw2")!
            ],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleImageSelection(result: result)
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
