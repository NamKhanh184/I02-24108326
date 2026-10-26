# I02 · Phân tích đánh đổi (Trade-off)

---

> **Cập nhật sau bản vá P-1:** README tham chiếu ghi nhận 118 cell, 26 FF,
> 1122,3264 µm², STA 2,86 ns và công suất 1.75e-04 W. Raw reports chưa có trong checkout,
> nên các số này chưa được tái xác nhận độc lập. Phần dưới đây giữ lại chẩn đoán netlist
> lỗi trước vá như lịch sử; không dùng số liệu 26 cell/7 FF cũ làm kết quả hiện tại.

---

## 1. Kiến trúc đã chọn

**Khai căn từng bit (digit-by-digit / restoring), radix-2, tiêu thụ 2 bit radicand mỗi
bước, sinh 1 bit `root` mỗi bước, số chu kỳ cố định.** Một bộ so sánh + trừ 9 bit dùng
chung cho cả 4 bước.

## 2. So sánh với các kiến trúc thay thế

| Tiêu chí | **(A) Từng bit** (đã chọn) | (B) Thử dần (trial-and-error) | (C) Newton–Raphson | (D) Bảng tra (LUT) | (E) CORDIC |
|---|---|---|---|---|---|
| Nguyên lý | 4 bước: `trial = 4·root+1`, so sánh–trừ | Tăng `k` từ 0, dừng khi `(k+1)² > x` | Lặp `r ← (r + x/r)/2` | Tra bảng 256 × 4 bit | Xoay vector, dịch–cộng |
| Số chu kỳ | **6 (cố định)** | **1…16 (phụ thuộc dữ liệu!)** | 3–4 lặp, mỗi lặp cần **một phép chia** | **1** | ~W lặp |
| Phần cứng cần | 1 bộ so sánh–trừ 9 bit | 1 bộ nhân + 1 bộ so sánh | **1 bộ chia** — rất đắt | ROM 1024 bit | bộ cộng + bảng arctan |
| Mở rộng lên `W` bit | Tuyến tính | Tệ hơn tuyến tính | Số lặp ~`log W` | **Mũ** — `2^W` phần tử | Tuyến tính |
| Charter cho phép? | ✅ tên đề chỉ định | ❌ **Charter mục 10 cấm thẳng** | 🟡 không cấm nhưng cần bộ chia, phá vỡ quy mô đề | 🟡 không cấm nhưng không còn là “theo từng bit” | ❌ **Charter mục 3: ngoài phạm vi** — đó là đề I05 |
| Khi nào nên dùng | Cần số chu kỳ dự đoán được, phần cứng nhỏ | Không bao giờ | `W` rất lớn (32/64 bit) và **đã có** bộ chia | `W ≤ 8` và ROM rẻ | Cần cả sin/cos/căn trong một khối |

### Vì sao (B) bị Charter mục 10 cấm thẳng

> “Chỗ hay tắc: Dùng vòng lặp **thử dần** cho dễ — đề cấm, vì nó cho số chu kỳ **thay đổi
> theo dữ liệu**.”

Thử dần cho `x=0` cần 1 vòng, cho `x=255` cần 16 vòng. Hệ quả kỹ thuật:

- Không tính được ngân sách thời gian cho hệ thống thời gian thực.
- Không viết được assertion kiểm số chu kỳ (ca B-4 ở `corner_cases.md` trở nên vô nghĩa).
- Cần **bộ nhân** để tính `(k+1)²` — đắt hơn hẳn bộ so sánh–trừ.
- Công suất đỉnh phụ thuộc dữ liệu → lộ thông tin qua kênh biên.

Thuật toán từng bit **mua tính dự đoán được** bằng cách luôn chạy đủ 4 bước. Đó là đánh
đổi trung tâm của đề này.

### Vì sao (D) — bảng tra — hấp dẫn nhưng bị loại

Với `W = 8`, bảng tra chỉ cần **256 × 4 bit = 1024 bit ROM** và cho kết quả trong **1 chu
kỳ**. Nghe rất tốt. Nhưng:

| Vấn đề | Chi tiết |
|---|---|
| Không còn là “theo từng bit” | Tên đề khoá kiến trúc |
| **Không mở rộng được** | `W=16` cần `65536 × 8 bit = 512 kbit` — gấp **512 lần**. Đây là tăng trưởng **mũ** |
| Không dạy được gì | Toàn bộ nội dung thuật toán biến mất |

> 📌 Đây là bài học đáng giá: **một kiến trúc tốt ở một cỡ có thể vô dụng ở cỡ khác.**
> Quy luật tăng trưởng quan trọng hơn con số tại một điểm. Bảng tra thắng ở `W=8` nhưng
> thua tuyệt đối ở `W=16`.

## 3. Ràng buộc phạm vi — chỉ được so sánh, **không được thay**

| Kiến trúc / tính năng | Charter mục 3 xếp vào | Được làm gì |
|---|---|---|
| **Căn có phần thập phân** | **Ngoài phạm vi** | Chỉ thảo luận (§5) |
| **Căn số rộng hơn** | **Ngoài phạm vi** ở mức bắt buộc | Module có `INPUT_W`, mở rộng là tự nguyện |
| **CORDIC** | **Ngoài phạm vi** — đó là đề I05 | Chỉ so sánh trên giấy (cột E) |
| Thiết kế analog mức transistor | Ngoài phạm vi (mọi đề) | Không |
| Tự làm physical design, ASIC sign-off, tape-out | Ngoài phạm vi (mọi đề) | Không tự sửa netlist |
| Chạy LibreLane + sky130A | **Mở rộng, tự nguyện** | Được làm, không phải điều kiện đạt |

## 4. Đánh đổi bên trong kiến trúc đã chọn

### Đánh đổi #1 — `x_reg` dịch trái 2 so với mux chọn cặp bit

```systemverilog
next_pair = x_reg[INPUT_W-1 -: 2];    // luôn lấy 2 bit cao nhất
x_reg    <= x_reg << 2;                // rồi dịch x_reg
```

| Phương án | FF | Cell tổ hợp | Nhận xét |
|---|---:|---|---|
| **Dịch `x_reg`** (đang dùng) | **8** | mux nạp/dịch 8 bit | Đơn giản, `next_pair` luôn ở vị trí cố định |
| Giữ `x` cố định + mux chọn theo `iter` | **0** (nếu tầng ngoài giữ `x`) hoặc 8 | 1 mux 4:1 rộng 2 bit | Tiết kiệm tới **8 FF**, nhưng buộc tầng ngoài giữ `x` ổn định suốt 6 chu kỳ |

Phương án 2 tiết kiệm tới 8 FF — đáng kể khi Charter mục 10 chỉ cho ngân sách **18–22**
ô nhớ. Nhưng nó **đổi hợp đồng giao diện**: `x` phải ổn định suốt phép tính thay vì chỉ
tại cạnh `start`. Đây là đánh đổi **diện tích ↔ ràng buộc giao diện**, phải hỏi giảng
viên.

### Đánh đổi #2 — `REM_W = INPUT_W + 1` rộng hơn cần thiết

```systemverilog
localparam int REM_W = INPUT_W + 1;     // = 9
```

Từ INV-6 (`rem ≤ 2·root`): với `root ≤ 15` thì `rem ≤ 30`, nên
`rem_shift = 4·rem + 3 ≤ 123` → **7 bit là đủ**. Công thức chặt là
`REM_W = INPUT_W/2 + 3`.

| | `REM_W = 9` (đang dùng) | `REM_W = 7` (chặt) |
|---|---:|---:|
| FF cho `rem_reg` | 9 | **7** |
| Bề rộng bộ so sánh–trừ | 9 bit | **7 bit** |
| Tiết kiệm | — | **2 FF + ~6–8 cell tổ hợp** |
| Rủi ro | Không | Phải chứng minh INV-6 trước, nếu sai thì tràn âm thầm |

**Dư bit là lựa chọn an toàn**, và tổng hợp thường tự thu hồi bit chết (đề I01 đã cho
thấy: `rem_reg[4]` bị xoá, `34 → 33 FF`). Nhưng ở đây tổng hợp **không** thu hồi được vì
cả `rem_reg` đã chết vì lý do khác.

⬜ **Không kiểm chứng được** cho tới khi vá lỗi driver.

### Đánh đổi #3 — `ITER_W = $clog2(ROOT_W+1)` thay vì `$clog2(ROOT_W)`

`ITER_W = $clog2(5) = 3` bit cho dải đếm 0…3 — **dư 1 bit** (2 bit là đủ).
Cách viết `+1` là mẫu phòng thủ chuẩn (bảo đảm đếm được tới `ROOT_W`), đổi 1 FF lấy sự
an toàn khi tham số hoá. Netlist xác nhận: `iter[0..2]` = 3 FF.

### Đánh đổi #4 — không đưa phần dư ra ngoài

`rem_reg` là tín hiệu **nội bộ**, không có cổng ra. So với đề I01 vốn **có** `remainder`:

| | I02 (không đưa ra) | Nếu thêm `rem_zero` (1 bit) |
|---|---|---|
| Chân cần thêm | 0 | 1 (còn dư 10 chân — `interface.md` §3) |
| Cell thêm | 0 | 1 cổng NOR rộng + 1 FF |
| Tầng ngoài biết được gì | Chỉ `root` | Biết `x` có phải **số chính phương** hay không |
| Làm tròn được không | ❌ | 🟡 một phần (biết `rem=0` thì chắc chắn không cần làm tròn) |

Với bối cảnh đo gia tốc (`√(aₓ²+a_y²)`), việc biết kết quả có bị cắt hay không **có giá
trị thật** — nó cho biết sai số lượng tử. Đề xuất, cần giảng viên duyệt.

## 5. Căn nguyên so với căn có phần thập phân (thảo luận — **ngoài phạm vi**)

Charter mục 3 xếp “căn có phần thập phân” vào ngoài phạm vi. So sánh trên giấy:

| | Căn nguyên (đang làm) | Căn có `F` bit thập phân |
|---|---|---|
| Số bước | `W/2` = 4 | `(W + 2F)/2` = `4 + F` |
| Thay đổi thuật toán | — | **Không đổi gì** — chỉ cần nạp thêm các cặp `00` vào sau khi hết bit của `x` |
| Bề rộng `root_reg` | `W/2` = 4 | `W/2 + F` |
| Bề rộng `rem_reg` | `W+1` | `W + 2F + 1` |

> 🔎 **Điểm đẹp của thuật toán từng bit:** mở rộng sang phần thập phân **không cần sửa
> lõi** — chỉ cần chạy thêm `F` bước và nạp cặp `00`. Đây là ưu thế mà Newton–Raphson và
> bảng tra không có. Đáng nêu khi bảo vệ dù không được hiện thực.

## 6. Số liệu theo README tham chiếu

| Chỉ số | I02 được ghi nhận | Charter dự báo | Ghi chú |
|---|---:|---|---|
| Số cell | 118 | ~230–330 cell | Số liệu tham chiếu; raw report chưa có |
| Flip-flop | 26 | > 0 | Số liệu tham chiếu; raw report chưa có |
| Diện tích | 1122,3264 µm² | 1×1 tile | Số liệu tham chiếu |
| Data arrival | 2,86 ns | — | STA theo giả định trong SDC |
| Slack | — | — | Raw report chưa có trong checkout |
| Công suất | 1.75e-04 W (ước lượng) | — | Số liệu tham chiếu |

### So sánh cấu trúc

| | **I01** (chia 8÷4) | **I02 trước vá (lịch sử)** | **I02 theo README tham chiếu** |
|---|---:|---:|---:|
| Số cell | **148** | 26 | **118** |
| Flip-flop | **33** | 7 | **26** |
| Cell `xor`/`xnor` | **7** | **0** | Raw report chưa có |
| Diện tích (µm²) | **1387,58** | 241,48 | **1122,3264** |
| Bước lặp | 8 | 4 | 4 |
| Bề rộng chuỗi mượn | 5 bit | 9 bit | 9 bit |
| Độ trễ | **1,24 ns** | 1,46 ns (trước vá) | **2,86 ns** theo README tham chiếu |

> Các số lịch sử trước vá được giữ lại để giải thích nguyên nhân lỗi. Số hiện tại là số
> tham chiếu từ README; xem [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md)
> để biết giới hạn raw reports chưa có.

## 7. Những đánh đổi **KHÔNG được phép** trong đề này

| Việc | Vì sao cấm |
|---|---|
| Đổi sang **thử dần** cho dễ | Charter mục 10 nêu thẳng — số chu kỳ phụ thuộc dữ liệu |
| Đổi sang **CORDIC** | Charter mục 3: **ngoài phạm vi** — đó là đề I05 |
| Đổi sang **bảng tra** | Không còn là “theo từng bit”; và không mở rộng được (tăng trưởng mũ) |
| Thêm **phần thập phân** | Charter mục 3: **ngoài phạm vi** |
| Dùng hàm `$sqrt` của ngôn ngữ | Không tổng hợp được, và xoá sạch nội dung dạy học |
| Xoá cổng `busy` để khớp đúng ánh xạ Charter mục 4 | Ánh xạ hiện dùng 14/24 chân, **còn dư 10** — không có áp lực phải xoá. Nhưng nếu muốn xoá thì phải hỏi giảng viên |
| Tự sửa netlist bằng tay để “phục hồi” `root` | Charter mục 3: physical design là ngoài phạm vi. Và sửa netlist không sửa được lỗi nguồn |
| Công bố số liệu vật lý mà không nêu công cụ, giả định và trạng thái raw reports | Sai phạm vi bằng chứng; cần kèm các điều kiện trong `physical_report.md` |

## 8. Đánh đổi mà hồ sơ này **đã mắc phải** mà không cố ý

| Đánh đổi vô tình | Cái được | Cái mất |
|---|---|---|
| `root` vừa `assign` từ `root_reg` vừa gán `'0` trong reset | Nhìn qua có vẻ “reset cho chắc” | 🔴 **Xung đột driver** → Yosys nối cổng ra về hằng 0 → **74 % thiết kế biến mất** |
| Bỏ qua 4 dòng `Warning: Driver-driver conflict` trong `yosys.log` | Tổng hợp “PASS” | Lỗi lọt xuống tận STA và báo cáo công suất |
| Chưa chạy mô phỏng gate-level (`L4-GATE = CHUA CHAY`) | Tiết kiệm thời gian | Mất **hàng rào cuối cùng** — một ca gate-level với `x=4` sẽ phát hiện ngay |
| Testbench thiếu `x=99`, `x=100` | Ít ca hơn, chạy nhanh hơn | Thiếu **2/5 ca bắt buộc** Charter mục 8, và mất lớp ca “mẫu `root` xen kẽ” |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
