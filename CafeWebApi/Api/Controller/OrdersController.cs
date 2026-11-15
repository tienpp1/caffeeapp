using System.Data;
using System.Globalization;
using System.Security.Claims;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/orders")]
public sealed class OrdersController(CafeDbContext db) : ControllerBase
{
    private const int PaidStatusId = 6;
    private static readonly TimeSpan CafeUtcOffset = TimeSpan.FromHours(7);
    private string MemberId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    [HttpGet]
    public async Task<IActionResult> List(bool admin = false, string? search = null, string? date = null,
        CancellationToken cancellation = default)
    {
        var query = VisibleOrders(admin);
        var keyword = TextSearch.Normalize(search ?? "");
        if (keyword.StartsWith('#') && int.TryParse(keyword.AsSpan(1), out var number))
            query = query.Where(order => order.Id == number);
        else if (keyword.Length > 0)
            query = query.Where(order => order.SearchText.Contains(keyword) || order.Id.ToString().Contains(keyword));

        if (!string.IsNullOrEmpty(date))
        {
            if (!DateOnly.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture,
                    DateTimeStyles.None, out var day) || day == DateOnly.MinValue || day == DateOnly.MaxValue)
                throw new ApiException(400, "Ngày phải có định dạng yyyy-MM-dd.");

            // The café's reporting day is based on local time in Vietnam.
            var start = new DateTimeOffset(day.ToDateTime(TimeOnly.MinValue), CafeUtcOffset).UtcDateTime;
            var end = start.AddDays(1);
            query = query.Where(order => order.Dated >= start && order.Dated < end);
        }

        var orders = await Project(query.OrderByDescending(order => order.Dated).ThenByDescending(order => order.Id))
            .ToListAsync(cancellation);
        return Ok(orders);
    }

    [HttpGet("revenue")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Revenue(int? year, int? month, int? day, CancellationToken cancellation)
    {
        var query = db.Orders.AsNoTracking().Where(order => order.StatusId == PaidStatusId);
        if (RevenuePeriod(year, month, day) is { } period)
            query = query.Where(order => (order.PaidAtUtc ?? order.Dated) >= period.Start &&
                                         (order.PaidAtUtc ?? order.Dated) < period.End);

        var orders = await Project(query.OrderByDescending(order => order.PaidAtUtc ?? order.Dated)
            .ThenByDescending(order => order.Id)).ToListAsync(cancellation);
        return Ok(orders);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, bool admin = false, CancellationToken cancellation = default)
    {
        var order = await Project(VisibleOrders(admin).Where(item => item.Id == id))
            .SingleOrDefaultAsync(cancellation)
            ?? throw new ApiException(404, "Đơn hàng không tồn tại.");
        return Ok(order);
    }

    [HttpGet("{id:int}/lines")]
    public async Task<IActionResult> Lines(int id, bool admin = false, CancellationToken cancellation = default)
    {
        if (!await VisibleOrders(admin).AnyAsync(order => order.Id == id, cancellation))
            throw new ApiException(404, "Đơn hàng không tồn tại.");

        var lines = await db.OrderLines.AsNoTracking()
            .Where(line => line.OrderId == id)
            .OrderBy(line => line.Id)
            .Select(line => new { line.ProductId, line.Name, line.Quantity, line.Price })
            .ToListAsync(cancellation);
        return Ok(lines);
    }

    [HttpPost]
    [Authorize(Roles = "Member")]
    public async Task<IActionResult> Checkout([FromBody] OrderInput input, CancellationToken cancellation)
    {
        if (input.TableNumber is < 1 or > 12)
            throw new ApiException(400, "Số bàn không hợp lệ.");
        var customerName = CatalogInput.Text(input.CustomerName, "Tên khách", 100);
        var note = CatalogInput.Text(input.Note, "Ghi chú", 500, required: false);

        var memberId = MemberId;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(
            item => item.Id == memberId && item.Active && item.Role == Member.CustomerRole, cancellation)
            ?? throw new ApiException(403, "Tài khoản không có quyền thực hiện thao tác này.");

        var items = await (from item in db.Cart
                           join product in db.Products on item.ProductId equals product.Id
                           where item.MemberId == memberId
                           orderby product.Id
                           select new { Item = item, Product = product }).ToListAsync(cancellation);
        if (items.Count == 0)
            throw new ApiException(409, "Giỏ món đang trống.");
        foreach (var row in items)
        {
            if (row.Product.Stock < row.Item.Quantity)
                throw new ApiException(409, $"Không đủ phần {row.Product.Name}. Vui lòng sửa giỏ món.");
            row.Product.Stock -= row.Item.Quantity;
        }

        var memberName = $"{member.Surname} {member.GivenName}".Trim();
        var order = new OrderTicket
        {
            StatusId = 1,
            MemberId = memberId,
            MemberName = memberName,
            TableNumber = input.TableNumber,
            CustomerName = customerName,
            Note = note,
            Dated = DateTime.UtcNow,
            Total = items.Sum(row => (long)row.Item.Quantity * row.Product.Price),
            SearchText = TextSearch.Normalize($"{memberName} {customerName} Bàn {input.TableNumber}")
        };
        db.Orders.Add(order);
        await db.SaveChangesAsync(cancellation);

        db.OrderLines.AddRange(items.Select(row => new OrderLine
        {
            OrderId = order.Id,
            ProductId = row.Product.Id,
            Name = row.Product.Name,
            Quantity = row.Item.Quantity,
            Price = row.Product.Price
        }));
        db.Cart.RemoveRange(items.Select(row => row.Item));
        await db.SaveChangesAsync(cancellation);
        await transaction.CommitAsync(cancellation);
        return Ok(order.Id);
    }

    [HttpPut("{id:int}/status")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateStatus(int id, [FromBody] OrderStatus input, CancellationToken cancellation)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var order = await db.Orders.FindAsync([id], cancellation)
            ?? throw new ApiException(404, "Đơn hàng không tồn tại.");

        var allowed = order.StatusId switch
        {
            1 => input.StatusId is 2 or 5,
            2 => input.StatusId is 3 or 5,
            3 => input.StatusId == 4,
            4 => input.StatusId == PaidStatusId,
            _ => false
        };
        if (!allowed)
            throw new ApiException(409, "Không thể chuyển sang trạng thái này.");

        if (input.StatusId == 5)
        {
            var items = await (from line in db.OrderLines
                               join product in db.Products on line.ProductId equals product.Id
                               where line.OrderId == id
                               orderby product.Id
                               select new { Product = product, line.Quantity }).ToListAsync(cancellation);
            foreach (var item in items)
                item.Product.Stock += item.Quantity;
        }

        order.StatusId = input.StatusId;
        if (input.StatusId == PaidStatusId)
            order.PaidAtUtc = DateTime.UtcNow;
        await db.SaveChangesAsync(cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }

    private IQueryable<OrderTicket> VisibleOrders(bool admin)
    {
        if (!User.IsInRole(admin ? "Admin" : "Member"))
            throw new ApiException(403, "Tài khoản không có quyền xem danh sách này.");

        var query = db.Orders.AsNoTracking();
        return admin ? query : query.Where(order => order.MemberId == MemberId);
    }

    private static (DateTime Start, DateTime End)? RevenuePeriod(int? year, int? month, int? day)
    {
        if (year is null && month is null && day is null)
            return null;
        if (year is not (>= 2 and <= 9998) || month is < 1 or > 12 || (day.HasValue && !month.HasValue))
            throw new ApiException(400, "Kỳ doanh thu không hợp lệ. Hãy chọn năm trước tháng và ngày.");

        var start = new DateTime(year.Value, month ?? 1, 1);
        if (day is int selectedDay)
        {
            if (selectedDay < 1 || selectedDay > DateTime.DaysInMonth(start.Year, start.Month))
                throw new ApiException(400, "Ngày doanh thu không hợp lệ.");
            start = start.AddDays(selectedDay - 1);
        }

        var end = day.HasValue ? start.AddDays(1) : month.HasValue ? start.AddMonths(1) : start.AddYears(1);
        return (new DateTimeOffset(start, CafeUtcOffset).UtcDateTime,
            new DateTimeOffset(end, CafeUtcOffset).UtcDateTime);
    }

    private static IQueryable<OrderView> Project(IQueryable<OrderTicket> query) =>
        query.Select(order => new OrderView(order.Id, order.StatusId, order.MemberId, order.MemberName,
            order.TableNumber, order.CustomerName, order.Note, order.Dated, order.Total, order.PaidAtUtc));

    private sealed record OrderView(int Id, int StatusId, string MemberId, string MemberName, int TableNumber,
        string CustomerName, string Note, DateTime Dated, long Total, DateTime? PaidAtUtc);

    public sealed record OrderInput(int TableNumber, string? CustomerName, string? Note);

    public sealed record OrderStatus(int StatusId);
}
