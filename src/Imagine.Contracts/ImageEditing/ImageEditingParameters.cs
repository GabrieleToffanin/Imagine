namespace Imagine.Contracts.ImageEditing;

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