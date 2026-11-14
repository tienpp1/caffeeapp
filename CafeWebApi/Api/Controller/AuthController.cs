using System.Data;
using System.Security.Claims;
using System.Text.RegularExpressions;
using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Api.Controller;

[ApiController]
[Route("api/auth")]
public sealed partial class AuthController(CafeDbContext db, MemberAccess access) : ControllerBase
{
    public sealed record RegisterRequest(string? Email, string? Password, string? GivenName, string? Surname);
    public sealed record LoginRequest(string? Email, string? Password);
    public sealed record PasswordRequest(string? CurrentPassword, string? NewPassword);

    [HttpPost("register")]
    public async Task<ActionResult<MemberDto>> Register(RegisterRequest request, CancellationToken cancel)
    {
        var email = (request.Email ?? "").Trim().ToLowerInvariant();
        if (email.Length > 254 || !EmailPattern().IsMatch(email))
            throw new ApiException(400, "Email không hợp lệ.");

        var password = ValidPassword(request.Password);
        var givenName = Name(request.GivenName, "Tên", required: true)!;
        var surname = Name(request.Surname, "Họ", required: false);
        if (await db.Members.AnyAsync(x => x.Email == email, cancel))
            throw new ApiException(409, "Email này đã được đăng ký.");

        var member = access.NewMember(email, password, givenName, surname);
        db.Members.Add(member);
        await db.SaveChangesAsync(cancel);
        return StatusCode(StatusCodes.Status201Created, MemberDto.From(member));
    }

    [HttpPost("login")]
    public async Task<ActionResult<LoginDto>> Login(LoginRequest request, CancellationToken cancel)
    {
        var email = (request.Email ?? "").Trim().ToLowerInvariant();
        var password = request.Password ?? "";
        if (email.Length > 254 || password.Length is 0 or > 128)
            throw new ApiException(401, "Email hoặc mật khẩu không đúng.");

        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(x => x.Email == email, cancel);
        if (member is null || !access.VerifyPassword(member, password))
            throw new ApiException(401, "Email hoặc mật khẩu không đúng.");
        if (!member.Active)
            throw new ApiException(403, "Tài khoản đã bị khóa.");

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, cancel);
        var valid = await db.Members.AnyAsync(
            x => x.Id == member.Id && x.Active && x.PasswordHash == member.PasswordHash, cancel);
        if (!valid)
            throw new ApiException(401, "Tài khoản đã thay đổi. Vui lòng đăng nhập lại.");

        var token = access.AddSession(member);
        await db.Sessions.Where(x => x.MemberId == member.Id && x.ExpiresAtUtc <= DateTime.UtcNow)
            .ExecuteDeleteAsync(cancel);
        await db.SaveChangesAsync(cancel);
        await transaction.CommitAsync(cancel);
        return new LoginDto(token, MemberDto.From(member));
    }

    [Authorize]
    [HttpGet("me")]
    public async Task<ActionResult<MemberDto>> Me(CancellationToken cancel)
    {
        var id = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.Active, cancel);
        if (member is null) throw new ApiException(401, "Vui lòng đăng nhập lại.");
        return MemberDto.From(member);
    }

    [Authorize]
    [HttpPut("password")]
    public async Task<IActionResult> ChangePassword(PasswordRequest request, CancellationToken cancel)
    {
        var password = ValidPassword(request.NewPassword);
        var currentPassword = request.CurrentPassword ?? "";
        if (password == currentPassword)
            throw new ApiException(400, "Mật khẩu mới phải khác mật khẩu hiện tại.");

        var id = User.FindFirstValue(ClaimTypes.NameIdentifier);
        var member = await db.Members.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id && x.Active, cancel);
        if (member is null) throw new ApiException(401, "Vui lòng đăng nhập lại.");
        if (currentPassword.Length is 0 or > 128 || !access.VerifyPassword(member, currentPassword))
            throw new ApiException(400, "Mật khẩu hiện tại không đúng.");

        var nextHash = access.HashPassword(member, password);
        await using var transaction = await db.Database.BeginTransactionAsync(cancel);
        var count = await db.Members.Where(x => x.Id == member.Id && x.Active && x.PasswordHash == member.PasswordHash)
            .ExecuteUpdateAsync(updates => updates.SetProperty(x => x.PasswordHash, nextHash), cancel);
        if (count != 1) throw new ApiException(409, "Tài khoản đã thay đổi. Vui lòng thử lại.");

        var tokenHash = User.FindFirstValue(SessionAuthenticationHandler.SessionClaim);
        await db.Sessions.Where(x => x.MemberId == member.Id && x.TokenHash != tokenHash).ExecuteDeleteAsync(cancel);
        await transaction.CommitAsync(cancel);
        return NoContent();
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout(CancellationToken cancel)
    {
        var tokenHash = User.FindFirstValue(SessionAuthenticationHandler.SessionClaim);
        await db.Sessions.Where(x => x.TokenHash == tokenHash).ExecuteDeleteAsync(cancel);
        return NoContent();
    }

    internal static string? Name(string? value, string label, bool required)
    {
        var name = (value ?? "").Trim();
        if (name.Length > 80)
            throw new ApiException(400, $"{label} tối đa 80 ký tự.");
        if (required && name.Length == 0)
            throw new ApiException(400, $"Vui lòng nhập {label.ToLowerInvariant()}.");
        return name.Length > 0 ? name : null;
    }

    private static string ValidPassword(string? value)
    {
        if (value is null || value.Length is < 8 or > 128)
            throw new ApiException(400, "Mật khẩu phải có từ 8 đến 128 ký tự.");
        return value;
    }

    [GeneratedRegex(@"^[^\s@]+@[^\s@]+\.[^\s@]+$")]
    private static partial Regex EmailPattern();
}
