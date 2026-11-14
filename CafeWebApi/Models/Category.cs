namespace CafeWebApi.Models;

public sealed class Category
{
    public int Id { get; init; }
    public string Name { get; set; } = "";
    public string NameKey { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon { get; set; } = "";
    public int? ImageId { get; set; }
}

public sealed class MenuImage
{
    public int Id { get; init; }
    public string ContentType { get; set; } = "";
    public byte[] Data { get; set; } = [];
}
