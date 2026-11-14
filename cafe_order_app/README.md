# Cà Phê Mây

Ứng dụng gọi món tại bàn, phục vụ và ghi nhận thanh toán cho một quán cà phê. Đây là đề tài số 2 **Xây dựng ứng dụng hỗ trợ nhà hàng, quán caphe quản lý việc order, tính tiền và phục vụ** trong danh sách đề tài học phần. Flutter dùng chung giao diện cho Android, Windows và trình duyệt. Windows và trình duyệt dùng REST API với SQL Server. Android dùng SQLite trên thiết bị.

Đề tài số 3 về thu chi và số 12 về nhắc việc dễ triển khai riêng lẻ, nhưng cần giải trình nghiệp vụ tương đương cho giỏ, đặt hàng và quản lý đơn trong bảng chấm điểm. Đề tài số 5 về thiết bị cho thuê đáp ứng các nhóm này và cần thêm quy tắc kiểm tra trùng lịch thuê. Đề tài số 2 đáp ứng trực tiếp bảng chấm điểm với phạm vi một quán, 12 bàn và thu tiền mặt. Gọi món tại bàn, chuyển phiếu sang quầy pha chế và ghi nhận thanh toán cũng là các nghiệp vụ của phần mềm quản lý quán đang được cung cấp tại Việt Nam. [MISA CukCuk cho quán cà phê](https://www.cukcuk.vn/cafe/).

## Chạy bằng hai terminal

Máy chạy API cần .NET SDK 10 và một SQL Server. Máy chạy Flutter cần Flutter SDK với Dart 3.13.1 trở lên. Dùng Chrome hoặc Edge để chạy web. Bản desktop Windows cần Visual Studio có workload **Desktop development with C++**.

Mở hai terminal ở thư mục gốc của repo. **Terminal 1** chạy API.

```powershell
cd CafeWebApi
dotnet watch run
```

API lắng nghe tại `http://localhost:5187`. Cấu hình Development dùng SQL Server Express `.\SQLEXPRESS` và xác thực Windows. Lần đầu, API khởi tạo cơ sở dữ liệu `CafeMay` cùng thực đơn và tài khoản mẫu. Nếu dùng SQL Server khác, xem [cấu hình API](docs/API_HANDOFF.md).
Đợi terminal hiển thị `Now listening on: http://localhost:5187` rồi giữ terminal này mở.

**Terminal 2** chạy Flutter. Chọn một thiết bị đích.

```powershell
cd cafe_order_app
flutter pub get
flutter run -d windows
# Hoặc chạy trên trình duyệt
flutter run -d chrome
# Hoặc dùng Microsoft Edge
flutter run -d edge
```

Windows và web chia sẻ dữ liệu qua SQL Server. Web yêu cầu đăng nhập lại sau khi tải lại trang. Để chạy Windows với dữ liệu SQLite riêng, dùng `flutter run -d windows --dart-define=CAFE_OFFLINE=true`. Trên Android, `flutter run -d <device-id>` dùng SQLite. Nếu API lắng nghe ở cổng khác, thêm `--dart-define=CAFE_API_URL=http://localhost:<port>` vào lệnh Flutter.

Ảnh bìa được tạo bằng ImageGen với cảnh một ly cà phê muối trên bàn đá dưới nắng xiên. Ảnh món mẫu được tạo từ bảng 4 × 4 gồm đồ uống và món nhẹ của quán cà phê Việt Nam. Ảnh bìa, món và danh mục nằm trong `assets/branding/`, `assets/products/` và `assets/categories/`. Font chữ đi kèm ứng dụng để dùng được khi ngoại tuyến.

| Vai trò | Email mẫu | Mật khẩu mẫu |
| --- | --- | --- |
| Quản trị viên | `admin@cafemay.vn` | `Admin@12345` |
| Thành viên | `member@cafemay.vn` | `Member@12345` |

Mỗi kho dữ liệu có thực đơn và hai tài khoản mẫu riêng. Nút điền nhanh trên màn hình đăng nhập hỗ trợ trình diễn từng vai trò. Mật khẩu được băm với salt riêng. Phiên Windows lưu trong secure storage. Phiên web nằm trong bộ nhớ của trang.

## Quy trình nghiệp vụ

1. **Gọi món tại bàn.** Thành viên lọc và tìm món, xem chi tiết, thêm món vào giỏ, điều chỉnh số lượng và chọn bàn từ 1 đến 12. Khi gửi đơn, ứng dụng kiểm tra số phần còn lại, lưu chi tiết và tổng tiền tại thời điểm đặt. Thành viên xem lại đơn và theo dõi tiến độ.
2. **Phục vụ và tính tiền.** Quản trị viên tra cứu đơn, xác nhận, chuyển sang pha chế, báo sẵn sàng và ghi nhận đã phục vụ. Quầy thu tiền mặt và ghi nhận thanh toán cho đơn đã phục vụ. Quản trị viên có thể hủy đơn ở hai trạng thái đầu. Khi hủy, số lượng của đơn được hoàn lại vào tồn.

## Đối chiếu yêu cầu học phần

| Nhóm | Chức năng trên SQLite và REST API |
| --- | --- |
| Xác thực | Đăng ký, đăng nhập, đổi mật khẩu, đăng xuất và phân quyền Admin/Member. Admin tìm và chỉnh sửa tên, vai trò, trạng thái hoạt động của thành viên. |
| Danh mục | Liệt kê, thêm, sửa, xóa và kiểm tra danh mục còn món. Chọn, thay hoặc xóa ảnh danh mục. |
| Quản lý sản phẩm | Liệt kê món theo danh mục có phân trang. Thêm món kèm ảnh, sửa và thay ảnh, xóa món kèm ảnh. Kiểm tra món đã có trong đơn trước khi xóa. |
| Trang chủ | Hiển thị danh mục và món mới, lọc theo danh mục, tìm món, xem chi tiết. Món mới, kết quả lọc/tìm và món liên quan có phân trang. |
| Giỏ hàng | Thêm món, xem tổng số lượng trên biểu tượng, xem giỏ, đổi số lượng, xóa món, đặt món, xem chi tiết và tìm đơn cá nhân. |
| Quản lý đơn | Liệt kê, tìm, lọc theo ngày tạo, cập nhật trạng thái phục vụ và ghi nhận đã thanh toán tiền mặt. |

Sản phẩm trong tiêu chí là món trong thực đơn. Giỏ hàng là giỏ gọi món. Đơn hàng là phiếu phục vụ tại bàn. Quản trị viên chọn ảnh JPEG, PNG hoặc WebP tối đa 5 MB. Android lưu ảnh thêm mới trong SQLite. Windows và trình duyệt gửi ảnh qua API để lưu trong SQL Server. [Tài liệu REST API](docs/API_HANDOFF.md). [Requirement Flutter](http://ceb.net.vn/flutter/requirement.html).

## Kế hoạch

1. Đối chiếu đề tài với BTCK và chốt hai quy trình tại quán.
2. Dùng lại cấu trúc màn hình, bổ sung SQLite và thực đơn mẫu. Lưu đơn, chi tiết, tồn và giỏ trong giao dịch khi gửi đơn.
3. Hoàn thiện đặt món, phục vụ, thu tiền và quản trị. Kiểm tra nhập sai, vượt tồn, thay đổi trạng thái, xóa dữ liệu có tham chiếu và quyền của từng vai trò.
4. Triển khai REST API ASP.NET Core 10 và SQL Server cho Windows và trình duyệt. Kiểm tra luồng Flutter, SQLite và API. Ghi các tích hợp bên ngoài trong tài liệu API.

## Prompt triển khai

> Dựa trên BTCK, chọn đề tài số 2 và xây dựng Cà Phê Mây bằng Flutter/Dart, SQLite và REST API ASP.NET Core 10 với SQL Server. Áp dụng cấu trúc danh mục, sản phẩm, giỏ, đơn và tài khoản vào nghiệp vụ gọi món tại bàn. Hoàn thiện đăng ký, đăng nhập, đổi mật khẩu, đăng xuất, phân quyền, quản lý thành viên, danh mục và món. Bổ sung ảnh, tìm kiếm, lọc, phân trang và món liên quan. Triển khai đặt món theo bàn, kiểm tra tồn, tra cứu đơn, xác nhận, pha chế, phục vụ và thu tiền mặt. Hủy đơn và hoàn tồn trong cùng giao dịch. Kiểm tra Android với SQLite và Windows hoặc trình duyệt qua REST API.

## Trình diễn nhanh

1. Đăng nhập bằng tài khoản Thành viên. Tìm một món, thêm vào giỏ, chỉnh số lượng, chọn bàn và ghi lại mã đơn.
2. Đăng xuất rồi đăng nhập bằng tài khoản Quản trị viên. Mở **Quản lý đơn**, tìm mã đơn, cập nhật từng bước phục vụ, sau đó ghi nhận thu tiền mặt.
3. Đăng nhập lại bằng tài khoản Thành viên để xem đơn đã thanh toán. Đóng và mở lại ứng dụng để kiểm tra dữ liệu được lưu.
4. Dùng tài khoản Quản trị viên tạo một danh mục và một món kèm ảnh. Thay ảnh rồi xóa món và danh mục. Thử xóa một danh mục còn món hoặc một món từng xuất hiện trong đơn để kiểm tra thông báo.

## Kiểm thử

Bộ kiểm thử có bảy ca SQLite và hai ca Flutter widget, bao gồm vòng đời ảnh, phân quyền, giao dịch tồn kho, lưu dữ liệu qua lần mở lại và luồng đặt món đến thu tiền. Trên SQL Server Express, 43 kiểm tra API đã đạt, gồm đăng nhập, phân quyền, tải ảnh multipart, thu tiền và hoàn tồn khi hủy. Bản Windows mở được dữ liệu mẫu với `flutter run -d windows`. Chrome đã đăng nhập, thêm và xóa món trong giỏ qua API.

```powershell
flutter test
```

## APK Android

Bản debug cho ARM64 và x86_64 nằm tại [app-debug.apk](build/app/outputs/flutter-apk/app-debug.apk) sau khi build. Đã cài, mở thực đơn và xác nhận ứng dụng khởi tạo SQLite trên giả lập khi Wi-Fi và dữ liệu di động tắt. Giả lập bị treo giao diện hệ thống trong lần thao tác tiếp theo. Luồng đặt món đến thu tiền được xác minh bằng Flutter widget test.

```powershell
flutter build apk --debug --target-platform android-arm64,android-x64
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
