# I02 · Báo cáo kiểm chứng (Verification Report)

> 🔧 **ĐỀ NÀY ĐÃ ĐƯỢC VÁ LỖI**
>
> Mô phỏng ban đầu không đạt. Lỗi đã được chẩn đoán, vá và **xác minh lại bằng
> công cụ thật**. Mọi số liệu trong hồ sơ là số liệu **sau khi vá**.
>
> * Mã nguồn gốc: [`08_ORIGINAL_SOURCE/`](08_ORIGINAL_SOURCE/) — giữ nguyên, quay lui được
> * Nhật ký vá: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](08_ORIGINAL_SOURCE/PATCHLOG.md)
> * Chẩn đoán đầy đủ: [`05_VERIFICATION/known_issues.md`](05_VERIFICATION/known_issues.md)



**Ngày chạy:** 2026-09-24 · **Phiên bản:** v1.0

**Xác minh lại trong checkout:** 2026-10-26 · Python reference và mô phỏng RTL PASS;
testbench gồm 15 ca và kiểm tra 4 chu kỳ `busy`. Physical flow cũng hoàn tất ngày
2026-10-26; kết quả được tổng hợp tại `../06_GDSII/physical_report.md`.

---

## 1. Điều kiện tạo ra bằng chứng

> Charter mục 6: *"Mỗi khẳng định đi kèm bằng chứng **và điều kiện tạo ra bằng chứng đó**."*

| Hạng mục | Giá trị |
|---|---|
| Hệ điều hành | Ubuntu 22.04 LTS (x86-64) |
| Công cụ mô phỏng | **Icarus Verilog 12.0 (stable)** (cờ `-g2012`) |
| Top module | `i02_integer_sqrt` |
| RTL | `04_IMPLEMENTATION/rtl/` |
| Mô hình chuẩn | `05_VERIFICATION/golden_model/` |
| Testbench | `05_VERIFICATION/testbench/` |
| Lệnh chạy | `bash 04_IMPLEMENTATION/scripts/01_run_sim.sh` |
| Nguồn gốc gói | `I02_FINAL_MENTOR_PACKAGE_v1_0` |

## 2. Kết quả tổng hợp

| Lớp | Nội dung | Kết quả |
|---|---|---|
| L0 | Mô hình chuẩn Python | ✅ **PASS** |
| L2 | Mô phỏng RTL | ✅ PASS — testbench chạy hết, không có assertion nào vi phạm |
| L3 | Kiểm cấu trúc — số flip-flop | ✅ 26 FF theo README tham chiếu; raw synthesis report chưa có trong checkout |
| L4 | Mô phỏng gate-level | ⬜ chưa chạy |
| L5 | Mô phỏng post-layout (SDF) | ⬜ chưa chạy |

## 3. Trích log mô phỏng

```
VCD info: dumpfile waveforms/i02_integer_sqrt.vcd opened for output.
I02 RTL TB PASS
05_VERIFICATION/testbench/i02_integer_sqrt_tb.sv:71: $finish called at 915 (1s)
```

Log đầy đủ: [`simulation.log`](simulation.log)

## 4. Kiểm cấu trúc — số flip-flop

README tham chiếu ghi nhận kết quả từ Yosys 0.33 (git sha1 2584903a060) +
`sky130_fd_sc_hd`. Raw synthesis report chưa có trong checkout:

| Chỉ số | Giá trị |
|---|---:|
| Tổng số cell | **118** |
| Cell tuần tự (flip-flop / latch) | **26** |
| Diện tích | 1122,3264 µm² |


✅ Số FF được ghi nhận phù hợp với phân loại **Tuần tự** của Charter; cần raw report để
tái xác nhận độc lập.


## 5. Trả lời câu hỏi kỹ thuật của Charter (mục 2)

> 1. Với số 8 bit, thuật toán chạy đúng 4 chu kỳ — kiểm chứng trên waveform?
> 2. Mở rộng lên 16 bit thì số chu kỳ tăng theo quy luật nào, diện tích tăng theo quy luật nào — hai quy luật đó có giống nhau không?
> 3. Thuật toán từng bit khác thử dần ở chỗ nào về số chu kỳ?
> Sinh viên được phép thay bằng câu hỏi của mình, miễn là cụ thể và trả lời được bằng bằng chứng — không viết “tìm hiểu về…”.

Phần trả lời dựa trên số liệu đo được nằm ở:

- Câu về **giao diện / tín hiệu**: `02_SPECIFICATION/interface.md`
- Câu về **thời gian / tần số**: `06_GDSII/metrics.json` và `06_GDSII/physical_report.md`
- Câu về **diện tích / tài nguyên**: `06_GDSII/physical_report.md` §2
- Phân tích bản chất và cơ chế: `implementation-notes_I02.md`

## 6. Những gì báo cáo này **chưa** chứng minh

| Chưa chứng minh | Vì sao |
|---|---|
| Kiến trúc bên trong đúng như mô tả | Kiểm chứng chức năng mù về cấu trúc — phải đọc RTL và netlist |
| Độ trễ lan truyền đạt yêu cầu | Mô phỏng hành vi là zero-delay |
| Chức năng sau place & route | P&R đã tạo GDS; chưa chạy mô phỏng gate-level hoặc post-layout có SDF |
| Không có glitch gây hại | Mô phỏng zero-delay không sinh glitch |

Danh sách đầy đủ: `07_TRACEABILITY/limitations.md`.

---

*Truy vết: REQ-I02-001, REQ-I02-003, REQ-I02-010…013.*
