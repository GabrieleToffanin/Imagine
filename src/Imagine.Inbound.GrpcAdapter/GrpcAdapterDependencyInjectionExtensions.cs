using Imagine.Inbound.GrpcAdapter.Services;
using Microsoft.AspNetCore.Builder;

namespace Imagine.Inbound.GrpcAdapter;

public static class GrpcAdapterDependencyInjectionExtensions
{
    public static void MapInfraGrpcServices(this WebApplication app)
    {
        app.MapGrpcService<ImageProcessingService>();
    }
}