using System.Data;
using System.Security.Claims;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controller;

[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/members")]
public sealed class MembersController(CafeDbContext db) : ControllerBase
{
    public sealed record UpdateRequest(string? GivenName, string? Surname, int Role, bool? Active);

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<MemberDto>>> List(string? search, CancellationToken cancel)
    {
        var keyword = TextSearch.Normalize(search ?? "");
        var query = db.Members.AsNoTracking().AsQueryable();
        if (keyword.Length != 0)
            query = query.Where(x => x.SearchText.Contains(keyword));

        var members = await query.OrderBy(x => x.Role).ThenBy(x => x.Email)
            .Select(x => new MemberDto(x.Id, x.Email, x.GivenName, x.Surname, x.Role, x.Active))
            .ToListAsync(cancel);
        return members;
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, UpdateRequest request, CancellationToken cancel)
    {
        if (request.Role is not (Member.AdminRole or Member.CustomerRole) || request.Active is null)
            throw new ApiException(400, "Vai trò hoặc trạng thái không hợp lệ.");

        var givenName = AuthController.Name(request.GivenName, "Tên", required: true)!;
        var surname = AuthController.Name(request.Surname, "Họ", required: false);
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancel);
        var actorId = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!await db.Members.AnyAsync(x => x.Id == actorId && x.Role == Member.AdminRole && x.Active, cancel))
            throw new ApiException(403, "Bạn không có quyền thực hiện thao tác này.");

        var target = await db.Members.FindAsync([id], cancel);
        if (target is null) throw new ApiException(404, "Tài khoản không tồn tại.");

        var active = request.Active.Value;
        if (target.Active && target.Role == Member.AdminRole && (!active || request.Role != Member.AdminRole))
        {
            var otherAdmin = await db.Members.AnyAsync(x => x.Id != id && x.Active && x.Role == Member.AdminRole, cancel);
            if (!otherAdmin) throw new ApiException(409, "Cần giữ ít nhất một quản trị viên hoạt động.");
        }

        target.GivenName = givenName;
        target.Surname = surname;
        target.Role = request.Role;
        target.Active = active;
        target.SearchText = TextSearch.Normalize($"{surname} {givenName} {target.Email}");
        await db.SaveChangesAsync(cancel);

        if (!active)
            await db.Sessions.Where(x => x.MemberId == id).ExecuteDeleteAsync(cancel);

        await transaction.CommitAsync(cancel);
        return NoContent();
    }
}
