using Grpc.Core;
using Imagine.Inbound.GrpcAdapter.Protos;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using SixLabors.ImageSharp.Formats.Png;
using Google.Protobuf;

namespace Imagine.Inbound.GrpcAdapter.Services;

public sealed class ImageProcessingService : UploadService.UploadServiceBase
{
    public override async Task<UploadImageResponse> UploadImageStream(
        IAsyncStreamReader<UploadImageChunk> requestStream,
        ServerCallContext context)
    {
        var imageChunks = new List<UploadImageChunk>();
        float exposure = 0.0f;
        string imageName = string.Empty;
        
        await foreach (var chunk in requestStream.ReadAllAsync())
        {
            imageChunks.Add(chunk);
            exposure = chunk.Exposure; // Use exposure from the last chunk (all should be the same)
            imageName = chunk.ImageName;
            Console.WriteLine($"Received chunk {chunk.ChunkIndex} with exposure {chunk.Exposure}");
        }
        
        // Process the image with exposure adjustment
        var processedImageBytes = await ProcessImageWithExposure(imageChunks, exposure);
        
        Console.WriteLine($"Processed image '{imageName}' with exposure {exposure}, total chunks: {imageChunks.Count}");
        
        return new UploadImageResponse
        {
            Status = "Success",
            Message = $"Image processed successfully with exposure {exposure:F2}.",
            ProcessedImage = ByteString.CopyFrom(processedImageBytes)
        };
    }
    
    private async Task<byte[]> ProcessImageWithExposure(List<UploadImageChunk> chunks, float exposure)
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
        
        // Process the image with ImageSharp
        using var image = Image.Load(imageData);
        
        // Apply exposure adjustment
        // Exposure is typically applied as a brightness multiplier
        // Exposure value of 1.0 means 2x brighter, -1.0 means 0.5x darker
        var exposureMultiplier = MathF.Pow(2.0f, exposure);
        
        image.Mutate(x => x.Brightness(exposureMultiplier));
        
        // Convert back to byte array
        using var output = new MemoryStream();
        await image.SaveAsync(output, new PngEncoder());
        var processedBytes = output.ToArray();
        
        Console.WriteLine($"Applied exposure adjustment: {exposure:F2} (multiplier: {exposureMultiplier:F2}) to {imageData.Length} bytes, result: {processedBytes.Length} bytes");
        
        return processedBytes;
    }
}