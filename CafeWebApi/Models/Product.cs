namespace CafeWebApi.Models;

public sealed class Product
{
    public int Id { get; init; }
    public int CategoryId { get; set; }
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public int Price { get; set; }
    public int Stock { get; set; }
    public string ImageUrl { get; set; } = "";
    public int? ImageId { get; set; }
    public string SearchText { get; set; } = "";
}

public sealed class CartItem
{
    public int Id { get; init; }
    public string MemberId { get; set; } = "";
    public int ProductId { get; set; }
    public int Quantity { get; set; }
}
