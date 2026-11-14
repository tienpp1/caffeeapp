# REST API của Cà Phê Mây

Dự án [CafeWebApi](../../CafeWebApi/CafeWebApi.csproj) dùng ASP.NET Core 10, Entity Framework Core và SQL Server. Bản Windows và trình duyệt gọi API mặc định qua `http://localhost:5187`. Bản Android dùng SQLite trên thiết bị. Dữ liệu SQLite và SQL Server hiện độc lập.

## Khởi động

Chạy từ thư mục gốc của repo bằng PowerShell.

```powershell
cd CafeWebApi
dotnet watch run
```

Có thể mở terminal khác để kiểm tra bằng `Invoke-RestMethod http://localhost:5187/api/health`. API trả về `status: ok` khi kết nối SQL Server thành công.

Cấu hình Development dùng SQL Server Express `.SQLEXPRESS`, cơ sở dữ liệu `CafeMay` và xác thực Windows. Tài khoản Windows chạy .NET cần quyền khởi tạo cơ sở dữ liệu trong lần chạy đầu. Dùng biến môi trường để đổi chuỗi kết nối cho terminal đang chạy API.

```powershell
$env:ConnectionStrings__CafeMay = 'Server=.\SQLEXPRESS;Database=CafeMay;Integrated Security=True;TrustServerCertificate=True'
dotnet watch run
```

Cấu trúc dự án gồm `Api/Controller` cho các endpoint, `Models` cho thực thể và DbContext, `Services` cho nghiệp vụ dùng chung, `Properties` cho cấu hình chạy và `wwwroot` cho tài nguyên tĩnh. Dự án `WebApi` của BTCK là mã nguồn tham khảo.

## Endpoint

| Nhóm | Endpoint |
| --- | --- |
| Sức khỏe | `GET /api/health` |
| Tài khoản | `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/auth/me`, `PUT /api/auth/password`, `POST /api/auth/logout` |
| Thành viên | `GET /api/members`, `PUT /api/members/{id}` |
| Danh mục | `GET /api/categories`, `POST /api/categories`, `PUT /api/categories/{id}`, `DELETE /api/categories/{id}` |
| Món và ảnh | `GET /api/products`, `GET /api/products/{id}`, `POST /api/products`, `PUT /api/products/{id}`, `DELETE /api/products/{id}`, `GET /api/images/{id}` |
| Giỏ | `GET /api/cart`, `GET /api/cart/count`, `POST /api/cart/{productId}`, `PUT /api/cart/{productId}` |
| Đơn | `GET /api/orders`, `POST /api/orders`, `GET /api/orders/{id}`, `GET /api/orders/{id}/lines`, `PUT /api/orders/{id}/status` |

API kiểm tra Bearer token và quyền ở mỗi thao tác có xác thực. Member xem đơn của tài khoản đang đăng nhập. Admin quản lý danh mục, món, thành viên và trạng thái đơn. Giỏ và tồn kho được cập nhật cùng giao dịch tạo đơn. Hủy đơn ở trạng thái cho phép sẽ hoàn tồn. Ảnh thêm hoặc thay qua API được lưu trong SQL Server.

## Dịch vụ ngoài còn lại

Xác minh email, gửi liên kết đặt lại mật khẩu, đăng nhập Google/Facebook/Zalo và thanh toán VNPayment/VietQR cần cấu hình dịch vụ tương ứng. Hiện tại nhân viên ghi nhận tiền mặt tại quầy. [Requirement Flutter](http://ceb.net.vn/flutter/requirement.html).
