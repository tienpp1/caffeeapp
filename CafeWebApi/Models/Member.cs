namespace CafeWebApi.Models;

public sealed class Member
{
    public const int AdminRole = 1;
    public const int CustomerRole = 2;

    public required string Id { get; init; }
    public required string Email { get; init; }
    public required string GivenName { get; set; }
    public string? Surname { get; set; }
    public int Role { get; set; } = CustomerRole;
    public bool Active { get; set; } = true;
    public string PasswordHash { get; set; } = "";
    public required string SearchText { get; set; }
}

public sealed class MemberSession
{
    public required string TokenHash { get; init; }
    public required string MemberId { get; init; }
    public required DateTime ExpiresAtUtc { get; init; }
    public Member Member { get; init; } = null!;
}
