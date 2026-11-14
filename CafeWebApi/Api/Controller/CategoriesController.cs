using System.Data;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controllers;

[ApiController]
[Route("api/categories")]
public sealed class CategoriesController(CafeDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken cancellation) =>
        Ok(await db.Categories.AsNoTracking()
            .OrderBy(category => category.Id)
            .Select(category => new { category.Id, category.Name, category.Description, category.Icon, category.ImageId })
            .ToListAsync(cancellation));

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
        var (input, image) = await CatalogInput.CategoryAsync(Request, cancellation);
        var name = CatalogInput.Text(input.Name, "Tên danh mục", 100);
        var description = CatalogInput.Text(input.Description, "Mô tả", 1000);
        var nameKey = TextSearch.Normalize(name);
        if (nameKey.Length == 0)
            throw new ApiException(400, "Tên danh mục không hợp lệ.");

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var category = id is int categoryId
            ? await db.Categories.FindAsync([categoryId], cancellation)
                ?? throw new ApiException(404, "Danh mục không tồn tại.")
            : new Category();

        if (await db.Categories.AnyAsync(item => item.NameKey == nameKey && item.Id != category.Id, cancellation))
            throw new ApiException(409, "Tên danh mục đã tồn tại.");

        var oldImageId = category.ImageId;
        if (image is not null)
        {
            db.Images.Add(image);
            await db.SaveChangesAsync(cancellation);
            category.ImageId = image.Id;
        }
        else if (input.RemoveImage)
        {
            category.ImageId = null;
        }

        category.Name = name;
        category.NameKey = nameKey;
        category.Description = description;
        if (input.RemoveImage)
            category.Icon = "";
        if (id is null)
            db.Categories.Add(category);

        await db.SaveChangesAsync(cancellation);
        if (oldImageId != category.ImageId)
            await CatalogInput.DeleteImageAsync(db, oldImageId, cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id, CancellationToken cancellation)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancellation);
        var category = await db.Categories.FindAsync([id], cancellation)
            ?? throw new ApiException(404, "Danh mục không tồn tại.");
        if (await db.Products.AnyAsync(product => product.CategoryId == id, cancellation))
            throw new ApiException(409, "Hãy chuyển hoặc xóa món trong danh mục trước.");

        db.Categories.Remove(category);
        await db.SaveChangesAsync(cancellation);
        await CatalogInput.DeleteImageAsync(db, category.ImageId, cancellation);
        await transaction.CommitAsync(cancellation);
        return NoContent();
    }
}
