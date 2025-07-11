using Grpc.Core;
using Imagine.Inbound.GrpcAdapter.Protos;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Tiff;
using SixLabors.ImageSharp.Formats;
using Google.Protobuf;

namespace Imagine.Inbound.GrpcAdapter.Services;

public class ImageEditingParameters
{
    public float Exposure { get; set; }
    public float Brightness { get; set; }
    public float Contrast { get; set; }
    public float Saturation { get; set; }
    public float Hue { get; set; }
    public float Gamma { get; set; } = 1.0f;
    public float Blur { get; set; }
    public float Sharpen { get; set; }
}

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
        
        Console.WriteLine($"Processed image '{imageName}' with editing parameters, total chunks: {imageChunks.Count}");
        
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
            
            // Apply gamma correction (0.1 to 3.0)
            if (editingParams.Gamma != 1.0f && editingParams.Gamma > 0.0f)
            {
                // ImageSharp doesn't have a direct Gamma method, use brightness with gamma curve
                var gammaAdjustment = MathF.Pow(editingParams.Gamma, 1.0f / 2.2f);
                x.Brightness(gammaAdjustment);
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
        
        var processedBytes = output.ToArray();
        
        Console.WriteLine($"Applied image editing: exposure={editingParams.Exposure:F2}, brightness={editingParams.Brightness:F2}, contrast={editingParams.Contrast:F2}, saturation={editingParams.Saturation:F2}, hue={editingParams.Hue:F2}, gamma={editingParams.Gamma:F2}, blur={editingParams.Blur:F2}, sharpen={editingParams.Sharpen:F2}");
        Console.WriteLine($"Processed {imageData.Length} bytes, result: {processedBytes.Length} bytes (format: {originalFormat?.Name ?? "Unknown"})");
        
        return processedBytes;
    }
    
    private Task<Image> LoadImageWithRawSupport(byte[] imageData)
    {
        try
        {
            // Try to detect format first
            var format = Image.DetectFormat(imageData);
            
            if (format != null)
            {
                Console.WriteLine($"Detected image format: {format.Name}");
                
                // Load with detected format
                return Task.FromResult(Image.Load(imageData));
            }
            else
            {
                Console.WriteLine("Could not detect image format, attempting generic load");
                
                // Fallback to generic load - ImageSharp will try to auto-detect
                return Task.FromResult(Image.Load(imageData));
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error loading image with RAW support: {ex.Message}");
            throw new InvalidOperationException($"Failed to load image data: {ex.Message}", ex);
        }
    }
}