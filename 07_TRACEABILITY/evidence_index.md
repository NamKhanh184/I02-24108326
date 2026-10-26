# I02 — Chỉ mục bằng chứng

## 1. Nguồn và điều kiện

Các khẳng định chức năng được kiểm tra trên RTL `i02_integer_sqrt`, dùng Icarus Verilog
12.0 với cờ SystemVerilog `-g2012`. Mô hình chuẩn Python độc lập chạy bằng CPython 3.
Số liệu tổng hợp và STA trước P&R được ghi lại trong README tham chiếu; raw reports tương
ứng chưa có trong checkout. Physical flow chạy ngày 2026-10-26 có metrics và GDS được lưu
trong `06_GDSII/`; log từng bước vẫn được giữ trong `runs/`. Xem
[`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md).

## 2. Chỉ mục

| Bằng chứng | Vị trí | Cách tạo / điều kiện | Trạng thái |
|---|---|---|---|
| Mô hình chuẩn căn nguyên | `../05_VERIFICATION/golden_model/reference_model.py` | `python3` trên CPython 3; vét cạn 8-bit, ca biên, random seed 2026 và kiểm tra 16-bit | Có mã; chạy lại theo §5 |
| Testbench RTL | `../05_VERIFICATION/testbench/i02_integer_sqrt_tb.sv` | Mô phỏng RTL đã vá bằng Icarus Verilog 12.0 | PASS khi chạy lại |
| Ma trận kiểm thử | `../05_VERIFICATION/test_matrix.csv` | Đối chiếu testbench với Charter và lớp kiểm chứng | Có |
| Waveform RTL | `../05_VERIFICATION/waveforms/` | Sinh bởi script mô phỏng; định dạng VCD | Có |
| Log mô phỏng workflow | `../05_VERIFICATION/workflow/` | Icarus Verilog; log và phiên bản công cụ của lần chạy workflow | Có |
| Báo cáo tổng hợp / STA trước P&R | `../06_GDSII/physical_report.md` | Số liệu tham chiếu README; raw reports chưa có trong checkout | Tham chiếu |
| Physical metrics | `../06_GDSII/metrics.csv`; `../06_GDSII/metrics.json` | LibreLane/OpenROAD; run 2026-10-26 | Có |
| Log từng công đoạn physical | `../06_GDSII/{synthesis,sta,power,floorplan,placement,cts,routing,drc,lvs}/` | Trích log gốc từ run 2026-10-26; toàn bộ run vẫn ở `../runs/` | Có |
| GDS | `../06_GDSII/gds/` | Stream-out Magic và KLayout | Có |
| Netlist flow | `../06_GDSII/synthesis/netlist/` | Netlist trong artifact physical flow | Có |
| Giới hạn của kết luận | `limitations.md` | Đối chiếu mức kiểm chứng với các tuyên bố được phép | Có |

## 3. Truy vết theo yêu cầu

Xem [`RTM.csv`](RTM.csv) để biết kiểm chứng, evidence path và trạng thái cho từng
`REQ-I02-xxx`.

## 4. Kết luận có thể hỗ trợ

- Mô hình chuẩn kiểm tra phép căn nguyên 8-bit trên toàn miền và số vòng lặp thuật toán.
- Mô phỏng RTL chạy qua testbench tự kiểm và các ca bắt buộc của Charter.
- Số liệu tổng hợp/STA trước P&R được chép từ README tham chiếu; raw reports gốc chưa có
  trong checkout.
- Physical flow ngày 2026-10-26 đã tạo GDS; metrics ghi nhận 0 flow errors, 0 DRC errors
  của Magic/KLayout và LVS match. Điều này không phải sign-off.
- Mô phỏng gate-level và post-layout có SDF chưa chạy; sign-off, tape-out và chế tạo
  chưa được xác nhận.

## 5. Chạy lại

Chạy từ thư mục gốc dự án:

```bash
python3 05_VERIFICATION/golden_model/reference_model.py
bash 04_IMPLEMENTATION/scripts/01_run_sim.sh
bash 04_IMPLEMENTATION/scripts/02_run_synth.sh
sta -no_splash -exit 04_IMPLEMENTATION/scripts/03_run_sta.tcl
bash 04_IMPLEMENTATION/scripts/04_run_librelane.sh
```

Tổng hợp và STA cần thư viện sky130 Liberty; physical design cần PDK sky130A cùng
LibreLane/OpenROAD. Script P&R dừng với thông báo nếu môi trường chưa đủ, không tạo kết
quả giả. Xem [`../04_IMPLEMENTATION/README.md`](../04_IMPLEMENTATION/README.md) để biết
chi tiết công cụ.
