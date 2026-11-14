using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Models;

public sealed class CafeDbContext(DbContextOptions<CafeDbContext> options) : DbContext(options)
{
    public DbSet<Member> Members => Set<Member>();
    public DbSet<MemberSession> Sessions => Set<MemberSession>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<MenuImage> Images => Set<MenuImage>();
    public DbSet<Product> Products => Set<Product>();
    public DbSet<CartItem> Cart => Set<CartItem>();
    public DbSet<OrderTicket> Orders => Set<OrderTicket>();
    public DbSet<OrderLine> OrderLines => Set<OrderLine>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<Member>(entity =>
        {
            entity.ToTable("Members", t => t.HasCheckConstraint("CK_Members_Role", "[Role] IN (1, 2)"));
            entity.Property(x => x.Id).HasMaxLength(40);
            entity.Property(x => x.Email).HasMaxLength(254);
            entity.Property(x => x.GivenName).HasMaxLength(80);
            entity.Property(x => x.Surname).HasMaxLength(80);
            entity.Property(x => x.PasswordHash).HasMaxLength(512);
            entity.Property(x => x.SearchText).HasMaxLength(640);
            entity.HasIndex(x => x.Email).IsUnique();
            entity.HasIndex(x => new { x.Role, x.Active });
        });

        model.Entity<MemberSession>(entity =>
        {
            entity.HasKey(x => x.TokenHash);
            entity.Property(x => x.TokenHash).HasMaxLength(64).IsUnicode(false);
            entity.HasOne(x => x.Member).WithMany().HasForeignKey(x => x.MemberId);
            entity.HasIndex(x => x.ExpiresAtUtc);
        });

        model.Entity<MenuImage>()
            .Property(x => x.ContentType).HasMaxLength(40).IsUnicode(false);

        model.Entity<Category>(entity =>
        {
            entity.Property(x => x.Name).HasMaxLength(100);
            entity.Property(x => x.NameKey).HasMaxLength(200);
            entity.Property(x => x.Description).HasMaxLength(1000);
            entity.Property(x => x.Icon).HasMaxLength(240);
            entity.HasIndex(x => x.NameKey).IsUnique();
            entity.HasOne<MenuImage>().WithMany().HasForeignKey(x => x.ImageId).OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<Product>(entity =>
        {
            entity.ToTable("Products", t =>
            {
                t.HasCheckConstraint("CK_Products_Price", "[Price] > 0");
                t.HasCheckConstraint("CK_Products_Stock", "[Stock] >= 0");
            });
            entity.Property(x => x.Name).HasMaxLength(120);
            entity.Property(x => x.Description).HasMaxLength(3000);
            entity.Property(x => x.ImageUrl).HasMaxLength(240);
            entity.HasOne<Category>().WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<MenuImage>().WithMany().HasForeignKey(x => x.ImageId).OnDelete(DeleteBehavior.Restrict);
        });

        model.Entity<CartItem>(entity =>
        {
            entity.ToTable("CartItems", t => t.HasCheckConstraint("CK_CartItems_Quantity", "[Quantity] > 0"));
            entity.HasOne<Member>().WithMany().HasForeignKey(x => x.MemberId).OnDelete(DeleteBehavior.Restrict);
            entity.HasOne<Product>().WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(x => new { x.MemberId, x.ProductId }).IsUnique();
        });

        model.Entity<OrderTicket>(entity =>
        {
            entity.ToTable("Orders", t =>
            {
                t.HasCheckConstraint("CK_Orders_Status", "[StatusId] BETWEEN 1 AND 6");
                t.HasCheckConstraint("CK_Orders_TableNumber", "[TableNumber] BETWEEN 1 AND 12");
                t.HasCheckConstraint("CK_Orders_Total", "[Total] > 0");
            });
            entity.Property(x => x.Dated).HasConversion(value => value, value => DateTime.SpecifyKind(value, DateTimeKind.Utc));
            entity.Property(x => x.MemberName).HasMaxLength(161);
            entity.Property(x => x.CustomerName).HasMaxLength(100);
            entity.Property(x => x.Note).HasMaxLength(500);
            entity.Property(x => x.SearchText).HasMaxLength(600);
            entity.HasOne<Member>().WithMany().HasForeignKey(x => x.MemberId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.MemberId, x.Dated });
            entity.HasIndex(x => x.Dated);
        });

        model.Entity<OrderLine>(entity =>
        {
            entity.ToTable("OrderLines", t =>
            {
                t.HasCheckConstraint("CK_OrderLines_Quantity", "[Quantity] > 0");
                t.HasCheckConstraint("CK_OrderLines_Price", "[Price] > 0");
            });
            entity.Property(x => x.Name).HasMaxLength(120);
            entity.HasOne<OrderTicket>().WithMany().HasForeignKey(x => x.OrderId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne<Product>().WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.OrderId, x.ProductId }).IsUnique();
        });
    }
}
