# I02 — Bộ tính căn bậc hai nguyên 8-bit theo từng bit · Ghi chú thực hiện

> **Cập nhật trạng thái 2026-10-26:** Lỗi D-1 đã được vá; mô hình Python và mô phỏng RTL
> PASS. Physical flow đã hoàn tất, sinh GDS, DRC/LVS không có lỗi theo metrics của lần
> chạy. Tài liệu bên dưới giữ lại phân tích sự cố **trước khi vá** để phục vụ đối chiếu;
> các bảng/nhận định mô tả trạng thái trước vá không phải trạng thái hiện tại. Xem
> [`05_VERIFICATION/verification_report.md`](05_VERIFICATION/verification_report.md) và
> [`06_GDSII/physical_report.md`](06_GDSII/physical_report.md) để biết bằng chứng hiện tại.

---

## 1. Bài toán này thực chất là gì

Bề ngoài, I02 là “bộ tính căn bậc hai”. Thực chất, nó là bài học về **cách biến một phép
toán không có công thức đóng thành một chuỗi so sánh và trừ** — và, một cách không cố ý,
nó đã trở thành bài học đắt giá nhất trong cả gói về **cách một chuỗi công cụ có thể báo
toàn dấu ✅ trong khi sản phẩm hoàn toàn rỗng**.

Bài toán: cho `x ∈ [0, 255]`, tìm `root` sao cho `root² ≤ x < (root+1)²`. Kết quả nằm
trong `[0, 15]` — vừa **4 bit**, đúng một nửa độ rộng đầu vào. Đây không phải trùng hợp:
`√(2^W − 1) < 2^(W/2)`, nên căn của số `W` bit luôn vừa `W/2` bit.

Bối cảnh Charter mục 1: tính **độ lớn vector** từ hai thành phần gia tốc — `√(aₓ² + a_y²)`.
Khối bên ngoài tính tổng bình phương, I02 lấy căn. Về mặt toán học, so ngưỡng trên
`aₓ²+a_y²` tương đương so trên `|a|` (hàm căn đơn điệu tăng) — nhưng `|a|` là đại lượng
**có đơn vị vật lý**, đọc được và đặt ngưỡng tuyến tính được. Đó là lý do bước lấy căn
được đưa vào phần cứng.

## 2. Bản chất kỹ thuật — cơ chế hoạt động

### 2.1 Vì sao `trial = 4·root + 1` — đây là toàn bộ thuật toán

Giả sử đã biết `root` là căn của phần `x` đã xử lý. Bước kế thêm một bit `b` vào `root`:

```
   (2·root + b)²  =  4·root²  +  4·root·b  +  b²
                  =  4·root²  +  b·(4·root + 1)        (vì b ∈ {0,1} nên b² = b)
```

Phần `4·root²` **đã được trừ ở các bước trước** — đó chính là ý nghĩa của phép
`rem << 2`. Phần còn phải trừ nếu chọn `b = 1` là đúng **`4·root + 1`**.

> 📌 **Đây là cơ chế, không chỉ là chức năng.** Phép khai căn — vốn không có công thức
> đóng trong số nguyên — được biến thành một chuỗi **so sánh và trừ** giống hệt phép
> chia. Không cần bộ nhân, không cần bảng tra, không cần phép chia.
>
> Và chú ý một chi tiết đẹp: `4·root + 1 = (root << 2) | 1`. Cả hai phép đều **miễn phí**
> trong phần cứng — dịch là dây nối, ghép bit `1` vào vị trí thấp nhất cũng là dây nối.
> **Không một cổng logic nào được dùng để tính `trial`.**

Mô hình chuẩn kiểm đúng đẳng thức này: `test_trial_recurrence()` khẳng định
`row["trial"] == ((prev_root << 2) | 1)` ở mọi bước — PASS.

### 2.2 Vì sao tiêu thụ **2 bit** mỗi bước

Mỗi bit thêm vào `root` làm `root²` tăng theo bậc 4 (vì `(2r)² = 4r²`). Để cân bằng,
phần dư phải được dịch **2 bit** mỗi bước và nạp **2 bit** mới của `x`. Đó là lý do:

- `rem_shift = (rem << 2) | pair` — dịch **2**.
- `root_reg <= (root_reg << 1) | qbit` — dịch **1**.
- Số bước = `W/2`, không phải `W`.

Hệ quả: với `W = 8` cần **4 bước**, một nửa số bước của bộ chia I01 (8 bước) — nhưng
chuỗi mượn rộng **9 bit** thay vì 5 bit. **Ít chu kỳ hơn, mỗi chu kỳ nặng hơn.**

### 2.3 Phụ thuộc nối tiếp — chặt hơn cả phép chia

```
 chu kỳ 2    rem₁, root₁ = f(rem₀, root₀, x[7:6])
 chu kỳ 3    rem₂, root₂ = f(rem₁, root₁, x[5:4])   ◀── cần CẢ rem₁ LẪN root₁
 chu kỳ 4    rem₃, root₃ = f(rem₂, root₂, x[3:2])
 chu kỳ 5    rem₄, root₄ = f(rem₃, root₃, x[1:0])
```

Ở bộ chia, số bị trừ (`divisor`) là **hằng số** suốt 8 bước. Ở bộ khai căn, số bị trừ
(`trial = 4·root + 1`) **thay đổi mỗi bước và phụ thuộc kết quả các bước trước**.

> 🔎 **Đây mới là nút thắt thật sự**, không phải bộ trừ. Không có cách nào tính trước
> `trial₃` mà chưa biết `root₂`. Vì vậy khai căn **không thể song song hoá** theo bất kỳ
> cách nào tương tự cây Wallace của phép nhân — không chỉ vì phần dư nối tiếp (như phép
> chia), mà còn vì **toán hạng thứ hai cũng nối tiếp**.

### 2.4 Chặn phần dư — chứng minh

Bất biến: `rem ≤ 2·root` ở mọi bước.

```
   rem < (root+1)² − root² = 2·root + 1    ⟹   rem ≤ 2·root
```

Với `root ≤ 15` → `rem ≤ 30`, nên `rem_shift = 4·rem + 3 ≤ 123` → **7 bit là đủ**.
RTL khai `REM_W = INPUT_W + 1 = 9` — dư 2 bit. Không sai, nhưng công thức chặt là
`REM_W = INPUT_W/2 + 3`.

Ca `x = 255` chạm **sát biên**: `rem = 30 = 2 × 15`. Đó là lý do ca này là ca biên đúng
nghĩa.

## 3. Đọc mã nguồn: RTL làm gì, từng dòng quan trọng

### 3.1 Trái tim thuật toán — khối `always_comb` (dòng 37–49)

```systemverilog
always_comb begin
    next_pair = x_reg[INPUT_W-1 -: 2];      // ① 2 bit cao nhất còn lại
    rem_shift = (rem_reg << 2) | next_pair; // ② nạp 2 bit mới vào phần dư
    trial     = (root_reg << 2) | 1'b1;     // ③ = 4·root + 1

    if (rem_shift >= trial) begin
        rem_next = rem_shift - trial;
        qbit     = 1'b1;
    end else begin
        rem_next = rem_shift;
        qbit     = 1'b0;
    end
end
```

Bốn điều đáng chú ý:

1. **`x_reg[INPUT_W-1 -: 2]`** — cú pháp chọn khoảng có bề rộng cố định, đọc là “2 bit
   tính từ `INPUT_W-1` đi xuống”. Ưu điểm so với `x_reg[7:6]`: **tham số hoá được**. Đây
   cũng là dòng gây cảnh báo `sorry: constant selects` của Icarus — **vô hại**, xem §6.
2. **`>=` chứ không phải `>`** — đây là ranh giới quyết định. Ca `x = 100` rơi vào
   `rem_shift == trial` tại **hai** bước; nếu viết `>` thì `√100` ra **8** thay vì **10**.
3. **`always_comb`, không phải `always_ff`** — thuần tổ hợp, sinh ra bộ so sánh–trừ 9 bit
   dùng chung cho cả 4 bước.
4. Ba dòng ①②③ **không sinh cổng logic nào** — chúng chỉ là cách nối dây.

### 3.2 Bước lặp và điều kiện thoát (dòng 79–92)

```systemverilog
S_ITER: begin
    busy <= 1'b1;

    rem_reg  <= rem_next;                    // ①
    root_reg <= (root_reg << 1) | qbit;      // ②
    x_reg    <= x_reg << 2;                  // ③

    if (iter == ROOT_W-1) begin
        busy  <= 1'b0;
        state <= S_DONE;
    end else begin
        iter <= iter + 1'b1;
    end
end
```

Ba phép gán ①②③ nằm **trước** câu `if`, nên chúng thực hiện ở **cả 4** lần. Nếu ai đó
“dọn dẹp” bằng cách đưa chúng vào nhánh `else`, `root` sẽ thiếu đúng **1 bit** — `√255`
ra `7` thay vì `15`. Cùng một cái bẫy off-by-one với đề I01.

Điều kiện thoát `iter == ROOT_W-1` dùng **localparam**, không dùng hằng số cứng — module
vẫn đúng khi đổi `INPUT_W`.

### 3.3 🔴 Dòng gây sụp đổ toàn bộ thiết kế (dòng 51 và 59)

```systemverilog
    assign root = root_reg;              // dòng 51 — DRIVER 1 (liên tục)
    ...
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_reg    <= '0;
            root_reg <= '0;              // dòng 57 — đã xoá thanh ghi rồi
            rem_reg  <= '0;
            iter     <= '0;
            root     <= '0;              // dòng 59 — DRIVER 2 (thủ tục) ← LỖI
```

`root` có **hai driver**, điều mà SystemVerilog không cho phép. Và dòng 59 **hoàn toàn
thừa**: `root` chỉ là dây nối từ `root_reg`, mà `root_reg` đã bị xoá ở dòng 57.

**Hậu quả — hiệu ứng domino từ một dòng:**

| Bước | Hệ quả | Thiệt hại |
|---|---|---|
| Icarus | `error: root Unable to assign to unresolved wires.` | **COMPILE_FAIL** |
| Yosys | `Warning: Driver-driver conflict ... Resolved using constant.` | `assign root = 4'h0;` |
| → | `root_reg` không còn ai đọc | **−4 FF** |
| → | `trial` (phụ thuộc `root_reg`) chết → bộ so sánh–trừ chết | **−~30 cell** |
| → | `qbit`, `rem_next` không còn ai tạo → `rem_reg` chết | **−9 FF** |
| → | `rem_shift`, `next_pair` chết → `x_reg` chết | **−8 FF** |
| → | **Cổng vào `x[7:0]` có 0 tham chiếu trong netlist** | 🔴 |

**Từ 27 bit thanh ghi khai báo còn lại 7. Từ một dòng mã.**

Phán xử đầy đủ và bản vá **xoá một dòng** ở `05_VERIFICATION/known_issues.md`.

## 4. Vì sao chọn kiến trúc này

Bốn lý do, xếp theo sức nặng:

1. **Tên đề khoá kiến trúc.** “Theo từng bit” là ràng buộc bắt buộc. Dùng `$sqrt` hay
   bảng tra sẽ xoá sạch nội dung dạy học.
2. **Charter mục 10 cấm thẳng “thử dần”**: số chu kỳ 1…16 phụ thuộc dữ liệu, và còn cần
   một **bộ nhân** để tính `(k+1)²` — đắt hơn hẳn bộ so sánh–trừ.
3. **Mở rộng tuyến tính.** Bảng tra thắng ở `W=8` (1 chu kỳ, 1024 bit ROM) nhưng
   `W=16` cần **512 kbit** — tăng trưởng **mũ**. Thuật toán từng bit tăng **tuyến tính**.
4. **Mở rộng sang phần thập phân không cần sửa lõi** — chỉ cần chạy thêm `F` bước và nạp
   cặp `00`. Newton–Raphson và bảng tra không có ưu thế này.

Bảng so sánh đầy đủ với 4 kiến trúc thay thế ở `03_ARCHITECTURE/tradeoff.md` §2.

## 5. Cách thực hiện — lộ trình 8 bước từ đặc tả tới GDSII

| # | Bước | Trạng thái I02 | Bằng chứng |
|---:|---|---|---|
| 1 | Chốt đặc tả: `root² ≤ x < (root+1)²`, độ rộng cổng, số bước = `W/2` | ✅ | `functional_spec.md` |
| 2 | Viết mô hình chuẩn Python, quét **vét cạn** 256 giá trị | ✅ **PASS** — 7 hàm test, 10 000 ca random, kiểm cả 16 bit | `python_reference_run.log` |
| 3 | Viết RTL: `always_comb` (số học) tách khỏi `always_ff` (trạng thái) | 🔴 **có mã nhưng SAI** — xung đột driver dòng 51/59 | `rtl/i02_integer_sqrt.sv` |
| 4 | Viết testbench tự kiểm, phủ đủ ca Charter mục 8 | 🟡 13 ca có assertion, **thiếu `x=100` và `x=99`** | `i02_integer_sqrt_tb.sv` |
| 5 | Mô phỏng RTL | ❌ **COMPILE_FAIL** | `iverilog_compile.log` |
| 6 | Tổng hợp, **đối chiếu FF với Charter mục 10** | 🔴 tổng hợp “PASS” nhưng **netlist rỗng**; 7 FF so với 18–22 | `synth_stat.txt`, `yosys.log` |
| 7 | STA | 🔴 “PASS” nhưng đo một bộ đếm 3 bit | `timing_report_max.txt` |
| 8 | **Mô phỏng gate-level** → physical design → GDSII | ⬜ **CHƯA CHẠY** — và đây là hàng rào đáng lẽ đã bắt được lỗi | `test_matrix.csv` L4-GATE |

> **Bước bị bỏ qua và đó là gốc rễ của việc lỗi lọt xuống tận báo cáo công suất: bước 8
> (gate-level).** Mô phỏng gate-level là bước **duy nhất** trong toàn bộ luồng có khả năng
> phát hiện logic bị tổng hợp xoá. Mô phỏng RTL không thể (nó đọc RTL, không đọc netlist);
> STA và công suất càng không thể (chúng chỉ đo cái đang có).

## 6. Số liệu thật đã đo được và cách đọc chúng

| Chỉ số | Giá trị đo | Nguồn | Dùng được? |
|---|---:|---|:-:|
| Mô hình chuẩn Python | **PASS** — 256 ca vét cạn + 10 000 random (seed 2026) + kiểm 16 bit | `python_reference_run.log` | ✅ |
| Mô phỏng RTL | **COMPILE_FAIL** | `iverilog_compile.log` | ✅ (là bằng chứng lỗi) |
| Số cell | 26 | `synth_stat.txt` | 🔴 **KHÔNG** |
| Flip-flop | 7 | `synth_stat.txt` | 🔴 **KHÔNG** |
| Diện tích | 241,4816 µm² | `synth_stat.txt` | 🔴 **KHÔNG** |
| Data arrival | 1,46 ns | `timing_report_max.txt` | 🔴 **KHÔNG** |
| Slack | 8,40 ns (MET) | `timing_report_max.txt` | 🔴 **KHÔNG** |
| WNS / TNS | 0,00 / 0,00 | `wns.txt`, `tns.txt` | 🔴 **KHÔNG** |
| Đường tới hạn | `start → _40_` (= FF `iter[1]`), 4 cell | `timing_report_max.txt` | ✅ (là bằng chứng lỗi) |
| Công suất | 3,22e-05 W — tuần tự 93,7 %, tổ hợp 6,3 % | `power_report.txt` | 🔴 **KHÔNG** |

### Những con số này **chứng minh** gì

- **Thuật toán đúng trên toàn miền ở mức mô hình.** Quét vét cạn 256 giá trị, 16 số chính
  phương, 23 giá trị biên, 10 000 ca ngẫu nhiên, và kiểm cả độ rộng 16 bit — tất cả PASS.
- **Lỗi là lỗi RTL, không phải lỗi thuật toán.** Hai sự thật này tách bạch nhau rất rõ.
- **Netlist là rỗng** — và đây là điều các con số “xấu” chứng minh:

| Bằng chứng | Con số |
|---|---|
| Cổng ra nối chết | `assign root = 4'h0;` (`netlist.v:182`) |
| Cổng vào vô dụng | `x[` xuất hiện **0 lần** |
| Thiếu FF | **7** so với 18–22 (Charter mục 10) |
| Thiếu cell số học | **0** cell `xor`/`xnor` |
| Đường tới hạn quá ngắn | logic thật **0,46 ns** so với I01 **1,24 ns** |
| Cảnh báo tổng hợp | **4** dòng `Driver-driver conflict` |

### Những con số này **KHÔNG** chứng minh gì

- **Không** chứng minh RTL đúng — mô phỏng chưa chạy một chu kỳ nào.
- **`slack 8,40 ns` không phải tin vui.** Logic thật chỉ 0,46 ns vì gần như không còn
  logic. So sánh: đề I01 (cùng họ thuật toán, cùng môi trường) có logic thật 1,24 ns với
  chuỗi mượn **hẹp hơn** (5 bit so với 9 bit). Một thiết kế có chuỗi mượn rộng gần gấp
  đôi mà đường tới hạn ngắn hơn một nửa là **mâu thuẫn không thể giải thích bằng tối ưu
  hoá thông thường**.
- **`tổ hợp 6,3 %`** không phải thành tích tiết kiệm công suất — nó là chữ ký của một mạch
  chỉ còn thanh ghi trạng thái và bộ đếm. Đối chiếu I01: **15,5 %**.
- **Không** nói được gì về tần số tối đa, diện tích thật, hay công suất thật của I02.

### Hai lớp cảnh báo — phải phân biệt

| Cảnh báo | Mức | Có hại? | Xử lý |
|---|---|:-:|---|
| `sorry: constant selects in always_* processes` (dòng 37) | Hạn chế công cụ | ❌ **Không** | **Bỏ qua.** Đề I01 có cảnh báo cùng loại (dòng 34) và mô phỏng vẫn PASS |
| `error: root Unable to assign to unresolved wires` (dòng 59) | **Lỗi ngôn ngữ** | ✅ **Chí mạng** | **Vá** — xoá dòng 59 |
| `Warning: Driver-driver conflict` (Yosys, 4 dòng) | **Cảnh báo che giấu lỗi chí mạng** | ✅ **Chí mạng** | Nên cấu hình Yosys coi loại này là **lỗi chặn** |

> 📌 Hàng thứ ba là bài học vận hành quan trọng nhất: **một `Warning` có thể nguy hiểm hơn
> một `error`**, vì `error` dừng luồng còn `Warning` để luồng chạy tiếp và sinh ra số liệu
> trông có vẻ hợp lệ.

## 7. Trả lời các câu hỏi kỹ thuật của Charter (mục 2)

### Câu 1 — “Với số 8 bit, thuật toán chạy đúng 4 chu kỳ — kiểm chứng trên waveform?”

**Cần tách hai con số:**

| Cách nói | Con số | Giải thích |
|---|---:|---|
| Số **bước lặp** | **4** | `ROOT_W = INPUT_W/2 = 4`; điều kiện thoát `iter == ROOT_W-1` |
| Số chu kỳ `busy = 1` | **4** | Trùng với số bước lặp |
| **Tổng độ trễ** `start` → `done` | **6** | 1 nạp + 4 lặp + 1 phát `done` |

Charter viết “4 chu kỳ” — đó là **số bước lặp**. Trả lời đầy đủ phải nêu cả 6.

**Kiểm chứng trên waveform: ⬜ CHƯA LÀM ĐƯỢC.** `COMPILE_FAIL` nên không có VCD.
Giản đồ suy từ mã cho `√255` và `√100` ở `03_ARCHITECTURE/timing_diagram.md` §2–3 — đã
đối chiếu khớp từng dòng với mô hình chuẩn, nhưng **không phải waveform đo được**.

> Đối chiếu: đề I01 trả lời được câu tương đương bằng bằng chứng thật — `$finish at 635`
> trong `simulation.log`, dựng lại dòng thời gian testbench cho đúng 10 chu kỳ mỗi phép.
> I02 không có `simulation.log` nên không có bằng chứng loại này.

### Câu 2 — “Mở rộng lên 16 bit thì số chu kỳ và diện tích tăng theo quy luật nào — hai quy luật đó có giống nhau không?”

Xem §8 — đây cũng là câu Charter mục 9.

### Câu 3 — “Thuật toán từng bit khác thử dần ở chỗ nào về số chu kỳ?”

| | **Từng bit** (đang dùng) | **Thử dần** |
|---|---|---|
| Số chu kỳ | **`W/2 + 2` — CỐ ĐỊNH** (6 với `W=8`) | **1…16 — PHỤ THUỘC DỮ LIỆU** |
| `x = 0` | 6 chu kỳ | ~1 chu kỳ |
| `x = 255` | 6 chu kỳ | ~16 chu kỳ |
| Tỉ lệ xấu nhất / tốt nhất | **1,0** | **~16** |
| Phần cứng cần | bộ so sánh–trừ `W+1` bit | **bộ nhân** (để tính `(k+1)²`) + bộ so sánh |
| Viết được assertion số chu kỳ? | ✅ `cyc == 6` | ❌ không có giá trị cố định |
| Ngân sách thời gian thực | ✅ tính được | ❌ phải dùng ca xấu nhất |
| Kênh biên công suất | ✅ không lộ | ❌ công suất phụ thuộc dữ liệu |

**Khác biệt cốt lõi: từng bit mua *tính dự đoán được* bằng cách luôn chạy đủ 4 bước**,
kể cả khi `x = 0` và mọi `qbit` đều bằng 0. Charter mục 10 cấm thử dần chính vì lý do này.

## 8. Trả lời câu phân tích riêng (Charter mục 9)

> “Thuật toán chạy đúng 4 chu kỳ cho số 8 bit. Kiểm chứng con số này trên waveform của
> mình, và nêu nếu mở rộng lên 16 bit thì cần bao nhiêu chu kỳ và **diện tích tăng theo
> quy luật nào**.”

### 8.1 Phần “kiểm chứng trên waveform” — **CHƯA LÀM ĐƯỢC**

Lý do: `COMPILE_FAIL`. Xem §7 câu 1. Giản đồ suy từ mã (đối chiếu khớp mô hình chuẩn)
ở `timing_diagram.md`; ca B-4 trong `corner_cases.md` là cách lấy bằng chứng sau khi vá.

### 8.2 Phần “16 bit cần bao nhiêu chu kỳ” — **trả lời được bằng cấu trúc**

| `INPUT_W` | `ROOT_W = W/2` | Bước lặp | **Tổng chu kỳ = W/2 + 2** |
|---:|---:|---:|---:|
| 8 | 4 | 4 | **6** |
| **16** | **8** | **8** | **10** |
| 32 | 16 | 16 | 18 |

**Quy luật số chu kỳ: `W/2 + 2` — tuyến tính theo `W`, hệ số 1/2.**

Mô hình chuẩn xác nhận phần thuật toán: `test_16bit_scaling()` khẳng định
`len(trace) == 8` cho `width=16` — **PASS**.

### 8.3 Phần “diện tích tăng theo quy luật nào” — **trả lời được bằng cấu trúc, KHÔNG bằng số đo**

Phân tích từng thành phần theo `W`:

| Thành phần | Bề rộng | Quy luật theo `W` |
|---|---|---|
| `x_reg` | `W` | **tuyến tính** |
| `rem_reg` | `W + 1` | **tuyến tính** |
| `root_reg` | `W/2` | **tuyến tính** |
| Bộ so sánh + trừ | `W + 1` bit | **tuyến tính** |
| `iter` | `⌈log₂(W/2 + 1)⌉` | **logarit** — bỏ qua được |
| `state` | 2 bit | **hằng số** |
| **Tổng** | | **`O(W)` — TUYẾN TÍNH** |

Ước tính cụ thể (số FF):

| `INPUT_W` | `x_reg` | `rem_reg` | `root_reg` | `iter` | `state`+cờ | **Tổng FF** |
|---:|---:|---:|---:|---:|---:|---:|
| 8 | 8 | 9 | 4 | 3 | 4 | **28** |
| **16** | 16 | 17 | 8 | 4 | 4 | **49** |
| 32 | 32 | 33 | 16 | 5 | 4 | **90** |

Tỉ lệ `49/28 ≈ 1,75` khi `W` gấp đôi — gần 2 nhưng nhỏ hơn, vì `iter` và `state` tăng
chậm hơn tuyến tính.

### 8.4 “Hai quy luật đó có giống nhau không?” — **CÓ, cùng bậc `O(W)`**

| Đại lượng | Quy luật | Bậc |
|---|---|---|
| Số chu kỳ | `W/2 + 2` | **`O(W)`** |
| Diện tích | `≈ 2,5·W + hằng` | **`O(W)`** |
| **Tích diện tích × thời gian** | `≈ 1,25·W² + …` | **`O(W²)`** |

**Đáp: hai quy luật giống nhau về bậc** — cả hai tuyến tính theo `W`. Đây là tính chất
làm cho thuật toán từng bit “cân bằng”: không có đại lượng nào bùng nổ so với đại lượng
kia. Đối chiếu bảng tra: chu kỳ là `O(1)` nhưng diện tích là `O(2^W)` — **hai quy luật
hoàn toàn khác bậc**, và đó là lý do bảng tra sụp đổ khi `W` tăng.

**Một sắc thái không được bỏ qua:** bộ so sánh–trừ rộng `W+1` bit có **chuỗi mượn dài
hơn** khi `W` tăng, nên **chu kỳ clock tối thiểu cũng phải dài ra** — khoảng `O(log W)`
nếu công cụ tổng hợp dùng carry-lookahead, `O(W)` nếu ripple. Vậy **thời gian thật**
(số chu kỳ × chu kỳ clock) tăng **nhanh hơn `O(W)` một chút**, không hoàn toàn tuyến tính.

### 8.5 🔴 Giới hạn bắt buộc phải nêu

> **Toàn bộ §8.3 và §8.4 là phân tích CẤU TRÚC, không phải số đo.**
>
> Netlist hiện tại có **7 FF** chứ không phải 28, và **không chứa** `x_reg`, `rem_reg`,
> `root_reg` hay bộ so sánh–trừ nào. Vì vậy:
>
> - **Không thể** dùng con số 241,4816 µm² làm mốc để ngoại suy sang 16 bit.
> - **Không thể** khẳng định quy luật tuyến tính bằng bằng chứng đo được của chính đề này.
> - Bằng chứng duy nhất hiện có cho phần “16 bit” là ở **mức thuật toán**
>   (`test_16bit_scaling()` — PASS), không phải mức phần cứng.
>
> Muốn có số thật: vá theo `known_issues.md`, tổng hợp lại với `INPUT_W = 8` và
> `INPUT_W = 16`, rồi so hai kết quả. Đó là một thí nghiệm rẻ và rất đáng làm.

## 9. Những chỗ sinh viên hay sai và cách phát hiện

| # | Sai lầm | Hậu quả | **Phát hiện bằng bằng chứng nào** |
|---:|---|---|---|
| 1 | Gán cổng ra vừa bằng `assign` vừa bằng `<=` trong `always_ff` | 🔴 **Xung đột driver** → cổng ra bị nối chết → cả datapath biến mất | Icarus: `error: ... Unable to assign to unresolved wires`. Yosys: `grep "Driver-driver" yosys.log` |
| 2 | Bỏ qua `Warning` của công cụ tổng hợp | Lỗi lọt xuống tận STA và báo cáo công suất, kèm số liệu trông hợp lệ | Đọc **toàn bộ** `yosys.log`, không chỉ đọc `synth_stat.txt` |
| 3 | Không kiểm netlist sau tổng hợp | Không biết logic đã bị xoá | `grep "assign" netlist.v` → tìm thấy `assign root = 4'h0;`. **Đây là kỹ thuật chẩn đoán nhanh nhất** |
| 4 | Không đối chiếu số FF với dự báo | Thiếu 11–15 FF mà không biết | So `synth_stat.txt` (7) với Charter mục 10 (18–22). Chênh > 20 % là phải điều tra |
| 5 | Không kiểm cổng vào có được dùng không | Đầu vào bị cô lập | Đếm tham chiếu tới tên cổng trong netlist. `x`: **0 lần** |
| 6 | Bỏ qua mô phỏng gate-level | Mất hàng rào cuối cùng | `test_matrix.csv` L4-GATE = `CHUA CHAY`. Một ca `x=4` sẽ ra `root=0` và phát hiện ngay |
| 7 | Dùng `>` thay vì `>=` trong so sánh | `√100` ra **8** thay vì **10**; `√1` ra 0 | Ca `x=100` và `x=1` — **cả hai rơi vào `rem_shift == trial`** |
| 8 | Đặt ba phép gán datapath vào nhánh `else` của `if (iter==ROOT_W-1)` | Thiếu 1 bit `root`; `√255` ra **7** | Ca `x=255` |
| 9 | Dùng **thử dần** cho dễ | Số chu kỳ 1…16 phụ thuộc dữ liệu; cần thêm bộ nhân | So số chu kỳ giữa `x=0` và `x=255`. Charter mục 10 cấm thẳng |
| 10 | Nhầm “4 bước lặp” với “4 chu kỳ độ trễ” | Báo cáo sai ngân sách thời gian cho tầng ngoài | Đếm chu kỳ trong TB (ca B-4): đáp án là **6** |
| 11 | Dịch `rem` 1 bit thay vì 2 bit mỗi bước | Thuật toán sai hoàn toàn | Bất kỳ ca nào ngoài `x ∈ {0,1}` |
| 12 | Coi cảnh báo `sorry: constant selects` là lỗi | Mất thời gian sửa thứ không hỏng | Phân biệt `sorry:` với `error:`. Đề I01 có cảnh báo cùng loại và vẫn PASS |
| 13 | Kết luận “slack 8,40 ns ⟹ thiết kế nhanh” | Che giấu việc logic bị xoá | Đối chiếu slack với số cell: 26 cell mà slack dư 84 % chu kỳ → nghi ngờ ngay |

## 10. Câu hỏi mentor nên đặt khi bảo vệ

| # | Câu hỏi | Đáp án mong đợi |
|---:|---|---|
| 1 | Vì sao `trial = 4·root + 1`? Chứng minh. | `(2r+b)² = 4r² + b·(4r+1)` với `b ∈ {0,1}`. Phần `4r²` đã trừ ở các bước trước (chính là `rem << 2`), phần còn lại phải trừ là `4r+1` |
| 2 | Vì sao mỗi bước tiêu thụ **2 bit** của `x` chứ không phải 1? | Mỗi bit thêm vào `root` làm `root²` tăng bậc 4. Để cân bằng, phần dư phải dịch 2 bit và nạp 2 bit mới. Vì vậy số bước là `W/2` |
| 3 | Thuật toán chạy bao nhiêu **bước lặp** và bao nhiêu **chu kỳ**? | **4 bước lặp**, **6 chu kỳ** tổng độ trễ (1 nạp + 4 lặp + 1 `done`). Hai con số khác nhau, phải nói rõ |
| 4 | Số chu kỳ có phụ thuộc dữ liệu không? | Không. Điều kiện thoát chỉ là `iter == ROOT_W-1`; `qbit` không ảnh hưởng `state` hay `iter`. Đây là lý do Charter mục 10 cấm “thử dần” |
| 5 | **Mô phỏng RTL báo lỗi gì, và lỗi nằm ở đâu?** | `error: root Unable to assign to unresolved wires` (dòng 59). Lỗi **trong DUT**: `root` có hai driver — `assign root = root_reg;` (dòng 51) và `root <= '0;` (dòng 59) |
| 6 | Bản vá là gì? | **Xoá dòng 59.** Một dòng, không thêm gì. Dòng 57 (`root_reg <= '0`) đã lo việc reset, và `root` chỉ là dây nối từ `root_reg` |
| 7 | **Netlist có 7 FF, Charter dự báo 18–22. Giải thích.** | Yosys giải quyết xung đột driver bằng cách nối `root` về hằng `4'h0`. Sau đó `root_reg` → `trial` → bộ so sánh–trừ → `rem_reg` → `x_reg` chết theo dây chuyền. Cổng vào `x` có **0 tham chiếu** |
| 8 | Tổng hợp báo PASS mà mô phỏng báo FAIL — tin ai? | **Tin cả hai, và điều tra.** Icarus dừng (`error`), Yosys tiếp tục (`Warning`). Hai mức nghiêm ngặt khác nhau cho cùng một lỗi. Bài học: `Warning` của công cụ tổng hợp không được bỏ qua |
| 9 | Làm sao phát hiện nhanh một netlist bị rỗng? | Ba lệnh: `grep "assign" netlist.v` (tìm cổng ra nối hằng) · đếm FF so với dự báo Charter mục 10 · `grep "Warning" yosys.log` |
| 10 | Bước nào trong luồng **đáng lẽ** đã bắt được lỗi này? | **Mô phỏng gate-level** (`L4-GATE`, hiện `CHUA CHAY`). Một ca `x=4` sẽ ra `root=0` thay vì `2`. Đây là bước **duy nhất** phát hiện được logic bị tổng hợp xoá |
| 11 | `slack 8,40 ns` nghĩa là thiết kế nhanh? | Không. Logic thật chỉ **0,46 ns** vì netlist gần như rỗng. So I01 (cùng họ, chuỗi mượn **hẹp hơn**): 1,24 ns. Mâu thuẫn này chính là bằng chứng |
| 12 | Testbench có đủ ca Charter mục 8 không? | **Không** — thiếu `x=100` và `x=99`. Cả hai đều rơi vào `rem_shift == trial`, nhắm thẳng vào ranh giới `>` / `>=`. Và chúng là ca duy nhất cho `root` **mẫu bit xen kẽ** |
| 13 | Mở rộng lên 16 bit: chu kỳ và diện tích tăng thế nào? | Chu kỳ: `W/2 + 2` → 6 thành **10**. Diện tích: **tuyến tính** theo `W` (`x_reg`, `rem_reg`, `root_reg`, bộ so sánh đều `O(W)`). **Hai quy luật cùng bậc `O(W)`**; tích diện tích × thời gian là `O(W²)` |
| 14 | Vì sao không dùng bảng tra cho `W=8`? | Với `W=8` bảng tra chỉ cần 1024 bit và 1 chu kỳ — rất tốt. Nhưng `W=16` cần **512 kbit**, tăng trưởng **mũ**. Và nó không còn là “theo từng bit” |
| 15 | Phần dư cuối có ý nghĩa gì? Sao không đưa ra ngoài? | `rem = x − root²` cho biết sai số cắt. Hiện **không có cổng ra** cho nó — khác đề I01 vốn có `remainder`. Thêm `rem_zero` (1 bit) sẽ rẻ và hữu ích; còn dư 10 chân |

## 11. Giới hạn: đã chứng minh được gì, chưa chứng minh được gì

### Đã chứng minh

| Điều | Bằng chứng |
|---|---|
| Thuật toán đúng trên **toàn miền 256 giá trị** | `test_full_domain()` — PASS |
| `root² ≤ x < (root+1)²` với mọi `x` | `test_full_domain()`, `test_boundaries()` — PASS |
| Đẳng thức `trial = 4·root + 1` đúng ở mọi bước | `test_trial_recurrence()` — PASS |
| **Đúng 4 bước lặp** với mọi `x` | `test_cycle_count()` — PASS |
| Thuật toán mở rộng đúng lên 16 bit (8 bước) | `test_16bit_scaling()` — PASS |
| 10 000 ca ngẫu nhiên khớp `math.isqrt` | `test_random()` (seed 2026) — PASS |
| **RTL có lỗi xung đột driver, và lỗi đó nằm ở đúng dòng 59** | `iverilog_compile.log` + 4 cảnh báo `Driver-driver conflict` trong `yosys.log` |
| **Netlist không chứa đường dữ liệu khai căn** | `assign root = 4'h0;` · `x` 0 tham chiếu · 7 FF · 0 cell `xor`/`xnor` |
| FSM và bộ đếm **đúng và đầy đủ**, không cần sửa | `03_ARCHITECTURE/fsm.md` §4, §7 |

### Chưa chứng minh được

| Điều | Vì sao | Cần gì |
|---|---|---|
| RTL tính đúng **một giá trị nào** | `COMPILE_FAIL` | Xoá dòng 59, chạy lại |
| Độ trễ 6 chu kỳ **đo được** | Không có `simulation.log` | Vá + ca B-4 |
| Ca Charter `x=100`, `x=99` | **Không có trong testbench** | Thêm 2 dòng `run_case` |
| Độ phủ toàn miền trên RTL | TB có 13/256 = 5,1 % ca | Ca B-3 — quét vét cạn |
| Số cell / FF / diện tích **thật** của I02 | Netlist rỗng | Vá + tổng hợp lại. Dự kiến ~28 FF, ~90–120 cell |
| Đường tới hạn thật | STA đo mạch rỗng | Vá + STA lại. Dự kiến chuỗi `rem_reg → so sánh–trừ 9 bit → rem_reg`, logic thật **> 1,24 ns** |
| Quy luật diện tích theo `W` **bằng số đo** | Không có điểm dữ liệu hợp lệ nào | Vá + tổng hợp với `INPUT_W = 8` và `16`, so hai kết quả |
| Netlist tương đương RTL | Mô phỏng gate-level `CHUA CHAY` | Chạy TB trên `netlist.v` |
| Tần số tối đa theo yêu cầu hệ thống | README ghi 10 MHz nhưng SDC cấu hình 10 ns; chưa có clock requirement nhất quán | Chốt yêu cầu clock rồi đánh giá theo STA |
| Diện tích physical, DRC/LVS | Đã có metrics physical flow: 3633,48 µm²; DRC Magic/KLayout 0; LVS match | `06_GDSII/physical_report.md`, `06_GDSII/metrics.json` |

### Tuyên bố phạm vi

Đây là ghi chú hậu kiểm sự cố D-1 ngày 2026-09-24, nên các kết quả compile-fail, netlist
rỗng và thiếu kiểm thử ở những phần trước là **bằng chứng lịch sử của bản chưa vá**. Bản
triển khai hiện tại đã bỏ driver xung đột; mô hình Python và mô phỏng RTL PASS. Physical
flow ngày 2026-10-26 đã tạo GDS, ghi nhận DRC Magic/KLayout bằng 0 và LVS match. Các kết
quả này không chứng minh sign-off, tape-out, chế tạo, hay hoạt động ở một tần số hệ thống
cụ thể. Chi tiết và giới hạn hiện tại được ghi trong báo cáo kiểm chứng và báo cáo
physical design liên kết ở đầu tài liệu.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
