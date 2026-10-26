# I02 — Giới hạn và phạm vi kết luận

## 1. Đã có bằng chứng

- Mô hình chuẩn Python độc lập kiểm tra toàn bộ 256 giá trị 8-bit, các ca biên, 10.000
  ca ngẫu nhiên với seed cố định và số vòng lặp của thuật toán.
- Testbench RTL tự kiểm chạy bằng Icarus Verilog; các ca bắt buộc của Charter gồm
  `x=0`, `1`, `255`, `100` và `99`.
- README tham chiếu ghi nhận 118 cell, 26 flip-flop, diện tích 1122,3264 µm², STA 2,86 ns
  và công suất ước lượng 1.75e-04 W. Raw reports tổng hợp/STA tham chiếu chưa có trong
  checkout để xác nhận độc lập.
- Physical flow ngày 2026-10-26 đã hoàn tất, tạo GDS, metrics và báo cáo checker. Metrics
  ghi nhận 0 lỗi DRC Magic/KLayout, LVS khớp và không có setup/hold violation theo cấu hình
  flow; xem [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md).

## 2. Chưa được chứng minh

| Tuyên bố | Vì sao chưa được chứng minh |
|---|---|
| Timing đáp ứng yêu cầu hệ thống | Flow physical có slack dương theo clock 10 ns và giả định IO đã cấu hình; chưa có yêu cầu hệ thống nhất quán (README nêu 10 MHz nhưng SDC là 10 ns) |
| RTL được xác minh cho mọi tham số | Mô hình Python kiểm tra 16-bit; testbench RTL hiện chỉ khởi tạo thiết kế 8-bit |
| Chức năng sau place & route | Chưa chạy mô phỏng gate-level hoặc post-layout có SDF |
| Thiết kế đã sign-off, tape-out, chế tạo hoặc kiểm tra silicon | Ngoài phạm vi bằng chứng hiện có |

## 3. Ràng buộc clock

SDC đặt chu kỳ 10 ns, tương ứng 100 MHz. README tham chiếu đồng thời ghi 10 MHz và
10 ns; hai giá trị không tương đương. Không dùng dòng “10 MHz” để suy ra kết quả timing
cho tới khi thông tin clock được xác nhận nhất quán.

## 4. Quy tắc diễn giải

Các trạng thái `Pass theo hồ sơ tham chiếu` trong
[`RTM.csv`](RTM.csv) không đồng nghĩa raw evidence đã được lưu trong checkout. Chỉ khẳng
định mức mà artifact hiện có hỗ trợ; không coi mô phỏng hành vi là bằng chứng cho timing,
hay hành vi sau chế tạo. DRC/LVS trong physical flow chỉ hỗ trợ kết luận cho lần chạy và
cấu hình đã ghi nhận, không phải sign-off tổng thể.
