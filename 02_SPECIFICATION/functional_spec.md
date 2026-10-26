# I02 · Đặc tả chức năng (Functional Specification)

---

> ## Trạng thái kiểm chứng
>
> Lỗi driver kép D-1 đã được vá trong `04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv` bằng
> cách bỏ phép gán `root <= '0;` dư thừa trong nhánh reset. Icarus Verilog 12.0 mô phỏng
> testbench thành công; testbench kiểm tra 4 chu kỳ `busy` và các ca Charter bắt buộc.
> Mô hình chuẩn Python cũng PASS. Chẩn đoán trước vá được lưu trong
> [`../05_VERIFICATION/known_issues.md`](../05_VERIFICATION/known_issues.md).
>
> Các số liệu 118 cell, 26 FF, 1122,3264 µm², 2,86 ns và 1.75e-04 W được ghi nhận trong
> README tham chiếu; raw reports chưa có trong checkout. Xem
> [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md) để biết giới hạn.

---

## 1. Bài toán

Tính **căn bậc hai nguyên** của một số 8 bit:

```
   root = ⌊√x⌋        tức là   root² ≤ x < (root+1)²
```

Với `x ∈ [0, 255]`, kết quả `root ∈ [0, 15]` — vừa **4 bit**, đúng một nửa độ rộng đầu
vào. Đây không phải trùng hợp: `√(2^W − 1) < 2^(W/2)`, nên căn của số `W` bit luôn vừa
`W/2` bit.

Bối cảnh Charter mục 1: tính **độ lớn vector** từ hai thành phần trong bộ đo gia tốc —
`√(aₓ² + a_y²)`. Khối bên ngoài tính tổng bình phương, I02 lấy căn.

## 2. Thuật toán **từng bit** (digit-by-digit) — đặc tả

Thuật toán xử lý **2 bit của `x` mỗi bước** và sinh **1 bit của `root` mỗi bước**. Với
`x` 8 bit, đó là **4 bước**.

```
   root ← 0 ;  rem ← 0
   lặp i = 0 .. W/2−1 :
       pair      ← 2 bit cao nhất còn lại của x
       rem_shift ← (rem << 2) | pair          # nạp 2 bit mới vào phần dư
       trial     ← (root << 2) | 1            # = 4·root + 1
       nếu rem_shift ≥ trial :
           rem  ← rem_shift − trial ;  bit ← 1
       ngược lại :
           rem  ← rem_shift         ;  bit ← 0
       root ← (root << 1) | bit
```

### Vì sao `trial = 4·root + 1` — chứng minh cơ chế

Giả sử đã biết `root` là căn của phần `x` đã xử lý. Bước kế thêm một bit `b` vào `root`:

```
   (2·root + b)²  =  4·root²  +  4·root·b  +  b²
                  =  4·root²  +  b·(4·root + 1)        (vì b ∈ {0,1} nên b² = b)
```

Phần `4·root²` đã được trừ ở các bước trước (đó chính là ý nghĩa của `rem << 2`). Phần
còn phải trừ nếu chọn `b = 1` là **đúng `4·root + 1`** — tức `trial`.

> 📌 **Đây là toàn bộ cơ chế của thuật toán.** Nó biến phép khai căn — vốn không có công
> thức đóng — thành một chuỗi **so sánh và trừ**, đúng cùng một khuôn với phép chia. Không
> cần bộ nhân, không cần bảng tra.

Mô hình chuẩn kiểm đúng đẳng thức này: `test_trial_recurrence()` khẳng định
`row["trial"] == ((prev_root << 2) | 1)` cho mọi bước với `x = 0xa5` — PASS.

## 3. Định nghĩa chính xác từng đầu ra

| Đầu ra | Độ rộng | Định nghĩa | RTL hiện tại |
|---|---:|---|---|
| `root[3:0]` | `INPUT_W/2` = 4 | `⌊√x⌋`, hợp lệ tại chu kỳ `done=1` | ✅ `assign root = root_reg` |
| `busy` | 1 | `1` trong các chu kỳ lặp; `0` ở `S_IDLE` và `S_DONE` | ✅ |
| `done` | 1 | Xung **đúng 1 chu kỳ** báo `root` hợp lệ | ✅ |

> Charter mục 4 ánh xạ `uo_out[3:0]` = căn bậc hai, `uo_out[4]` = xong. Tổng 9 bit vào +
> 5 bit ra = 14/24 chân — **ánh xạ đã khả thi**, không phải đổi gì (`interface.md` §3).
> Cổng `busy` là dư so với ánh xạ Charter, nhưng còn thừa 10 chân nên không sao.

## 4. Ràng buộc cấu trúc bắt buộc

Tên đề chỉ định **“theo từng bit”** → RTL **bắt buộc** mô tả tường minh vòng lặp 2-bit-mỗi-bước.

| Ràng buộc | RTL có thoả? | Bằng chứng |
|---|:-:|---|
| Không dùng hàm `$sqrt` hay bảng tra | ✅ | Toàn văn RTL không có |
| Xử lý **2 bit `x` mỗi bước**, sinh **1 bit `root` mỗi bước** | ✅ | `x_reg[INPUT_W-1 -: 2]` (dòng 38), `root_reg <= (root_reg << 1) \| qbit` (dòng 83) |
| Số bước = `ROOT_W = INPUT_W/2` = **4**, **cố định** | ✅ | `if (iter == ROOT_W-1)` (dòng 86) |
| **Không** dùng thử dần (Charter mục 10 cấm) | ✅ | Điều kiện thoát chỉ phụ thuộc `iter`, không phụ thuộc dữ liệu |
| Mạch tuần tự, có thanh ghi trạng thái | ✅ | RTL có `state_t`; README tham chiếu ghi nhận 26 FF sau tổng hợp |
| Tham số hoá theo `INPUT_W` | ✅ | `parameter int INPUT_W = 8`, mọi độ rộng suy từ đó |

> Charter mục 10 cảnh báo: “Dùng vòng lặp **thử dần** cho dễ — đề cấm, vì nó cho số chu kỳ
> **thay đổi theo dữ liệu**.” RTL này **không** mắc lỗi đó: số bước cố định bằng 4 với mọi
> `x`. Đây là điểm RTL làm **đúng**.

## 5. Bảng trạng thái

| Trạng thái | Mã | Điều kiện ra | Kế tiếp | Hành động |
|---|---|---|---|---|
| `S_IDLE` | `2'b00` | `!start` | `S_IDLE` | `busy←0` |
| `S_IDLE` | | `start` | `S_ITER` | `x_reg←x`, xoá `root_reg`,`rem_reg`,`iter`; `busy←1` |
| `S_ITER` | `2'b01` | `iter != ROOT_W-1` | `S_ITER` | `rem_reg←rem_next`, `root_reg←(root_reg<<1)\|qbit`, `x_reg←x_reg<<2`, `iter←iter+1` |
| `S_ITER` | | `iter == ROOT_W-1` | `S_DONE` | ba phép gán trên **vẫn thực hiện**; `busy←0` |
| `S_DONE` | `2'b10` | — | `S_IDLE` | `done←1`, `busy←0` |
| `default` (`2'b11`) | | — | `S_IDLE` | `busy←0` |

`state_t` chỉ có **3** giá trị nhưng mã hoá **2 bit** → mã `2'b11` **không dùng**, được
nhánh `default` bắt về `S_IDLE`. Đây là phòng thủ đúng.

## 6. Trạng thái sau reset và độ trễ

| Mục | Giá trị | Bằng chứng |
|---|---|---|
| Loại reset | **Đồng bộ**, tích cực thấp | `if (!rst_n)` nằm trong `always_ff` (dòng 53–54) |
| Sau reset | `state=S_IDLE`, mọi thanh ghi `=0`, `busy=done=0` | dòng 54–62 |
| Lấy mẫu `start` | Chỉ ở `S_IDLE`; trong lúc `busy`, `start` bị bỏ qua | `case` chỉ kiểm `start` ở `S_IDLE` |

### Độ trễ — đếm theo cạnh clock

Gọi cạnh clock lấy mẫu `start=1` là **cạnh 1**:

| Cạnh | Trạng thái trước cạnh | Việc xảy ra |
|---:|---|---|
| 1 | `S_IDLE` | Nạp `x_reg ← x`, xoá `root_reg`/`rem_reg`/`iter`, `state ← S_ITER`, `busy ← 1` |
| 2 | `S_ITER` (`iter=0`) | Bước lặp **1** (bit cao nhất của `root`), `iter ← 1` |
| 3 | `S_ITER` (`iter=1`) | Bước lặp **2**, `iter ← 2` |
| 4 | `S_ITER` (`iter=2`) | Bước lặp **3**, `iter ← 3` |
| 5 | `S_ITER` (`iter=3`) | Bước lặp **4** (`iter == ROOT_W−1`), `busy ← 0`, `state ← S_DONE` |
| 6 | `S_DONE` | `done ← 1`, `state ← S_IDLE` |

| Đại lượng | Giá trị |
|---|---:|
| **Số bước lặp** | **4** |
| **Độ trễ tổng (`start` → `done=1`)** | **6 chu kỳ** |
| `busy` giữ mức 1 | **4 chu kỳ** |
| Thông lượng tối đa | 1 kết quả / 6 chu kỳ |

> ### ⚠️ Phân biệt “**4 bước lặp**” với “**4 chu kỳ**”
>
> Charter mục 2 và mục 9 đều viết “thuật toán chạy **đúng 4 chu kỳ**”. Chính xác hơn:
> **4 bước lặp**, nhưng **6 chu kỳ** tổng độ trễ (1 nạp + 4 lặp + 1 phát `done`). Hai con
> số khác nhau và phải nói rõ con số nào khi báo cáo. Nhầm lẫn giữa chúng là một trong
> những sai sót hay gặp nhất khi trả lời Charter mục 9.

## 7. Tính chất bất biến (invariants)

| # | Phát biểu | Trạng thái kiểm |
|---|---|---|
| **INV-1** | **Định nghĩa căn nguyên**: `root² ≤ x < (root+1)²` | ✅ Mô hình chuẩn `test_full_domain()` quét **cả 256 giá trị** — PASS |
| **INV-2** | `root == math.isqrt(x)` với mọi `x` | ✅ `test_random()` — 10 000 ca, seed 2026 — PASS |
| **INV-3** | **Số bước cố định** = 4 với mọi `x` | ✅ `test_cycle_count()`, `assert len(tr)==4` — PASS |
| **INV-4** | **Đẳng thức thử**: `trial_i == 4·root_{i−1} + 1` ở mọi bước | ✅ `test_trial_recurrence()` — PASS |
| **INV-5** | **Đẳng thức phần dư**: `x = root² + rem` khi kết thúc | ⬜ chưa có test tường minh; suy được từ INV-1 |
| **INV-6** | **Chặn phần dư**: `rem ≤ 2·root` ở mọi bước (vì `rem < (root+1)² − root² = 2·root+1`) | ⬜ chưa có assertion — dùng để tính độ rộng `rem_reg` tối ưu, xem §10 |
| **INV-7** | `done` là xung 1 chu kỳ: `done \|=> !done` | ⬜ SVA được bảo vệ bởi macro `I02_SVA`; chưa chạy trong flow Icarus |
| **INV-8** | Không có `X` ở đầu ra | ⬜ SVA được bảo vệ bởi macro `I02_SVA`; chưa chạy trong flow Icarus |
| **INV-9** | `busy` và `done` không đồng thời bằng 1 | ⬜ chưa có — suy từ bảng §5 là đúng |
| **INV-10** | Bit cao nhất của `root` được sinh ở bước **1**, bit thấp nhất ở bước **4** | ⬜ chưa có — hệ quả của `root_reg <= (root_reg << 1) \| qbit` |

> **INV-1…INV-4 được chứng minh trên toàn miền ở mức Python.** RTL được mô phỏng với các
> ca trong testbench; chưa có kiểm chứng RTL vét cạn toàn miền.

## 8. Điều kiện biên và hành vi không xác định

| Tình huống | Hành vi đặc tả | RTL (nếu vá CT-1) | Ca TB? |
|---|---|---|:-:|
| `x = 0` | `root = 0`, `rem = 0` | ✅ mọi `qbit = 0` | ✅ |
| `x = 1` | `root = 1` | ✅ bước 4 cho `qbit=1` | ✅ |
| `x = 255` | `root = 15`, `rem = 30` — **giá trị lớn nhất** | ✅ mọi `qbit = 1` | ✅ |
| `x = 100` | `root = 10` | ✅ | ✅ ca Charter mục 8 |
| `x = 99` | `root = 9` | ✅ | ✅ ca Charter mục 8 |
| Số chính phương (`x = k²`) | `root = k`, `rem = 0` | ✅ | 🟡 có `0,1,4,9,16,64` |
| Ngay dưới số chính phương (`x = k²−1`) | `root = k−1` | ✅ | 🟡 có `3, 15, 63` |
| Ngay trên số chính phương (`x = k²+1`) | `root = k` | ✅ | 🟡 có `2, 65` |
| `start` bật lúc `busy` | Bỏ qua | ✅ | ⬜ chưa có |
| Đọc `root` khi chưa `done` | **Không xác định** — kết quả dở dang | Tầng ngoài phải đợi `done` | — |
| `x` đổi giữa chừng | Không ảnh hưởng — đã chốt vào `x_reg` | ✅ đây là lý do `x_reg` tồn tại | ⬜ chưa có |
| `INPUT_W` lẻ | **Không hợp lệ** — `ROOT_W = INPUT_W/2` sẽ cắt cụt và thuật toán 2-bit-mỗi-bước không còn đúng | ❌ RTL **không có** kiểm tra | — |

> Ràng buộc `INPUT_W` **phải chẵn** chưa được ghi ở đâu trong mã. Nên thêm:
> `initial assert (INPUT_W % 2 == 0);` hoặc một `$fatal` trong `generate`.

## 9. Hợp đồng với tầng ngoài

1. Giữ `x` ổn định **tại cạnh clock lấy mẫu `start`**; sau đó được phép đổi tuỳ ý.
2. Phát `start` **đúng 1 chu kỳ**.
3. Chốt `root` **tại chu kỳ `done=1`**.
4. Giữ `rst_n=0` qua **ít nhất 1 cạnh `clk`** — reset là **đồng bộ**.
5. Khối **không có back-pressure**: không có `ready` đi vào.
6. Tầng ngoài **không nhận được phần dư**: `rem_reg` là tín hiệu nội bộ, không có cổng ra.
   Nếu cần biết `x` có phải số chính phương hay không, phải đưa thêm cổng `rem_zero` — xem
   `tradeoff.md`.

## 10. Chi tiết độ rộng — `rem_reg` rộng hơn cần thiết

```systemverilog
localparam int REM_W = INPUT_W + 1;     // = 9 với INPUT_W = 8
```

Từ INV-6, `rem ≤ 2·root ≤ 30`, nên `rem_shift = 4·rem + 3 ≤ 123` → **7 bit là đủ**.
`REM_W = 9` dư **2 bit**.

Đây **không phải lỗi** (dư bit là an toàn, và tổng hợp sẽ thu hồi bit chết như đã thấy ở
đề I01). Nhưng nó là một điểm để bàn khi bảo vệ: công thức đúng theo INV-6 là
`REM_W = INPUT_W/2 + 3` chứ không phải `INPUT_W + 1`.

> RTL mô phỏng PASS, nhưng raw netlist chưa có trong checkout để xác minh tổng hợp có thu
> hồi các bit thừa hay không.

## 11. Truy vết Charter

| Mục Charter | Đáp ứng |
|---|---|
| Mục 1 (bối cảnh) | §1 |
| Mục 2 câu 1 (đúng 4 chu kỳ — kiểm chứng trên waveform?) | §6 + `timing_diagram.md`. ⚠️ **4 bước lặp, 6 chu kỳ tổng** |
| Mục 2 câu 2 (mở rộng 16 bit: chu kỳ và diện tích tăng theo quy luật nào) | `implementation-notes_I02.md` §8 |
| Mục 2 câu 3 (từng bit khác thử dần ở chỗ nào) | §4 + `tradeoff.md` §2 |
| Mục 4 (giao diện) | §3 — giao diện RTL và bảng chân trong `interface.md` |
| Mục 8 (ca kiểm thử) | `corner_cases.md` — đủ 5 ca bắt buộc; testbench PASS |
| Mục 9 (phân tích riêng) | `implementation-notes_I02.md` §8 — mô hình kiểm tra thuật toán 16-bit; chưa tổng hợp RTL 16-bit |
| Mục 10 (dấu hiệu làm đúng) | README tham chiếu ghi nhận 26 FF; raw synthesis report chưa có trong checkout |

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
