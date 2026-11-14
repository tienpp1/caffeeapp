using System.Data;
using CafeWebApi.Models;
using Microsoft.EntityFrameworkCore;

namespace CafeWebApi.Services;

public static class CafeSeed
{
    public static async Task InitializeAsync(IServiceProvider services)
    {
        var db = services.GetRequiredService<CafeDbContext>();
        var memberAccess = services.GetRequiredService<MemberAccess>();
        await db.Database.EnsureCreatedAsync();

        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        if (!await db.Members.AnyAsync())
        {
            db.Members.AddRange(
                memberAccess.NewMember("admin@cafemay.vn", "Admin@12345", "Quản trị", null, Member.AdminRole),
                memberAccess.NewMember("member@cafemay.vn", "Member@12345", "Khách mẫu", null));
        }

        if (!await db.Categories.AnyAsync())
        {
            var coffee = Category("Cà phê", "Cà phê phin và espresso pha tại quầy.", "coffee");
            var tea = Category("Trà và trái cây", "Trà, matcha và đồ uống kết hợp trái cây.", "tea");
            var food = Category("Bánh và đồ ăn nhẹ", "Bánh nướng và món ăn nhẹ dùng tại bàn.", "food");
            db.Categories.AddRange(coffee, tea, food);
            await db.SaveChangesAsync();
            db.Products.AddRange(
                Product(coffee.Id, "Espresso", "espresso", 30000, "Cà phê chiết xuất đậm, dùng nóng trong tách nhỏ.", 18),
                Product(coffee.Id, "Americano", "americano", 35000, "Espresso pha nước, có thể dùng nóng hoặc với đá.", 20),
                Product(coffee.Id, "Cappuccino", "cappuccino", 45000, "Espresso với sữa nóng và lớp bọt sữa mịn.", 16),
                Product(coffee.Id, "Latte", "latte", 49000, "Espresso pha nhiều sữa cho vị dịu, có thể chọn nóng hoặc đá.", 22),
                Product(coffee.Id, "Cà phê sữa đá", "ca-phe-sua-da", 39000, "Cà phê phin đậm với sữa đặc và đá.", 24),
                Product(coffee.Id, "Cà phê đen đá", "ca-phe-den-da", 32000, "Cà phê phin dùng với đá, có thể yêu cầu thêm đường.", 20),
                Product(coffee.Id, "Bạc xỉu", "bac-xiu", 42000, "Sữa đặc, sữa tươi và một lớp cà phê phin nhẹ.", 18),
                Product(coffee.Id, "Cà phê muối", "ca-phe-muoi", 45000, "Cà phê phin với kem muối béo nhẹ.", 17),
                Product(tea.Id, "Trà đào cam sả", "tra-dao-cam-sa", 49000, "Trà đen với đào, cam tươi và sả thơm.", 21),
                Product(tea.Id, "Trà vải", "tra-vai", 45000, "Trà lài, vải và đá, vị ngọt thanh.", 18),
                Product(tea.Id, "Trà tắc", "tra-tac", 35000, "Trà đen pha tắc tươi, dùng lạnh.", 22),
                Product(tea.Id, "Matcha latte", "matcha-latte", 55000, "Bột trà xanh đánh mịn với sữa tươi.", 18),
                Product(food.Id, "Croissant bơ", "croissant", 36000, "Bánh sừng bò nhiều lớp, nướng giòn và thơm bơ.", 10),
                Product(food.Id, "Bánh mì gà", "banh-mi-ga", 52000, "Bánh mì giòn kẹp gà xé, dưa leo và rau.", 10),
                Product(food.Id, "Bánh chuối", "banh-chuoi", 39000, "Bánh chuối nướng mềm, dùng theo lát.", 8),
                Product(food.Id, "Bánh phô mai", "banh-pho-mai", 56000, "Bánh phô mai nướng, giữ lạnh và phục vụ theo lát.", 8));
        }

        await db.SaveChangesAsync();
        await transaction.CommitAsync();
    }

    private static Category Category(string name, string description, string asset) => new()
    {
        Name = name,
        NameKey = TextSearch.Normalize(name),
        Description = description,
        Icon = $"assets/categories/{asset}.jpg"
    };

    private static Product Product(int categoryId, string name, string asset, int price, string description, int stock) => new()
    {
        CategoryId = categoryId,
        Name = name,
        Description = description,
        Price = price,
        Stock = stock,
        ImageUrl = $"assets/products/{asset}.jpg",
        SearchText = TextSearch.Normalize($"{name} {description}")
    };
}
