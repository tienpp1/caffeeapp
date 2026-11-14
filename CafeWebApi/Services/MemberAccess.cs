using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using CafeWebApi.Models;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace CafeWebApi.Services;

public sealed record MemberDto(string Id, string Email, string GivenName, string? Surname, int Role, bool Active)
{
    public static MemberDto From(Member member) =>
        new(member.Id, member.Email, member.GivenName, member.Surname, member.Role, member.Active);
}

public sealed record LoginDto(string Token, MemberDto Member);

public sealed class MemberAccess(CafeDbContext db, IPasswordHasher<Member> hasher)
{
    public static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(token)));

    public Member NewMember(string email, string password, string givenName, string? surname, int role = Member.CustomerRole)
    {
        var member = new Member
        {
            Id = Guid.NewGuid().ToString("N"),
            Email = email,
            GivenName = givenName,
            Surname = surname,
            Role = role,
            SearchText = TextSearch.Normalize($"{surname} {givenName} {email}")
        };
        member.PasswordHash = hasher.HashPassword(member, password);
        return member;
    }

    public bool VerifyPassword(Member member, string password) =>
        hasher.VerifyHashedPassword(member, member.PasswordHash, password) != PasswordVerificationResult.Failed;

    public string HashPassword(Member member, string password) => hasher.HashPassword(member, password);

    public string AddSession(Member member)
    {
        var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        db.Sessions.Add(new MemberSession
        {
            TokenHash = HashToken(token),
            MemberId = member.Id,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(7)
        });
        return token;
    }
}

public sealed class SessionAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    CafeDbContext db) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "CafeSession";
    public const string SessionClaim = "cafe_session";

    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var header = Request.Headers.Authorization.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.NoResult();

        var token = header["Bearer ".Length..].Trim();
        if (token.Length != 64 || !token.All(Uri.IsHexDigit))
            return AuthenticateResult.Fail("Phiên không hợp lệ.");

        var tokenHash = MemberAccess.HashToken(token);
        var session = await db.Sessions.AsNoTracking().Include(x => x.Member)
            .SingleOrDefaultAsync(x => x.TokenHash == tokenHash && x.ExpiresAtUtc > DateTime.UtcNow, Context.RequestAborted);
        if (session is null || !session.Member.Active)
            return AuthenticateResult.Fail("Phiên đã hết hạn hoặc tài khoản đã bị khóa.");

        var role = session.Member.Role == Member.AdminRole ? "Admin" : "Member";
        var identity = new ClaimsIdentity([
            new Claim(ClaimTypes.NameIdentifier, session.Member.Id),
            new Claim(ClaimTypes.Role, role),
            new Claim(SessionClaim, tokenHash)
        ], SchemeName);

        return AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(identity), SchemeName));
    }

    protected override Task HandleChallengeAsync(AuthenticationProperties properties)
    {
        Response.StatusCode = StatusCodes.Status401Unauthorized;
        Response.Headers.WWWAuthenticate = "Bearer";
        return Response.WriteAsJsonAsync(new { message = "Vui lòng đăng nhập lại." }, Context.RequestAborted);
    }

    protected override Task HandleForbiddenAsync(AuthenticationProperties properties)
    {
        Response.StatusCode = StatusCodes.Status403Forbidden;
        return Response.WriteAsJsonAsync(new { message = "Bạn không có quyền thực hiện thao tác này." }, Context.RequestAborted);
    }
}
