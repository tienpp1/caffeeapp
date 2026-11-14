# Cà Phê Mây

Ứng dụng Flutter/Dart để xem thực đơn, gọi món theo bàn, phục vụ và ghi nhận thu tiền. Android lưu dữ liệu trên thiết bị bằng SQLite. Windows và trình duyệt dùng chung dữ liệu qua Web API ASP.NET Core 10 và SQL Server.

## Chạy trên Windows hoặc trình duyệt

Cần .NET SDK 10, SQL Server, Flutter SDK và Chrome hoặc Edge nếu chạy web. Bản desktop cần Visual Studio với workload **Desktop development with C++**.

Mở terminal ở thư mục gốc của repo rồi chạy API.

```powershell
cd CafeWebApi
dotnet watch run
```

API mặc định dùng SQL Server Express `.\SQLEXPRESS` qua xác thực Windows. Lần đầu ứng dụng tạo cơ sở dữ liệu `CafeMay` và nạp dữ liệu mẫu. Sau khi API lắng nghe tại `http://localhost:5187`, mở terminal khác từ thư mục gốc của repo.

```powershell
cd cafe_order_app
flutter pub get
flutter run -d windows
```

Thay lệnh cuối bằng `flutter run -d chrome` để mở trên Chrome. Android dùng `flutter run -d <device-id>`.

- [Hướng dẫn Flutter, tài khoản mẫu và cách trình diễn](cafe_order_app/README.md)
- [Cấu hình SQL Server và danh sách API](cafe_order_app/docs/API_HANDOFF.md)
- [Lược đồ và truy vấn quản lý CafeMay](CafeWebApi/CafeMay.sql)
