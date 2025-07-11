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
    @StateObject private var viewModel = ImageProcessingViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar with controls
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Imagine")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    // Controls panel
                    VStack(spacing: 20) {
                        // File operations
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.selectImage()
                            }) {
                                HStack {
                                    Image(systemName: "folder")
                                        .font(.system(size: 14))
                                    Text("Import")
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.borderless)
                            
                            Button(action: {
                                viewModel.downloadImage()
                            }) {
                                HStack {
                                    if viewModel.isDownloading {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                            .font(.system(size: 14))
                                        Text("Download")
                                            .font(.system(size: 14))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(viewModel.processedImage != nil ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.borderless)
                            .disabled(viewModel.processedImage == nil || viewModel.isDownloading)
                        }
                        
                        Divider()
                        
                        // Exposure controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exposure")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("-2.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("+2.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: Binding(
                                    get: { Double(viewModel.exposure) },
                                    set: { newValue in
                                        viewModel.updateExposure(Float(newValue))
                                    }
                                ), in: -2.0...2.0, step: 0.1)
                                .accentColor(.blue)
                                
                                Text(String(format: "%.1f", viewModel.exposure))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Spacer()
                        
                        // Status
                        if !viewModel.uploadStatus.isEmpty {
                            Text(viewModel.uploadStatus)
                                .font(.caption)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
                .frame(width: 250)
                
                // Main image area
                ZStack {
                    Color(NSColor.controlBackgroundColor).opacity(0.1)
                    
                    if let selectedImage = viewModel.selectedImage {
                        HStack(spacing: 20) {
                            // Original image
                            VStack(spacing: 8) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.05))
                                        .cornerRadius(8)
                                    
                                    Image(nsImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(8)
                                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                .frame(maxWidth: (geometry.size.width - 250) / 2 - 30, maxHeight: geometry.size.height - 100)
                                
                                Text("Original")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Processed image
                            VStack(spacing: 8) {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.05))
                                        .cornerRadius(8)
                                    
                                    if let processedImage = viewModel.processedImage {
                                        ZStack {
                                            Image(nsImage: processedImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .cornerRadius(8)
                                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                            
                                            if viewModel.isProcessingLive {
                                                Rectangle()
                                                    .fill(Color.black.opacity(0.3))
                                                    .cornerRadius(8)
                                                
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(1.2)
                                            }
                                        }
                                    } else {
                                        VStack(spacing: 12) {
                                            if viewModel.isProcessingLive {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                    .scaleEffect(1.2)
                                                Text("Processing...")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            } else {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.system(size: 32))
                                                    .foregroundColor(.gray)
                                                Text("Processed image\nwill appear here")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: (geometry.size.width - 250) / 2 - 30, maxHeight: geometry.size.height - 100)
                                
                                Text("Processed")
                                    .font(.caption)
                                    .foregroundColor(viewModel.processedImage != nil ? .green : .secondary)
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            
                            Text("No image selected")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            Text("Import an image to get started")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .fileImporter(
            isPresented: $viewModel.isImagePickerPresented,
            allowedContentTypes: [.image],
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
