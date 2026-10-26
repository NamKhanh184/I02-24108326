# I02 — Báo cáo tổng hợp, STA, công suất và trạng thái vật lý

## 1. Kết quả trong hồ sơ tham chiếu

Các số liệu trong README tham chiếu là kết quả tổng hợp/STA trước place & route. Raw
report Yosys/OpenSTA tương ứng chưa có trong checkout, vì vậy chưa thể tái xác nhận độc
lập các số liệu đó.

| Công đoạn / chỉ số | Kết quả tham chiếu | Công cụ / điều kiện |
|---|---:|---|
| Tổng hợp | **PASS · 118 cell · 26 FF** | Yosys 0.33, sky130_fd_sc_hd |
| Diện tích cell tổng hợp | **1122,3264 µm²** | Liberty `sky130_fd_sc_hd__tt_025C_1v80.lib` |
| STA trước P&R | **PASS · 2,86 ns** | OpenSTA 3.1.0 |
| Đường tới hạn | `_191_` → `_199_` | Báo cáo theo README tham chiếu |
| Công suất ước lượng trước P&R | **1.75e-04 W** | OpenSTA 3.1.0 |

## 2. Kết quả physical design ngày 2026-10-26

LibreLane/OpenROAD hoàn tất flow cho thiết kế `i02_integer_sqrt` với clock period 10 ns,
PDK `sky130A` và thư viện `sky130_fd_sc_hd`. RTL dùng trong flow tại `rtl/project.sv`
cùng logic chức năng với bản triển khai trong `04_IMPLEMENTATION/rtl/`.

| Công đoạn / chỉ số | Kết quả từ metrics/log |
|---|---:|
| Flow | **Hoàn tất** · 0 flow errors |
| GDS | Sinh được bản Magic và KLayout |
| Diện tích instance sau physical design | **3633,48 µm²** |
| Slack setup tệ nhất | **4,0016 ns** · không có setup violation |
| Slack hold tệ nhất | **0,2878 ns** · không có hold violation |
| DRC Magic / KLayout | **0 / 0 lỗi** |
| LVS | **Mạch khớp** · 0 device/net/property differences |
| Route DRC cuối | **0 lỗi** |
| Công suất tổng ước lượng | **3,4978e-04 W** |
| Cảnh báo lint | 5 |

Metrics, GDS và log được chọn cho từng công đoạn đã được đưa vào các thư mục tương ứng
trong `06_GDSII/`. Log đầy đủ nằm dưới `../runs/runs/RUN_2026-10-26_04-16-30/`. Các số
liệu physical design này là một lần chạy riêng, không thay thế các số tổng hợp/STA tham
chiếu ở §1. Slack là biên timing theo cấu hình 10 ns, không phải độ trễ đường truyền.

## 3. Giả định timing và lưu ý về tần số

Ràng buộc SDC đặt chu kỳ clock 10,0 ns và input/output delay 1,0 ns. Chu kỳ 10,0 ns
tương ứng 100 MHz, không phải 10 MHz. README tham chiếu ghi đồng thời “10 MHz” và “10 ns”,
nên hai thông tin đó mâu thuẫn. Physical flow trên chỉ xác nhận kết quả theo cấu hình
10 ns; không khẳng định tần số hoạt động hệ thống.

Kết quả STA phụ thuộc thư viện, góc PVT, cấu hình flow và giả định IO. Không suy ra khả
năng chế tạo, tape-out hay sign-off từ việc flow tạo GDS hoặc các checker báo 0 lỗi.

## 4. Khả năng tái tạo

Các script tổng hợp, STA và physical design nằm trong
[`../04_IMPLEMENTATION/scripts/`](../04_IMPLEMENTATION/scripts/). Lệnh chạy được liệt kê
trong [`../07_TRACEABILITY/evidence_index.md`](../07_TRACEABILITY/evidence_index.md) §5.
Flow physical cần PDK sky130A cùng LibreLane/OpenROAD.
