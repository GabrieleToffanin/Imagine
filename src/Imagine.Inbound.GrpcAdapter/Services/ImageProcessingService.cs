using Grpc.Core;
using Imagine.Inbound.GrpcAdapter.Protos;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Tiff;
using SixLabors.ImageSharp.Formats;
using Google.Protobuf;
using Imagine.Contracts.ImageEditing;
using SixLabors.ImageSharp.PixelFormats;

namespace Imagine.Inbound.GrpcAdapter.Services;

public sealed class ImageProcessingService : UploadService.UploadServiceBase
{
    public override async Task<UploadImageResponse> UploadImageStream(
        IAsyncStreamReader<UploadImageChunk> requestStream,
        ServerCallContext context)
    {
        var imageChunks = new List<UploadImageChunk>();
        var editingParams = new ImageEditingParameters();
        string imageName = string.Empty;
        
        await foreach (var chunk in requestStream.ReadAllAsync())
        {
            imageChunks.Add(chunk);
            // Use parameters from the last chunk (all should be the same)
            editingParams.Exposure = chunk.Exposure;
            editingParams.Brightness = chunk.Brightness;
            editingParams.Contrast = chunk.Contrast;
            editingParams.Saturation = chunk.Saturation;
            editingParams.Hue = chunk.Hue;
            editingParams.Gamma = chunk.Gamma;
            editingParams.Blur = chunk.Blur;
            editingParams.Sharpen = chunk.Sharpen;
            imageName = chunk.ImageName;
            Console.WriteLine($"Received chunk {chunk.ChunkIndex} with editing parameters");
        }
        
        // Process the image with all editing adjustments
        var processedImageBytes = await ProcessImageWithEditing(imageChunks, editingParams);
        
        return new UploadImageResponse
        {
            Status = "Success",
            Message = $"Image processed successfully with editing parameters.",
            ProcessedImage = ByteString.CopyFrom(processedImageBytes),
            OriginalFilename = imageName
        };
    }
    
    private async Task<byte[]> ProcessImageWithEditing(List<UploadImageChunk> chunks, ImageEditingParameters editingParams)
    {
        // Reconstruct the image from chunks
        var orderedChunks = chunks.OrderBy(c => c.ChunkIndex).ToList();
        var totalSize = orderedChunks.Sum(c => c.ImageData.Length);
        var imageData = new byte[totalSize];
        
        var offset = 0;
        foreach (var chunk in orderedChunks)
        {
            Array.Copy(chunk.ImageData.ToByteArray(), 0, imageData, offset, chunk.ImageData.Length);
            offset += chunk.ImageData.Length;
        }
        
        // Detect original format for proper output encoding
        var originalFormat = Image.DetectFormat(imageData);
        
        // Process the image with ImageSharp - enhanced for RAW support
        using var image = LoadImageWithRawSupport(imageData).Result;
        
        // Apply all editing adjustments
        image.Mutate(x =>
        {
            // Apply exposure adjustment
            if (editingParams.Exposure != 0.0f)
            {
                var exposureMultiplier = MathF.Pow(2.0f, editingParams.Exposure);
                x.Brightness(exposureMultiplier);
            }
            
            // Apply brightness adjustment (-1.0 to 1.0)
            if (editingParams.Brightness != 0.0f)
            {
                x.Brightness(1.0f + editingParams.Brightness);
            }
            
            // Apply contrast adjustment (-1.0 to 1.0)
            if (editingParams.Contrast != 0.0f)
            {
                x.Contrast(1.0f + editingParams.Contrast);
            }
            
            // Apply saturation adjustment (-1.0 to 1.0)
            if (editingParams.Saturation != 0.0f)
            {
                x.Saturate(1.0f + editingParams.Saturation);
            }
            
            // Apply hue adjustment (-180 to 180 degrees)
            if (editingParams.Hue != 0.0f)
            {
                x.Hue(editingParams.Hue);
            }
            
            // Apply blur (0 to 10 radius)
            if (editingParams.Blur > 0.0f)
            {
                x.GaussianBlur(editingParams.Blur);
            }
            
            // Apply sharpen (0 to 10 amount)
            if (editingParams.Sharpen > 0.0f)
            {
                x.GaussianSharpen(editingParams.Sharpen);
            }
        });
        
        ApplyGammaCorrection(image, editingParams.Gamma);
        
        // Convert back to byte array using original format
        using var output = new MemoryStream();
        
        // Save using the original format, defaulting to PNG if format is null or unsupported
        if (originalFormat?.Name == "JPEG")
        {
            await image.SaveAsync(output, new JpegEncoder { Quality = 95 });
        }
        else if (originalFormat?.Name == "TIFF")
        {
            await image.SaveAsync(output, new TiffEncoder());
        }
        else
        {
            // Default to PNG for all other formats (including PNG itself)
            await image.SaveAsync(output, new PngEncoder());
        }
        
        return output.ToArray();
    }

    private void ApplyGammaCorrection(Image<Rgba32> image, float editingParamsGamma)
    {
        for (int i = 0; i < image.Height - 1; i++)
        {
            for (int j = 0; j < image.Width; j++)
            {
                var pixel = image[j, i];
                
                // Apply gamma correction
                pixel.R = (byte)(MathF.Pow(pixel.R / 255.0f, editingParamsGamma) * 255);
                pixel.G = (byte)(MathF.Pow(pixel.G / 255.0f, editingParamsGamma) * 255);
                pixel.B = (byte)(MathF.Pow(pixel.B / 255.0f, editingParamsGamma) * 255);
                
                image[j, i] = pixel;
            }
        }
    }

    private Task<Image<Rgba32>> LoadImageWithRawSupport(byte[] imageData)
    {
        try
        {
            // Try to detect format first
            var format = Image.DetectFormat(imageData);
            
            if (format != null)
            {
                Console.WriteLine($"Detected image format: {format.Name}");
                
                // Load with detected format
                return Task.FromResult(Image.Load<Rgba32>(imageData));
            }
            else
            {
                Console.WriteLine("Could not detect image format, attempting generic load");
                
                // Fallback to generic load - ImageSharp will try to auto-detect
                return Task.FromResult(Image.Load<Rgba32>(imageData));
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error loading image with RAW support: {ex.Message}");
            throw new InvalidOperationException($"Failed to load image data: {ex.Message}", ex);
        }
    }
}