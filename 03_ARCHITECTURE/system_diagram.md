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
| Chốt `x` vào thanh ghi | ✅ | I02 — `x_reg` ⚠️ **đã bị xoá khỏi netlist** |
| **Vòng lặp 4 bước so sánh–trừ** | ✅ | I02 — `S_ITER` ⚠️ **đường dữ liệu đã bị xoá** |
| Bắt tay `start` / `busy` / `done` | ✅ | I02 — còn nguyên trong netlist |
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
| **I02** | **Digital thuần, đồng bộ, một miền clock** | 26 cell, 7 FF — **nhưng xem cảnh báo §5** |
| Miền clock | **Một miền duy nhất** (`clk`) | Không có biên CDC, không cần bộ đồng bộ hoá |

## 4. Vòng đời RTL → GDSII — trạng thái **thật**

```
 ┌──────────────┐
 │ Đặc tả       │ ✅  Charter + 01_REQUIREMENT + 02_SPECIFICATION
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô hình chuẩn│ ✅ PASS   python_reference_run.log
 │ (Python)     │           quét VÉT CẠN 256 giá trị + 10 000 random (seed 2026)
 │              │           + kiểm mở rộng 16 bit (test_16bit_scaling)
 └──────┬───────┘
 ┌──────▼───────┐
 │ RTL          │ ✅ có mã   rtl/i02_integer_sqrt.sv
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô phỏng RTL │ ❌ COMPILE_FAIL
 │              │    "i02_integer_sqrt.sv:59: error: root Unable to assign
 │              │     to unresolved wires. / 1 error(s) during elaboration."
 └──────┬───────┘   ◀── ĐỨT MẠCH BẰNG CHỨNG TẠI ĐÂY
 ┌──────▼───────┐
 │ Tổng hợp     │ 🟡 "PASS" NHƯNG SINH RA MẠCH RỖNG
 │              │    yosys.log dòng 170–173:
 │              │    "Warning: Driver-driver conflict for \root [3..0]
 │              │     ... Resolved using constant."
 │              │    → netlist.v:182  assign root = 4'h0;
 │              │    → 26 cell, 7 FF, cổng x KHÔNG được dùng
 └──────┬───────┘
 ┌──────▼───────┐
 │ STA          │ 🟡 "PASS" nhưng đo một mạch rỗng
 │              │    slack 8,40 ns · endpoint _40_ = iter[1]
 └──────┬───────┘
 ┌──────▼───────┐
 │ Công suất    │ 🟡 3,22e-05 W — của mạch rỗng
 └──────┬───────┘
 ┌──────▼───────┐
 │ Mô phỏng     │ ⬜ CHƯA CHẠY — và đây là bước ĐÁNG LẼ đã phát hiện lỗi
 │ gate-level   │    test_matrix.csv: L4-GATE = "CHUA CHAY"
 └──────┬───────┘
 ┌──────▼───────┐
 │ Floorplan …  │ ⬜ chưa chạy (Floorplan · Placement · CTS · Routing · DRC · LVS · GDS)
 │ … GDSII      │    Charter mục 3 xếp vào MỞ RỘNG TỰ NGUYỆN
 └──────────────┘
 ┌──────────────┐
 │ Tape-out     │ ⬛ KHÔNG ÁP DỤNG — Charter mục 3 liệt vào ngoài phạm vi
 │ Chế tạo      │ ⬛ KHÔNG ÁP DỤNG
 └──────────────┘
```

## 5. 🔴 Cảnh báo bắt buộc về chuỗi bằng chứng

Đề này là **ví dụ điển hình về cách một chuỗi công cụ có thể cho ra toàn dấu ✅ trong khi
sản phẩm hoàn toàn rỗng.**

| Bước | Báo cáo | Sự thật |
|---|---|---|
| Mô hình chuẩn | ✅ PASS | ✅ **Thật sự đúng** — thuật toán được hiểu đúng |
| Mô phỏng RTL | ❌ FAIL | Trung thực — đây là dấu hiệu duy nhất được báo đúng |
| Tổng hợp | ✅ PASS, 26 cell | 🔴 **Sai lệch** — Yosys chỉ cảnh báo (`Warning`), không dừng, và **im lặng nối `root` về 0** |
| STA | ✅ PASS, slack 8,40 ns | 🔴 **Vô nghĩa** — đo timing của một bộ đếm 3 bit |
| Công suất | ✅ 3,22e-05 W | 🔴 **Vô nghĩa** — 93,7 % tuần tự vì chỉ còn 7 FF |

**Ba nguyên tắc rút ra, đáng ghi vào sổ tay:**

1. **`Warning` của công cụ tổng hợp không được bỏ qua.** Bốn dòng
   `Driver-driver conflict ... Resolved using constant` trong `yosys.log` là toàn bộ nội
   dung của lỗi CT-2. Nên chạy Yosys với chính sách coi cảnh báo loại này là lỗi.
2. **Luôn `grep "assign" netlist.v`.** Một dòng `assign <cổng ra> = <hằng số>` là bằng
   chứng không thể chối cãi rằng logic đã bị xoá. Ở đây: `assign root = 4'h0;`.
3. **Luôn đối chiếu số FF với dự báo.** Charter mục 10 nói 18–22; netlist có **7**. Đây
   là bài kiểm tra tự động hoá được và đã **trượt**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
