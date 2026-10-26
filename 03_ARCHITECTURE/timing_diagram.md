# I02 · Giản đồ thời gian (Timing Diagram)

---

> ## ✅ Waveform và kiểm tra số bước
>
> RTL đã chạy PASS bằng Icarus Verilog 12.0. Testbench ghi waveform tại
> `../05_VERIFICATION/waveforms/i02_integer_sqrt.vcd` và kiểm tra `busy` đúng 4 chu kỳ
> cho mỗi ca. Bảng dưới đây được suy ra từ RTL và đối chiếu với mô hình chuẩn Python.
>
> Đây là mô phỏng **hành vi (zero-delay)**: mọi
> tín hiệu đổi đúng tại cạnh clock, **không** minh hoạ `t_ckq`, `t_setup` hay độ trễ cổng.

---

## 1. Số chu kỳ cho **một kết quả** — con số chốt

| Pha | Số chu kỳ | Việc xảy ra |
|---|---:|---|
| Nạp (`S_IDLE` thấy `start`) | **1** | Chốt `x_reg ← x`; xoá `root_reg`, `rem_reg`, `iter` |
| Lặp (`S_ITER`) | **4** | Mỗi chu kỳ tiêu thụ **2 bit** của `x` và sinh **1 bit** của `root` |
| Phát `done` (`S_DONE`) | **1** | `done ← 1`, `root` hợp lệ |
| **TỔNG ĐỘ TRỄ** | **6 chu kỳ** | |

**Số chu kỳ KHÔNG phụ thuộc dữ liệu.** `x=0` và `x=255` đều mất đúng 6 chu kỳ. Đây là
điều Charter mục 10 yêu cầu (cấm “thử dần” vì số chu kỳ thay đổi theo dữ liệu).

> ### ⚠️ “4 chu kỳ” hay “6 chu kỳ”? — phải trả lời cho đúng
>
> Charter mục 2 và mục 9 viết “thuật toán chạy **đúng 4 chu kỳ** cho số 8 bit”.
> Chính xác hơn:
>
> | Cách nói | Con số | Đúng khi nào |
> |---|---:|---|
> | Số **bước lặp** của thuật toán | **4** | Đây là ý Charter — `ROOT_W = INPUT_W/2 = 4` |
> | Số chu kỳ `busy = 1` | **4** | Trùng với số bước lặp |
> | **Tổng độ trễ** `start` → `done` | **6** | 1 nạp + 4 lặp + 1 phát `done` |
>
> Khi trả lời Charter mục 9, phải nêu **cả hai** con số và nói rõ con số nào là gì. Trả
> lời “4 chu kỳ” mà không kèm giải thích là **thiếu**; trả lời “6 chu kỳ” mà không nói
> trong đó có 4 bước lặp cũng là **thiếu**.

Testbench xác nhận 4 chu kỳ `busy` cho từng ca; tổng độ trễ `start`→`done` là 6 chu kỳ
theo diễn tiến FSM trong bảng. Waveform là bằng chứng hành vi, không phải STA.

## 2. Giản đồ dạng sóng đầy đủ — `√255 = 15` (ca 15 của testbench)

`x = 255 = 8'b1111_1111`. Các cặp bit theo thứ tự: `11, 11, 11, 11`.

```
chu kỳ       0    1    2    3    4    5    6    7
           ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐
clk     ───┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └───

start   ______╱‾‾‾‾╲_______________________________
              ▲ lấy mẫu tại cạnh 1

x       │ FF │ FF │ ~~ giá trị cổng vào không còn quan trọng ~~ │
                   (đã chốt vào x_reg ở cạnh 1)

            ┌─ NẠP ─┬──────── 4 BƯỚC LẶP ────────┬─ XONG ─┐
state   │IDLE│IDLE│ITER│ITER│ITER│ITER│DONE│IDLE│
                  ▲cạnh1                 ▲cạnh5  ▲cạnh6

iter    │ -- │ 0  │ 1  │ 2  │ 3  │ 3  │ 0  │ 0  │
                   b1   b2   b3   b4
                                  ▲ iter==3 → thoát

x_reg   │ -- │ FF │ FC │ F0 │ C0 │ 00 │ 00 │  (dịch trái 2 mỗi bước)
pair    │ -- │ 11 │ 11 │ 11 │ 11 │ -- │ -- │  (= x_reg[7:6])

busy    ______╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲______________
              cạnh1                cạnh5 ▲ (4 chu kỳ)

done    _______________________________╱‾‾‾╲__________
                                 cạnh6 ▲ (1 chu kỳ)

root    │ 0  │ 0  │ 1  │ 3  │ 7  │ 15 │ 15 │
                   ▲b1  ▲b2  ▲b3  ▲b4
                   1    11   111  1111
```

### Bảng giá trị từng chu kỳ — **giá trị sau mỗi cạnh clock**

| Cạnh | `iter` | `x_reg` | `pair` | `rem_shift` = `4·rem\|pair` | `trial` = `4·root+1` | `≥`? | `qbit` | `rem_reg` | `root_reg` |
|---:|---:|---|---:|---:|---:|:-:|:-:|---:|---|
| 1 (nạp) | 0 | `1111_1111` | — | — | — | — | — | 0 | `0000` = 0 |
| 2 · bước 1 | 1 | `1111_1100` | 3 | **3** | **1** | ✅ | **1** | **2** | `0001` = 1 |
| 3 · bước 2 | 2 | `1111_0000` | 3 | **11** | **5** | ✅ | **1** | **6** | `0011` = 3 |
| 4 · bước 3 | 3 | `1100_0000` | 3 | **27** | **13** | ✅ | **1** | **14** | `0111` = 7 |
| 5 · bước 4 | 3 | `0000_0000` | 3 | **59** | **29** | ✅ | **1** | **30** | `1111` = **15** |
| 6 (`done`) | 0 | — | — | — | — | — | — | **30** | **15** |

**Kiểm:** `15² = 225`, `255 − 225 = 30` = `rem_reg` ✅ — đúng INV-5.
**Kiểm INV-1:** `15² = 225 ≤ 255 < 256 = 16²` ✅.
**Kiểm INV-6:** `rem = 30 ≤ 2 × 15 = 30` ✅ — đúng sát biên, đây là ca xấu nhất cho độ rộng
`rem_reg`.

Đối chiếu mô hình chuẩn: `isqrt_bitwise(255, 8)` trả `trace` gồm 4 dòng với các trường
`pair`, `rem_shift`, `trial`, `bit`, `root`, `remainder` — **trùng khớp từng dòng** với
bảng trên.

## 3. Giản đồ `√100 = 10` — ca Charter mục 8

`x = 100 = 8'b0110_0100`. Các cặp bit: `01, 10, 01, 00`.

```
chu kỳ       0    1    2    3    4    5    6
           ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐  ┌─┐
clk     ───┘ └──┘ └──┘ └──┘ └──┘ └──┘ └──┘ └───

start   ______╱‾‾‾‾╲___________________________
state   │IDLE│IDLE│ITER│ITER│ITER│ITER│DONE│
iter    │ -- │ 0  │ 1  │ 2  │ 3  │ 3  │ 0  │
x_reg   │ -- │ 64 │ 90 │ 40 │ 00 │ 00 │ -- │   (hex)
pair    │ -- │ 01 │ 10 │ 01 │ 00 │ -- │ -- │
qbit    │ -- │ 1  │ 0  │ 1  │ 0  │ -- │ -- │   ◀── MẪU XEN KẼ 1010
root    │ 0  │ 0  │ 1  │ 2  │ 5  │ 10 │ 10 │
                   1    10   101  1010
done    _________________________________╱‾‾‾╲
                                   cạnh6 ▲
```

| Cạnh | `iter` | `x_reg` | `pair` | `rem_shift` | `trial` | `≥`? | `qbit` | `rem_reg` | `root_reg` |
|---:|---:|---|---:|---:|---:|:-:|:-:|---:|---|
| 1 (nạp) | 0 | `0110_0100` | — | — | — | — | — | 0 | `0000` = 0 |
| 2 · bước 1 | 1 | `1001_0000` | **1** | **1** | **1** | ✅ | **1** | 0 | `0001` = 1 |
| 3 · bước 2 | 2 | `0100_0000` | **2** | **2** | **5** | ❌ | **0** | **2** | `0010` = 2 |
| 4 · bước 3 | 3 | `0000_0000` | **1** | **9** | **9** | ✅ | **1** | 0 | `0101` = 5 |
| 5 · bước 4 | 3 | `0000_0000` | **0** | **0** | **21** | ❌ | **0** | 0 | `1010` = **10** |
| 6 (`done`) | 0 | — | — | — | — | — | — | **0** | **10** |

**Kiểm:** `10² = 100` chính xác → `rem = 0` ✅.

> ### 🔎 Vì sao ca này **bắt buộc** phải có
>
> Hai lần ở cạnh 2 và cạnh 4, phép so sánh rơi vào trường hợp **`rem_shift == trial`**
> (`1 == 1` và `9 == 9`). Đây chính là ranh giới `>` so với `>=`:
>
> | Nếu RTL viết | Kết quả `√100` | Đúng? |
> |---|---:|:-:|
> | `rem_shift >= trial` (đúng) | **10** | ✅ |
> | `rem_shift > trial` (sai) | **8** | ❌ |
>
> Và mẫu `qbit` là **`1,0,1,0`** — testbench hiện có cả `x=99` và `x=100`, hai ca Charter
> kiểm tra mẫu xen kẽ.

## 4. Giản đồ **hai phép tính liên tiếp**

```
chu kỳ    1        5   6   7   8       12  13
          ▼        ▼   ▼   ▼   ▼        ▼   ▼
state  │IDLE│ITER×4 │DONE│IDLE│IDLE│ITER×4│DONE│IDLE│
        nạp₁              ▲    nạp₂              ▲
                        done₁                  done₂

start  __╱‾╲_______________╱‾╲_____________________

done   _____________________╱‾╲__________________╱‾╲
                            ▲ 1 chu kỳ           ▲
```

| Đại lượng | Giá trị |
|---|---:|
| Độ trễ mỗi phép | **6** chu kỳ |
| Khoảng cách nhỏ nhất giữa hai `start` | **7** chu kỳ |
| Thông lượng tối đa bền vững | **1 kết quả / 7 chu kỳ** |

## 5. So sánh nhịp độ với đề I01 (cùng họ thuật toán, cùng môi trường)

| | **I02** — căn 8 bit | **I01** — chia 8÷4 |
|---|---:|---:|
| Bit đầu vào tiêu thụ mỗi bước | **2** | 1 |
| Bit kết quả sinh mỗi bước | 1 | 1 |
| Số bước lặp | **4** | 8 |
| Tổng độ trễ | **6** chu kỳ | 10 chu kỳ |
| Bề rộng chuỗi mượn | **9** bit | 5 bit |
| Kiểm chứng số bước | ✅ testbench xác nhận 4 chu kỳ `busy` | ✅ mô phỏng |

> **Đánh đổi rõ ràng:** I02 tiêu thụ **2 bit mỗi bước** nên chỉ cần **một nửa** số bước
> so với I01 — nhưng phải trả giá bằng **chuỗi mượn rộng gần gấp đôi** (9 bit so với
> 5 bit), tức đường tổ hợp sâu hơn. Số liệu STA 2,86 ns được ghi nhận trong README tham
> chiếu; raw report chưa có trong checkout để so sánh độc lập. Xem
> [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md).

## 6. Quy luật mở rộng — dự báo cho `INPUT_W` khác

| `INPUT_W` | `ROOT_W` | Bước lặp | Tổng chu kỳ | Bề rộng so sánh | FF ước tính |
|---:|---:|---:|---:|---:|---|
| 8 | 4 | **4** | **6** | 9 bit | ~28 (dự báo sau khi vá) |
| 16 | 8 | **8** | **10** | 17 bit | ~52 |
| 32 | 16 | **16** | **18** | 33 bit | ~100 |
| `W` | `W/2` | **`W/2`** | **`W/2 + 2`** | `W+1` bit | ~`2,5·W` |

**Hai quy luật, cùng bậc:**

- Số chu kỳ: `W/2 + 2` → **tuyến tính theo `W`**, hệ số 1/2.
- Diện tích: `x_reg` (`W`) + `rem_reg` (`W+1`) + `root_reg` (`W/2`) + bộ so sánh–trừ
  (`W+1` bit) → **tuyến tính theo `W`**.

Vậy **hai quy luật giống nhau về bậc** (cả hai là `O(W)`), và tích diện tích × thời gian
tăng theo **`O(W²)`**. Đây là đáp án cho Charter mục 2 câu 2 — phân tích đầy đủ ở
`implementation-notes_I02.md` §8.

> Một sắc thái không được bỏ qua: bộ so sánh–trừ rộng `W+1` bit có **chuỗi mượn dài hơn**
> khi `W` tăng, nên **chu kỳ clock tối đa cũng phải dài ra** (khoảng `O(log W)` nếu công
> cụ dùng carry-lookahead, `O(W)` nếu ripple). Thời gian thật = số chu kỳ × chu kỳ clock
> nên tăng **nhanh hơn** `O(W)` một chút.
>
> ⬜ Chỉ hàng `INPUT_W = 8` có cấu trúc RTL thật; **không hàng nào** có số đo hợp lệ, vì
> netlist hiện tại không chứa datapath. Mô hình chuẩn đã kiểm đúng thuật toán ở 16 bit
> (`test_16bit_scaling()` — PASS), nhưng đó là kiểm **thuật toán**, không phải **phần
> cứng**.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
