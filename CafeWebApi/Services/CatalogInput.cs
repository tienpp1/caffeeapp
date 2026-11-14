using System.Globalization;
using System.Text.Json;
using CafeWebApi.Models;

namespace CafeWebApi.Services;

public sealed record CategoryInput(string? Name, string? Description, bool RemoveImage, string? ImageBase64);

public sealed record ProductInput(int CategoryId, string? Name, string? Description, int Price, int Stock,
    string? ImageBase64);

internal static class CatalogInput
{
    internal const int MaxImageBytes = 5 * 1024 * 1024;
    internal const int MaxRequestBytes = 8 * 1024 * 1024;

    internal static string Text(string? value, string label, int limit, bool required = true)
    {
        var clean = value?.Trim() ?? "";
        if (required && clean.Length == 0)
            throw new ApiException(400, $"Vui lòng nhập {label.ToLowerInvariant()}.");
        if (clean.Length > limit)
            throw new ApiException(400, $"{label} tối đa {limit} ký tự.");
        return clean;
    }

    internal static async Task<(CategoryInput Input, MenuImage? Image)> CategoryAsync(
        HttpRequest request, CancellationToken cancellation)
    {
        if (!request.HasFormContentType)
        {
            var input = await ReadJsonAsync<CategoryInput>(request, cancellation);
            return (input, DecodeImage(input.ImageBase64));
        }

        var form = await ReadFormAsync(request, cancellation);
        var removeImage = bool.TryParse(form["removeImage"], out var remove) && remove;
        return (new CategoryInput(form["name"], form["description"], removeImage, null),
            await ReadImageAsync(form.Files.GetFile("image"), cancellation));
    }

    internal static async Task<(ProductInput Input, MenuImage? Image)> ProductAsync(
        HttpRequest request, CancellationToken cancellation)
    {
        if (!request.HasFormContentType)
        {
            var input = await ReadJsonAsync<ProductInput>(request, cancellation);
            return (input, DecodeImage(input.ImageBase64));
        }

        var form = await ReadFormAsync(request, cancellation);
        var inputFromForm = new ProductInput(Number(form, "categoryId"), form["name"],
            form["description"], Number(form, "price"), Number(form, "stock"), null);
        return (inputFromForm, await ReadImageAsync(form.Files.GetFile("image"), cancellation));
    }

    private static int Number(IFormCollection form, string key) =>
        int.TryParse(form[key], NumberStyles.Integer, CultureInfo.InvariantCulture, out var result)
            ? result
            : throw new ApiException(400, "Danh mục, giá bán hoặc số lượng tồn không hợp lệ.");

    private static async Task<T> ReadJsonAsync<T>(HttpRequest request, CancellationToken cancellation)
        where T : class
    {
        if (!request.HasJsonContentType())
            throw new ApiException(415, "Dùng JSON hoặc biểu mẫu multipart để gửi dữ liệu.");

        try
        {
            return await request.ReadFromJsonAsync<T>(cancellation)
                ?? throw new ApiException(400, "Dữ liệu không được để trống.");
        }
        catch (JsonException)
        {
            throw new ApiException(400, "Dữ liệu gửi lên không hợp lệ.");
        }
    }

    private static async Task<IFormCollection> ReadFormAsync(HttpRequest request, CancellationToken cancellation)
    {
        try
        {
            return await request.ReadFormAsync(cancellation);
        }
        catch (InvalidDataException)
        {
            throw new ApiException(400, "Biểu mẫu tải ảnh không hợp lệ.");
        }
    }

    private static MenuImage? DecodeImage(string? encoded)
    {
        if (encoded is null)
            return null;
        if (encoded.Length > (MaxImageBytes + 2) / 3 * 4)
            throw new ApiException(400, "Ảnh tối đa 5 MB.");

        try
        {
            return ToImage(Convert.FromBase64String(encoded));
        }
        catch (FormatException)
        {
            throw new ApiException(400, "Ảnh gửi lên không hợp lệ.");
        }
    }

    private static async Task<MenuImage?> ReadImageAsync(IFormFile? file, CancellationToken cancellation)
    {
        if (file is null)
            return null;
        if (file.Length > MaxImageBytes)
            throw new ApiException(400, "Ảnh tối đa 5 MB.");

        using var content = new MemoryStream((int)file.Length);
        await file.CopyToAsync(content, cancellation);
        return ToImage(content.ToArray());
    }

    private static MenuImage ToImage(byte[] bytes)
    {
        if (bytes.Length > MaxImageBytes)
            throw new ApiException(400, "Ảnh tối đa 5 MB.");

        var data = bytes.AsSpan();
        string? type = data.StartsWith(new byte[] { 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a })
            ? "image/png"
            : data.StartsWith(new byte[] { 0xff, 0xd8, 0xff }) ? "image/jpeg" : null;
        if (type is null && data.Length >= 12 && data.StartsWith("RIFF"u8) &&
            data.Slice(8, 4).SequenceEqual("WEBP"u8))
            type = "image/webp";

        return type is null
            ? throw new ApiException(400, "Chỉ hỗ trợ ảnh JPEG, PNG hoặc WebP.")
            : new MenuImage { Data = bytes, ContentType = type };
    }

    internal static async Task DeleteImageAsync(CafeDbContext db, int? imageId, CancellationToken cancellation)
    {
        if (imageId is not int id)
            return;
        var image = await db.Images.FindAsync([id], cancellation);
        if (image is not null)
        {
            db.Images.Remove(image);
            await db.SaveChangesAsync(cancellation);
        }
    }
}
