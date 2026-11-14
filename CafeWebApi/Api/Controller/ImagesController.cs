using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controllers;

[ApiController]
[Route("api/images")]
public sealed class ImagesController(CafeDbContext db) : ControllerBase
{
    [HttpGet("{id:int}")]
    public async Task<IActionResult> Get(int id, CancellationToken cancellation)
    {
        var image = await db.Images.AsNoTracking().SingleOrDefaultAsync(item => item.Id == id, cancellation)
            ?? throw new ApiException(404, "Ảnh không tồn tại.");
        return File(image.Data, image.ContentType);
    }
}
