using System.Data;
using System.Security.Claims;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controllers;

[ApiController]
[Authorize(Roles = "Member")]
[Route("api/cart")]
public sealed class CartController(CafeDbContext db) : ControllerBase
{
    private string MemberId => User.FindFirstValue(ClaimTypes.NameIdentifier)!;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellation)
    {
        var rows = from item in db.Cart.AsNoTracking()
                   join product in db.Products.AsNoTracking() on item.ProductId equals product.Id
                   where item.MemberId == MemberId
                   orderby item.Id
                   select new { item.Id, item.ProductId, item.Quantity, product.Name, product.ImageUrl,
                       product.Price, product.Stock, product.ImageId };
        return Ok(await rows.ToListAsync(cancellation));
    }

    [HttpGet("count")]
    public async Task<IActionResult> Count(CancellationToken cancellation) =>
        Ok(await db.Cart.Where(item => item.MemberId == MemberId)
            .SumAsync(item => item.Quantity, cancellation));

    [HttpPost("{productId:int}")]
    public Task<IActionResult> Add(int productId, CancellationToken cancellation) =>
        ChangeAsync(productId, null, cancellation);

    [HttpPut("{productId:int}")]
    public Task<IActionResult> Update(int productId, [FromBody] CartQuantity input, CancellationToken cancellation) =>
        ChangeAsync(productId, input.Quantity ?? throw new ApiException(400, "Vui lòng nhập số lượng."), cancellation);

    [HttpDelete("{productId:int}")]
    public Task<IActionResult> Delete(int productId, CancellationToken cancellation) =>
        ChangeAsync(productId, 0, cancellation);

    private async Task<IActionResult> ChangeAsync(int productId, int? requestedQuantity, CancellationToken cancellation)
    {
        if (requestedQuantity is < 0)
            throw new ApiException(400, "Số lượng không hợp lệ.");

        var memberId = MemberId;
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var item = await db.Cart.SingleOrDefaultAsync(row =>
            row.MemberId == memberId && row.ProductId == productId, cancellation);
        var quantity = requestedQuantity ?? ((item?.Quantity ?? 0) + 1);

        if (quantity == 0)
        {
            if (item is not null)
                db.Cart.Remove(item);
        }
        else
        {
            var product = await db.Products.FindAsync([productId], cancellation)
                ?? throw new ApiException(404, "Món không tồn tại.");
            if (quantity > product.Stock)
                throw new ApiException(409, "Số lượng vượt quá tồn kho của món.");

            if (item is null)
                db.Cart.Add(new CartItem { MemberId = memberId, ProductId = productId, Quantity = quantity });
            else
                item.Quantity = quantity;
        }

        await db.SaveChangesAsync(cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }

    public sealed record CartQuantity(int? Quantity);
}
