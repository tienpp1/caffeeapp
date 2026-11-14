using System.Data;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controllers;

[ApiController]
[Route("api/products")]
public sealed class ProductsController(CafeDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(int? categoryId, string? search, int? excludeId,
        int page = 1, int pageSize = 6, CancellationToken cancellation = default)
    {
        if (page < 1 || pageSize is < 1 or > 100 || (long)(page - 1) * pageSize > int.MaxValue)
            throw new ApiException(400, "Trang hoặc kích thước trang không hợp lệ.");

        var query = db.Products.AsNoTracking();
        var keyword = TextSearch.Normalize(search ?? "");
        if (categoryId is int category)
            query = query.Where(product => product.CategoryId == category);
        if (excludeId is int excluded)
            query = query.Where(product => product.Id != excluded);
        if (keyword.Length > 0)
            query = query.Where(product => product.SearchText.Contains(keyword));

        var total = await query.CountAsync(cancellation);
        var items = await Project(query.OrderByDescending(product => product.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)).ToListAsync(cancellation);
        return Ok(new { items, total });
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken cancellation)
    {
        var product = await Project(db.Products.AsNoTracking().Where(item => item.Id == id))
            .SingleOrDefaultAsync(cancellation)
            ?? throw new ApiException(404, "Món không tồn tại.");
        return Ok(product);
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    [RequestSizeLimit(CatalogInput.MaxRequestBytes)]
    public Task<IActionResult> Create(CancellationToken cancellation) => SaveAsync(null, cancellation);

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin")]
    [RequestSizeLimit(CatalogInput.MaxRequestBytes)]
    public Task<IActionResult> Update(int id, CancellationToken cancellation) => SaveAsync(id, cancellation);

    private async Task<IActionResult> SaveAsync(int? id, CancellationToken cancellation)
    {
        var (input, image) = await CatalogInput.ProductAsync(Request, cancellation);
        var name = CatalogInput.Text(input.Name, "Tên món", 120);
        var description = CatalogInput.Text(input.Description, "Mô tả", 3000);
        if (input.Price is < 1 or > 1_000_000_000 || input.Stock is < 0 or > 10_000)
            throw new ApiException(400, "Giá bán hoặc số lượng tồn không hợp lệ.");
        if (id is null && image is null)
            throw new ApiException(400, "Vui lòng chọn ảnh cho món mới.");

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        if (!await db.Categories.AnyAsync(category => category.Id == input.CategoryId, cancellation))
            throw new ApiException(404, "Danh mục không tồn tại.");

        var product = id is int productId
            ? await db.Products.FindAsync([productId], cancellation)
                ?? throw new ApiException(404, "Món không tồn tại.")
            : new Product();
        var oldImageId = product.ImageId;
        if (image is not null)
        {
            db.Images.Add(image);
            await db.SaveChangesAsync(cancellation);
            product.ImageId = image.Id;
        }
        product.CategoryId = input.CategoryId;
        product.Name = name;
        product.Description = description;
        product.Price = input.Price;
        product.Stock = input.Stock;
        product.SearchText = TextSearch.Normalize($"{name} {description}");
        if (id is null)
            db.Products.Add(product);

        await db.SaveChangesAsync(cancellation);
        if (oldImageId != product.ImageId)
            await CatalogInput.DeleteImageAsync(db, oldImageId, cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellation)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var product = await db.Products.FindAsync([id], cancellation)
            ?? throw new ApiException(404, "Món không tồn tại.");
        if (await db.OrderLines.AnyAsync(line => line.ProductId == id, cancellation))
            throw new ApiException(409, "Món đã có trong đơn hàng và không thể xóa.");

        db.Products.Remove(product);
        await db.SaveChangesAsync(cancellation);
        await CatalogInput.DeleteImageAsync(db, product.ImageId, cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }

    private static IQueryable<ProductView> Project(IQueryable<Product> query) =>
        query.Select(product => new ProductView(product.Id, product.CategoryId, product.Name,
            product.Description, product.Price, product.Stock, product.ImageUrl, product.ImageId));

    private sealed record ProductView(int Id, int CategoryId, string Name, string Description,
        int Price, int Stock, string ImageUrl, int? ImageId);
}
