# I02 · Sơ đồ hệ thống (System Diagram)

---

## 1. Bối cảnh ứng dụng (Charter mục 1)

> “Khối tính độ lớn vector từ hai thành phần trong bộ đo gia tốc (**căn của tổng bình
> phương**).”

Công thức đầy đủ: `|a| = √(aₓ² + a_y²)`. I02 chỉ làm **bước cuối** — lấy căn. Bước bình
phương và cộng nằm ở khối khác.

```
 ┌──────────────────────────── NGOÀI CHIP ───────────────────────────┐
 │  ┌──────────────┐                                                 │
 │  │ Cảm biến MEMS│  hai trục X, Y                                  │
 │  │ gia tốc      │  (ANALOG)                                       │
 │  └──────┬───────┘                                                 │
 └─────────┼─────────────────────────────────────────────────────────┘
           │ hai kênh tương tự
 ┌─────────▼──────────────────────────────── TRONG CHIP ─────────────┐
 │  ┌──────────────┐                                                 │
 │  │  ADC 2 kênh  │  (MIXED-SIGNAL)                                 │
 │  └──────┬───────┘                                                 │
 │         │ ax[3:0], ay[3:0]                                        │
 │         ▼                                                         │
 │  ┌───────────────────────────────┐                                │
 │  │ BỘ BÌNH PHƯƠNG + CỘNG         │   ax² + ay²                    │
 │  │ (khối khác — có thể là I03)   │                                │
 │  └───────────────┬───────────────┘                                │
 │                  │ x[7:0] = tổng bình phương                      │
 │                  ▼                                                │
 │      ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓                          │
 │      ┃                                 ┃                          │
 │      ┃   ███  I02  ███                 ┃                          │
 │      ┃   Căn bậc hai nguyên 8 bit      ┃                          │
 │      ┃   theo từng bit (4 bước lặp)    ┃                          │
 │      ┃                                 ┃                          │
 │      ┃   x[7:0]  ◀── tổng bình phương  ┃                          │
 │      ┃   start   ◀── điều khiển        ┃                          │
 │      ┃   clk, rst_n ◀──                ┃                          │
 │      ┃                                 ┃                          │
 │      ┃   root[3:0] ──▶ |a| (độ lớn)    ┃                          │
 │      ┃   busy      ──▶ bắt tay         ┃                          │
 │      ┃   done      ──▶ bắt tay         ┃                          │
 │      ┗━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━┛                          │
 │                      │  (KHỐI ĐANG XÉT)                           │
 │                      ▼                                            │
 │      ┌──────────────────────────────┐                             │
 │      │ So ngưỡng / phát hiện va đập │                             │
 │      │ / ghi log / truyền ra ngoài  │                             │
 │      └──────────────────────────────┘                             │
 └───────────────────────────────────────────────────────────────────┘
```

> **Vì sao cần căn bậc hai mà không dùng thẳng tổng bình phương?**
> So ngưỡng trên `ax²+ay²` về mặt toán học tương đương với so trên `|a|` (vì hàm căn đơn
> điệu tăng). Nhưng `|a|` là đại lượng **có đơn vị vật lý** (g), đọc được, hiển thị được,
> và ngưỡng đặt theo `|a|` không bị co giãn phi tuyến. Đó là lý do bước lấy căn được đưa
> vào phần cứng thay vì để phần mềm làm.

## 2. Ranh giới khối — ai làm gì

| Chức năng | Thuộc I02? | Ai làm |
|---|:-:|---|
| Đo gia tốc hai trục | ❌ | Cảm biến MEMS (analog) |
| Số hoá | ❌ | ADC (mixed-signal) |
| Bình phương từng thành phần, cộng lại | ❌ | Khối bình phương–cộng bên ngoài |
| Chốt `x` vào thanh ghi | ✅ | I02 — `x_reg` trong RTL đã vá |
| **Vòng lặp 4 bước so sánh–trừ** | ✅ | I02 — `S_ITER`, testbench kiểm 4 chu kỳ `busy` |
| Bắt tay `start` / `busy` / `done` | ✅ | RTL và testbench |
| Quyết định ngưỡng va đập | ❌ | Tầng ứng dụng |
| Làm tròn thay vì cắt (`round` thay `floor`) | ❌ | Không làm được — I02 **không** đưa phần dư ra ngoài |

> ⚠️ **Một hạn chế giao diện đáng bàn:** I02 giữ `rem_reg` nội bộ và **không có cổng ra
> cho phần dư**. Hệ quả: tầng ngoài không biết `x` có phải số chính phương hay không, và
> không thể tự làm tròn. Đối chiếu với đề I01 — bộ chia **có** đưa `remainder` ra ngoài
> chính vì lý do đó. Thêm một cổng `rem_zero` (1 bit) sẽ rẻ và hữu ích; xem `tradeoff.md`.

> **Nghĩa vụ hợp đồng của tầng ngoài** (chi tiết `functional_spec.md` §9): giữ `x` ổn định
> tại cạnh lấy mẫu `start` · phát `start` đúng 1 chu kỳ · chốt `root` tại chu kỳ `done=1` ·
> giữ `rst_n=0` qua ít nhất 1 cạnh `clk`.

## 3. Phân loại analog / digital / mixed (Charter mục 3)

| Thành phần | Loại | Ghi chú |
|---|---|---|
| Cảm biến MEMS | **Analog** | Ngoài phạm vi (Charter mục 3, mọi đề) |
| ADC | **Mixed-signal** | Ngoài phạm vi |
| Bộ bình phương–cộng | **Digital đồng bộ** | Khối khác |
| **I02** | **Digital thuần, đồng bộ, một miền clock** | 118 cell, 26 FF theo README tham chiếu |
| Miền clock | **Một miền duy nhất** (`clk`) | Không có biên CDC, không cần bộ đồng bộ hoá |

## 4. Vòng đời RTL → GDSII — trạng thái hồ sơ

```
 ┌──────────────┐
 │ Đặc tả       │ ✅  Charter + 01_REQUIREMENT + 02_SPECIFICATION
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô hình chuẩn│ ✅ PASS   reference_model.py
 │ (Python)     │           quét vét cạn 256 giá trị + 10 000 random (seed 2026)
 │              │           + kiểm mở rộng 16 bit (test_16bit_scaling)
 └──────┬───────┘
 ┌──────▼───────┐
 │ RTL          │ ✅ đã vá   04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô phỏng RTL │ ✅ PASS · Icarus Verilog 12.0
 │              │    15 ca, gồm các ca bắt buộc x=0,1,99,100,255
 │              │    và kiểm 4 chu kỳ busy
 └──────┬───────┘
 ┌──────▼───────┐
 │ Tổng hợp     │ ✅ 118 cell · 26 FF (theo README tham chiếu)
 └──────┬───────┘
 ┌──────▼───────┐
 │ STA          │ ✅ 2,86 ns (theo README tham chiếu)
 └──────┬───────┘
 ┌──────▼───────┐
 │ Công suất    │ ✅ 1.75e-04 W ước lượng (theo README tham chiếu)
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô phỏng     │ ⬜ chưa chạy
 │ gate-level   │
 └──────┬───────┘
 ┌──────▼───────┐
 │ Physical     │ ✅ P&R hoàn tất
 │ design       │    P&R hoàn tất · DRC 0 lỗi · LVS match
 │              │    sign-off chưa xác nhận
 └──────────────┘
 ┌──────────────┐
 │ Tape-out     │ ⬛ KHÔNG ÁP DỤNG — Charter mục 3 liệt vào ngoài phạm vi
 │ Chế tạo      │ ⬛ KHÔNG ÁP DỤNG
 └──────────────┘
```

## 5. Giới hạn bằng chứng

Các trạng thái tổng hợp, STA và công suất trước P&R ở trên được ghi nhận trong README
tham chiếu; raw reports tương ứng chưa có trong checkout để tái xác nhận. Physical flow
ngày 2026-10-26 đã hoàn tất, DRC Magic/KLayout không có lỗi và LVS match; xem
[`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md). Gate-level và sign-off
chưa được xác nhận. Chẩn đoán sự cố D-1 trước vá được giữ riêng trong
[`../05_VERIFICATION/known_issues.md`](../05_VERIFICATION/known_issues.md).

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
