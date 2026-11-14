using CafeWebApi.Models;
using CafeWebApi.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var connection = builder.Configuration.GetConnectionString("CafeMay")
    ?? throw new InvalidOperationException("Thiếu ConnectionStrings:CafeMay trong cấu hình Web API.");

builder.Services.AddDbContext<CafeDbContext>(options => options.UseSqlServer(connection));
builder.Services.Configure<FormOptions>(options => options.MultipartBodyLengthLimit = 6 * 1024 * 1024);
builder.Services.AddControllers().ConfigureApiBehaviorOptions(options =>
{
    options.InvalidModelStateResponseFactory = _ =>
        new BadRequestObjectResult(new { message = "Dữ liệu gửi lên không đúng định dạng." });
});
builder.Services.AddScoped<MemberAccess>();
builder.Services.AddScoped<IPasswordHasher<Member>, PasswordHasher<Member>>();
builder.Services.Configure<PasswordHasherOptions>(options => options.IterationCount = 210_000);
builder.Services.AddAuthentication(SessionAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, SessionAuthenticationHandler>(SessionAuthenticationHandler.SchemeName, null);
builder.Services.AddAuthorization();

builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
{
    if (builder.Environment.IsDevelopment())
    {
        policy.SetIsOriginAllowed(origin => Uri.TryCreate(origin, UriKind.Absolute, out var uri)
            && uri.IsLoopback && uri.Scheme is "http" or "https");
    }
    else
    {
        var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? [];
        policy.WithOrigins(origins);
    }

    policy.AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();
app.Use(async (context, next) =>
{
    try
    {
        await next(context);
    }
    catch (Exception error) when (!context.Response.HasStarted)
    {
        var sqlError = error as SqlException ?? error.InnerException as SqlException;
        var status = error switch
        {
            ApiException api => api.StatusCode,
            BadHttpRequestException bad => bad.StatusCode,
            _ when sqlError?.Number is 1205 or 2601 or 2627 or 547 => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status500InternalServerError
        };
        if (status >= 500)
            app.Logger.LogError(error, "Lỗi khi xử lý {Method} {Path}", context.Request.Method, context.Request.Path);
        if (context.RequestAborted.IsCancellationRequested) return;

        var message = error is ApiException known ? known.Message : status switch
        {
            StatusCodes.Status409Conflict => "Dữ liệu vừa thay đổi hoặc đã được sử dụng. Vui lòng kiểm tra và thử lại.",
            StatusCodes.Status413PayloadTooLarge => "Tệp tải lên quá lớn.",
            StatusCodes.Status400BadRequest => "Dữ liệu gửi lên không hợp lệ.",
            _ => "Máy chủ gặp lỗi. Vui lòng thử lại."
        };
        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new { message }, context.RequestAborted);
    }
});

app.UseRouting();
app.UseCors();
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Ok(new { name = "Cà Phê Mây Web API", health = "/api/health" }));
app.MapGet("/api/health", async (CafeDbContext db, CancellationToken cancel) =>
    await db.Database.CanConnectAsync(cancel)
        ? Results.Ok(new { status = "ok" })
        : Results.Json(new { status = "unavailable" }, statusCode: StatusCodes.Status503ServiceUnavailable));
app.MapControllers();

if (app.Environment.IsDevelopment())
{
    await using var scope = app.Services.CreateAsyncScope();
    await CafeSeed.InitializeAsync(scope.ServiceProvider);
}

await app.RunAsync();
