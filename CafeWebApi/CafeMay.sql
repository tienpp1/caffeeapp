/*
    CÀ PHÊ MÂY  |  KHỞI TẠO VÀ QUẢN LÝ CƠ SỞ DỮ LIỆU SQL SERVER

    Mở bằng SSMS, kết nối .\SQLEXPRESS với Windows Authentication rồi nhấn Execute.
    Nếu CafeMay chưa có, script tạo database, 8 bảng của Web API và thực đơn mẫu.
    Nếu 8 bảng đã có, script giữ nguyên các hàng và chạy các truy vấn xem dữ liệu.

    Nguồn 3 danh mục và 16 món: cafe_order_app/lib/local_seed.dart.
    Cấu trúc SQL Server lấy từ CafeWebApi/Models/CafeDbContext.cs.
    Tài khoản mẫu do CafeWebApi tạo khi khởi động Development lần đầu.
    Giao dịch, tài khoản và ảnh tải lên trên thiết bị nằm trong tệp SQLite riêng.
*/

USE [master];
GO

IF DB_ID(N'CafeMay') IS NULL
    EXEC(N'CREATE DATABASE [CafeMay]');
GO

USE [CafeMay];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @AppTableCount int = (
    SELECT COUNT(*)
    FROM sys.tables
    WHERE schema_id = SCHEMA_ID(N'dbo')
      AND name IN (N'Members', N'Sessions', N'Images', N'Categories',
                   N'Products', N'CartItems', N'Orders', N'OrderLines')
);

IF @AppTableCount <> 0 AND @AppTableCount <> 8
    THROW 50001, N'CafeMay đang thiếu bảng nghiệp vụ. Kiểm tra các bảng hiện có và khôi phục lược đồ trước khi chạy lại.', 1;

IF @AppTableCount = 0
BEGIN
    BEGIN TRANSACTION;

        CREATE TABLE [dbo].[Images] (
            [Id] int NOT NULL IDENTITY,
            [ContentType] varchar(40) NOT NULL,
            [Data] varbinary(max) NOT NULL,
            CONSTRAINT [PK_Images] PRIMARY KEY ([Id])
        );

        CREATE TABLE [dbo].[Members] (
            [Id] nvarchar(40) NOT NULL,
            [Email] nvarchar(254) NOT NULL,
            [GivenName] nvarchar(80) NOT NULL,
            [Surname] nvarchar(80) NULL,
            [Role] int NOT NULL,
            [Active] bit NOT NULL,
            [PasswordHash] nvarchar(512) NOT NULL,
            [SearchText] nvarchar(640) NOT NULL,
            CONSTRAINT [PK_Members] PRIMARY KEY ([Id]),
            CONSTRAINT [CK_Members_Role] CHECK ([Role] IN (1, 2))
        );

        CREATE TABLE [dbo].[Categories] (
            [Id] int NOT NULL IDENTITY,
            [Name] nvarchar(100) NOT NULL,
            [NameKey] nvarchar(200) NOT NULL,
            [Description] nvarchar(1000) NOT NULL,
            [Icon] nvarchar(240) NOT NULL,
            [ImageId] int NULL,
            CONSTRAINT [PK_Categories] PRIMARY KEY ([Id]),
            CONSTRAINT [FK_Categories_Images_ImageId] FOREIGN KEY ([ImageId]) REFERENCES [dbo].[Images] ([Id]) ON DELETE NO ACTION
        );

        CREATE TABLE [dbo].[Orders] (
            [Id] int NOT NULL IDENTITY,
            [StatusId] int NOT NULL,
            [MemberId] nvarchar(40) NOT NULL,
            [MemberName] nvarchar(161) NOT NULL,
            [TableNumber] int NOT NULL,
            [CustomerName] nvarchar(100) NOT NULL,
            [Note] nvarchar(500) NOT NULL,
            [Dated] datetime2 NOT NULL,
            [Total] bigint NOT NULL,
            [SearchText] nvarchar(600) NOT NULL,
            CONSTRAINT [PK_Orders] PRIMARY KEY ([Id]),
            CONSTRAINT [CK_Orders_Status] CHECK ([StatusId] BETWEEN 1 AND 6),
            CONSTRAINT [CK_Orders_TableNumber] CHECK ([TableNumber] BETWEEN 1 AND 12),
            CONSTRAINT [CK_Orders_Total] CHECK ([Total] > 0),
            CONSTRAINT [FK_Orders_Members_MemberId] FOREIGN KEY ([MemberId]) REFERENCES [dbo].[Members] ([Id]) ON DELETE NO ACTION
        );

        CREATE TABLE [dbo].[Sessions] (
            [TokenHash] varchar(64) NOT NULL,
            [MemberId] nvarchar(40) NOT NULL,
            [ExpiresAtUtc] datetime2 NOT NULL,
            CONSTRAINT [PK_Sessions] PRIMARY KEY ([TokenHash]),
            CONSTRAINT [FK_Sessions_Members_MemberId] FOREIGN KEY ([MemberId]) REFERENCES [dbo].[Members] ([Id]) ON DELETE CASCADE
        );

        CREATE TABLE [dbo].[Products] (
            [Id] int NOT NULL IDENTITY,
            [CategoryId] int NOT NULL,
            [Name] nvarchar(120) NOT NULL,
            [Description] nvarchar(3000) NOT NULL,
            [Price] int NOT NULL,
            [Stock] int NOT NULL,
            [ImageUrl] nvarchar(240) NOT NULL,
            [ImageId] int NULL,
            [SearchText] nvarchar(max) NOT NULL,
            CONSTRAINT [PK_Products] PRIMARY KEY ([Id]),
            CONSTRAINT [CK_Products_Price] CHECK ([Price] > 0),
            CONSTRAINT [CK_Products_Stock] CHECK ([Stock] >= 0),
            CONSTRAINT [FK_Products_Categories_CategoryId] FOREIGN KEY ([CategoryId]) REFERENCES [dbo].[Categories] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_Products_Images_ImageId] FOREIGN KEY ([ImageId]) REFERENCES [dbo].[Images] ([Id]) ON DELETE NO ACTION
        );

        CREATE TABLE [dbo].[CartItems] (
            [Id] int NOT NULL IDENTITY,
            [MemberId] nvarchar(40) NOT NULL,
            [ProductId] int NOT NULL,
            [Quantity] int NOT NULL,
            CONSTRAINT [PK_CartItems] PRIMARY KEY ([Id]),
            CONSTRAINT [CK_CartItems_Quantity] CHECK ([Quantity] > 0),
            CONSTRAINT [FK_CartItems_Members_MemberId] FOREIGN KEY ([MemberId]) REFERENCES [dbo].[Members] ([Id]) ON DELETE NO ACTION,
            CONSTRAINT [FK_CartItems_Products_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [dbo].[Products] ([Id]) ON DELETE CASCADE
        );

        CREATE TABLE [dbo].[OrderLines] (
            [Id] int NOT NULL IDENTITY,
            [OrderId] int NOT NULL,
            [ProductId] int NOT NULL,
            [Name] nvarchar(120) NOT NULL,
            [Quantity] int NOT NULL,
            [Price] int NOT NULL,
            CONSTRAINT [PK_OrderLines] PRIMARY KEY ([Id]),
            CONSTRAINT [CK_OrderLines_Price] CHECK ([Price] > 0),
            CONSTRAINT [CK_OrderLines_Quantity] CHECK ([Quantity] > 0),
            CONSTRAINT [FK_OrderLines_Orders_OrderId] FOREIGN KEY ([OrderId]) REFERENCES [dbo].[Orders] ([Id]) ON DELETE CASCADE,
            CONSTRAINT [FK_OrderLines_Products_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [dbo].[Products] ([Id]) ON DELETE NO ACTION
        );

        CREATE UNIQUE INDEX [IX_CartItems_MemberId_ProductId] ON [dbo].[CartItems] ([MemberId], [ProductId]);

        CREATE INDEX [IX_CartItems_ProductId] ON [dbo].[CartItems] ([ProductId]);

        CREATE INDEX [IX_Categories_ImageId] ON [dbo].[Categories] ([ImageId]);

        CREATE UNIQUE INDEX [IX_Categories_NameKey] ON [dbo].[Categories] ([NameKey]);

        CREATE UNIQUE INDEX [IX_Members_Email] ON [dbo].[Members] ([Email]);

        CREATE INDEX [IX_Members_Role_Active] ON [dbo].[Members] ([Role], [Active]);

        CREATE UNIQUE INDEX [IX_OrderLines_OrderId_ProductId] ON [dbo].[OrderLines] ([OrderId], [ProductId]);

        CREATE INDEX [IX_OrderLines_ProductId] ON [dbo].[OrderLines] ([ProductId]);

        CREATE INDEX [IX_Orders_Dated] ON [dbo].[Orders] ([Dated]);

        CREATE INDEX [IX_Orders_MemberId_Dated] ON [dbo].[Orders] ([MemberId], [Dated]);

        CREATE INDEX [IX_Products_CategoryId] ON [dbo].[Products] ([CategoryId]);

        CREATE INDEX [IX_Products_ImageId] ON [dbo].[Products] ([ImageId]);

        CREATE INDEX [IX_Sessions_ExpiresAtUtc] ON [dbo].[Sessions] ([ExpiresAtUtc]);

        CREATE INDEX [IX_Sessions_MemberId] ON [dbo].[Sessions] ([MemberId]);

        -- Nạp danh mục từ SQLite. Dùng NameKey để nối món với danh mục.
        INSERT dbo.Categories (Name, NameKey, Description, Icon)
        VALUES
        (N'Cà phê', N'ca phe', N'Cà phê phin và espresso pha tại quầy.', N'assets/categories/coffee.jpg'),
        (N'Trà và trái cây', N'tra va trai cay', N'Trà, matcha và đồ uống kết hợp trái cây.', N'assets/categories/tea.jpg'),
        (N'Bánh và đồ ăn nhẹ', N'banh va do an nhe', N'Bánh nướng và món ăn nhẹ dùng tại bàn.', N'assets/categories/food.jpg');

        INSERT dbo.Products (CategoryId, Name, Description, Price, Stock, ImageUrl, SearchText)
        SELECT c.Id, s.Name, s.Description, s.Price, s.Stock, s.ImageUrl, s.SearchText
        FROM (VALUES
        (N'ca phe', N'Espresso', N'Cà phê chiết xuất đậm, dùng nóng trong tách nhỏ.', 30000, 18, N'assets/products/espresso.jpg', N'espresso ca phe chiet xuat dam, dung nong trong tach nho.'),
        (N'ca phe', N'Americano', N'Espresso pha nước, có thể dùng nóng hoặc với đá.', 35000, 20, N'assets/products/americano.jpg', N'americano espresso pha nuoc, co the dung nong hoac voi da.'),
        (N'ca phe', N'Cappuccino', N'Espresso với sữa nóng và lớp bọt sữa mịn.', 45000, 16, N'assets/products/cappuccino.jpg', N'cappuccino espresso voi sua nong va lop bot sua min.'),
        (N'ca phe', N'Latte', N'Espresso pha nhiều sữa cho vị dịu, có thể chọn nóng hoặc đá.', 49000, 22, N'assets/products/latte.jpg', N'latte espresso pha nhieu sua cho vi diu, co the chon nong hoac da.'),
        (N'ca phe', N'Cà phê sữa đá', N'Cà phê phin đậm với sữa đặc và đá.', 39000, 24, N'assets/products/ca-phe-sua-da.jpg', N'ca phe sua da ca phe phin dam voi sua dac va da.'),
        (N'ca phe', N'Cà phê đen đá', N'Cà phê phin dùng với đá, có thể yêu cầu thêm đường.', 32000, 20, N'assets/products/ca-phe-den-da.jpg', N'ca phe den da ca phe phin dung voi da, co the yeu cau them duong.'),
        (N'ca phe', N'Bạc xỉu', N'Sữa đặc, sữa tươi và một lớp cà phê phin nhẹ.', 42000, 18, N'assets/products/bac-xiu.jpg', N'bac xiu sua dac, sua tuoi va mot lop ca phe phin nhe.'),
        (N'ca phe', N'Cà phê muối', N'Cà phê phin với kem muối béo nhẹ.', 45000, 17, N'assets/products/ca-phe-muoi.jpg', N'ca phe muoi ca phe phin voi kem muoi beo nhe.'),
        (N'tra va trai cay', N'Trà đào cam sả', N'Trà đen với đào, cam tươi và sả thơm.', 49000, 21, N'assets/products/tra-dao-cam-sa.jpg', N'tra dao cam sa tra den voi dao, cam tuoi va sa thom.'),
        (N'tra va trai cay', N'Trà vải', N'Trà lài, vải và đá, vị ngọt thanh.', 45000, 18, N'assets/products/tra-vai.jpg', N'tra vai tra lai, vai va da, vi ngot thanh.'),
        (N'tra va trai cay', N'Trà tắc', N'Trà đen pha tắc tươi, dùng lạnh.', 35000, 22, N'assets/products/tra-tac.jpg', N'tra tac tra den pha tac tuoi, dung lanh.'),
        (N'tra va trai cay', N'Matcha latte', N'Bột trà xanh đánh mịn với sữa tươi.', 55000, 18, N'assets/products/matcha-latte.jpg', N'matcha latte bot tra xanh danh min voi sua tuoi.'),
        (N'banh va do an nhe', N'Croissant bơ', N'Bánh sừng bò nhiều lớp, nướng giòn và thơm bơ.', 36000, 10, N'assets/products/croissant.jpg', N'croissant bo banh sung bo nhieu lop, nuong gion va thom bo.'),
        (N'banh va do an nhe', N'Bánh mì gà', N'Bánh mì giòn kẹp gà xé, dưa leo và rau.', 52000, 10, N'assets/products/banh-mi-ga.jpg', N'banh mi ga banh mi gion kep ga xe, dua leo va rau.'),
        (N'banh va do an nhe', N'Bánh chuối', N'Bánh chuối nướng mềm, dùng theo lát.', 39000, 8, N'assets/products/banh-chuoi.jpg', N'banh chuoi banh chuoi nuong mem, dung theo lat.'),
        (N'banh va do an nhe', N'Bánh phô mai', N'Bánh phô mai nướng, giữ lạnh và phục vụ theo lát.', 56000, 8, N'assets/products/banh-pho-mai.jpg', N'banh pho mai banh pho mai nuong, giu lanh va phuc vu theo lat.')
        ) AS s (CategoryKey, Name, Description, Price, Stock, ImageUrl, SearchText)
        INNER JOIN dbo.Categories AS c ON c.NameKey = s.CategoryKey;

    COMMIT TRANSACTION;
END;
GO

-- XEM BẢNG, CỘT VÀ KHÓA NGOẠI
SELECT SCHEMA_NAME(t.schema_id) AS [Schema], t.name AS [TableName],
       COALESCE(SUM(p.rows), 0) AS [Rows]
FROM sys.tables AS t
LEFT JOIN sys.partitions AS p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.schema_id, t.name
ORDER BY [Schema], [TableName];

SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE,
       CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;

SELECT name AS ForeignKeyName,
       OBJECT_SCHEMA_NAME(parent_object_id) AS TableSchema,
       OBJECT_NAME(parent_object_id) AS TableName,
       OBJECT_NAME(referenced_object_id) AS ReferencedTable,
       delete_referential_action_desc AS OnDelete
FROM sys.foreign_keys
ORDER BY TableName, ForeignKeyName;

-- XEM DỮ LIỆU. Chọn một câu SELECT rồi nhấn Execute để chạy riêng.
SELECT Id, Name, Description, Icon, ImageId
FROM dbo.Categories ORDER BY Id;

SELECT p.Id, c.Name AS CategoryName, p.Name, p.Price, p.Stock,
       p.Description, p.ImageUrl, p.ImageId
FROM dbo.Products AS p
JOIN dbo.Categories AS c ON c.Id = p.CategoryId
ORDER BY p.Id;

SELECT Id, Email, GivenName, Surname, Role, Active
FROM dbo.Members ORDER BY Role, Email;

SELECT Id, MemberId, ProductId, Quantity
FROM dbo.CartItems ORDER BY Id;

SELECT Id, MemberId, MemberName, TableNumber, CustomerName, Note, Total,
       Dated AS DatedUtc,
       CASE StatusId
           WHEN 1 THEN N'Chờ xác nhận'
           WHEN 2 THEN N'Đang pha chế'
           WHEN 3 THEN N'Chờ phục vụ'
           WHEN 4 THEN N'Đã phục vụ'
           WHEN 5 THEN N'Đã hủy'
           WHEN 6 THEN N'Đã thanh toán'
       END AS [Status]
FROM dbo.Orders ORDER BY Dated DESC, Id DESC;

SELECT OrderId, ProductId, Name, Quantity, Price
FROM dbo.OrderLines ORDER BY OrderId, Id;

SELECT Id, ContentType, DATALENGTH([Data]) AS SizeBytes
FROM dbo.Images ORDER BY Id;

SELECT MemberId, ExpiresAtUtc
FROM dbo.Sessions ORDER BY ExpiresAtUtc DESC;

/*
    VÍ DỤ QUẢN LÝ BẢNG

    Chọn riêng các câu lệnh bên trong khối chú thích để chạy.
    Sửa lược đồ của các bảng nghiệp vụ cần cập nhật cả model và DbContext C#.

    CREATE TABLE dbo.GhiChuQuan (
        Id int IDENTITY PRIMARY KEY,
        NoiDung nvarchar(500) NOT NULL,
        TaoLucUtc datetime2 NOT NULL DEFAULT SYSUTCDATETIME()
    );

    INSERT dbo.GhiChuQuan (NoiDung) VALUES (N'Kiểm tra tồn kho cuối ngày');
    SELECT Id, NoiDung, TaoLucUtc FROM dbo.GhiChuQuan ORDER BY Id;

    ALTER TABLE dbo.GhiChuQuan ADD DaXuLy bit NOT NULL DEFAULT 0;
    UPDATE dbo.GhiChuQuan SET DaXuLy = 1 WHERE Id = 1;
    DELETE FROM dbo.GhiChuQuan WHERE Id = 1;

    -- DROP TABLE xóa cả lược đồ và dữ liệu của bảng do bạn tạo.
    DROP TABLE IF EXISTS dbo.GhiChuQuan;
*/
