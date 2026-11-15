namespace CafeWebApi.Models;

public sealed class OrderTicket
{
    public int Id { get; init; }
    public int StatusId { get; set; }
    public string MemberId { get; set; } = "";
    public string MemberName { get; set; } = "";
    public int TableNumber { get; set; }
    public string CustomerName { get; set; } = "";
    public string Note { get; set; } = "";
    public DateTime Dated { get; set; }
    public DateTime? PaidAtUtc { get; set; }
    public long Total { get; set; }
    public string SearchText { get; set; } = "";
}

public sealed class OrderLine
{
    public int Id { get; init; }
    public int OrderId { get; set; }
    public int ProductId { get; set; }
    public string Name { get; set; } = "";
    public int Quantity { get; set; }
    public int Price { get; set; }
}
