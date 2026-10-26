# I02 · Đường dữ liệu (Datapath)

---

> **Ảnh chụp lịch sử trước bản vá P-1:** đoạn dưới mô tả datapath trong RTL và cách lỗi
> driver kép từng làm Yosys nối `root` về `4'h0`. Lỗi đã được vá; không coi các mô tả
> netlist lỗi bên dưới là kết quả hiện tại. Xem
> [`../05_VERIFICATION/known_issues.md`](../05_VERIFICATION/known_issues.md).
>
> Cấu trúc datapath RTL vẫn có giá trị để đọc kiến trúc; báo cáo số liệu hiện có xem tại
> [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md).

---

## 1. Bản chất: datapath **quay vòng**, xử lý 2 bit vào — 1 bit ra mỗi bước

```
         ┌──────────────────────────────────────────────────────────┐
         │                                                          │
         ▼                                                          │
   [rem_reg] ──dịch trái 2, ghép pair──▶ [rem_shift 9 bit]         │
                                                │                   │
   [root_reg] ──dịch trái 2, ghép 1──▶ [trial 9 bit]               │
                                                │                   │
                                                ▼                   │
                                    [so sánh: rem_shift ≥ trial?]   │
                                         │              │           │
                                    có   │              │  không    │
                                         ▼              ▼           │
                                    [trừ trial]    [giữ nguyên]     │
                                         │              │           │
                                         └──────┬───────┘           │
                                                │ rem_next          │
                                                └───────────────────┘
                                          (chốt vào rem_reg ở cạnh clock)
   [root_reg] ◀── dịch trái 1, ghép qbit ──────────────┘
```

Đây là **cùng một khuôn** với bộ chia I01 — so sánh, trừ có điều kiện, dịch. Khác biệt
duy nhất: số bị trừ không phải hằng số `divisor` mà là **`trial = 4·root + 1`, thay đổi
mỗi bước**.

## 2. Bảng các đường dữ liệu

| Đường | Độ rộng | Từ | Đến | Bản chất | Trong netlist |
|---|---:|---|---|---|---|
| `x[7:0]` | 8 | cổng vào | `x_reg` | Toán hạng, lấy mẫu 1 lần | ❌ **0 tham chiếu** |
| `x_reg[7:0]` | 8 | thanh ghi dịch trái 2 | `next_pair` | Nguồn cặp bit vào | ❌ bị xoá |
| `next_pair[1:0]` | 2 | `x_reg[INPUT_W-1 -: 2]` | `rem_shift` | **2 bit radicand mỗi bước** | ❌ bị xoá |
| `rem_shift[8:0]` | 9 | `(rem_reg << 2) \| next_pair` | so sánh + trừ | **Chỉ là dây** — dịch không tốn cổng | ❌ bị xoá |
| `trial[8:0]` | 9 | `(root_reg << 2) \| 1'b1` | so sánh + trừ | **Chỉ là dây** — `4·root+1` | ❌ bị xoá |
| `rem_next[8:0]` | 9 | bộ trừ hoặc đường vòng | `rem_reg` | Phần dư bước kế | ❌ bị xoá |
| `qbit` | 1 | kết quả so sánh | `root_reg[0]` | **1 bit căn mỗi chu kỳ** | ❌ bị xoá |
| `rem_reg[8:0]` | 9 | thanh ghi | `rem_shift` | Trạng thái vòng lặp | ❌ **0 FF** |
| `root_reg[3:0]` | 4 | thanh ghi dịch trái | `trial`, cổng ra | Tích luỹ căn | ❌ **0 FF** |
| `root[3:0]` | 4 | `root_reg` | cổng ra | Kết quả | 🔴 **hằng `4'h0`** |
| `iter[2:0]` | 3 | bộ đếm | so sánh `== ROOT_W-1` | **Điều khiển**, không phải dữ liệu | ✅ 3 FF |

### Phép dịch **miễn phí** — giống I01

```systemverilog
rem_shift = (rem_reg << 2) | next_pair;       // dịch 2, ghép 2 bit
trial     = (root_reg << 2) | 1'b1;           // dịch 2, ghép hằng 1
root_reg <= (root_reg << 1) | qbit;           // dịch 1, ghép qbit
x_reg    <= x_reg << 2;                       // dịch 2
```

Bốn phép dịch, **không cổng logic nào**. Toàn bộ chi phí nằm ở **một** chỗ: bộ so sánh +
trừ 9 bit.

> ⚠️ Nhưng `x_reg <= x_reg << 2` **có** tốn phần cứng theo nghĩa khác: nó cần 8 FF để giữ
> `x_reg`. Có cách rẻ hơn — thay vì dịch cả `x_reg`, dùng một bộ chọn (mux) lấy cặp bit
> tại vị trí do `iter` chỉ định. Đổi 8 FF lấy một mux 4:1 rộng 2 bit. Xem `tradeoff.md`.

## 3. Đồ thị phụ thuộc

### 3.1 Phụ thuộc **trong một chu kỳ** (tổ hợp)

```
 mức 0   rem_reg[8:0]      x_reg[7:6]        root_reg[3:0]
            │                  │                  │
            │ (dây: <<2 | )    │                  │ (dây: <<2 | 1)
            ▼                  ▼                  ▼
 mức 0   rem_shift[8:0] ◀──────┘             trial[8:0]
            │                                     │
            └──────────────┬──────────────────────┘
                           ▼
 mức 1-4        BỘ SO SÁNH 9 BIT  (rem_shift >= trial)
                ↳ chuỗi mượn 9 bit — ĐÂY LÀ ĐƯỜNG SÂU NHẤT
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
 mức 4-5   qbit                    rem_next[8:0]
             │                           │
             ▼                           ▼
 (cạnh clock) root_reg[0]            rem_reg[8:0]
```

| Đầu ra tổ hợp | Độ sâu ước tính từ RTL | Đo được từ STA |
|---|---|---|
| `qbit` | ~4–5 mức (chuỗi mượn 9 bit) | ⬜ **không đo được — logic không tồn tại** |
| `rem_next[8:0]` | ~4–5 mức | ⬜ như trên |
| `iter[1]` (điều khiển) | ~3 mức | ✅ **3 cell**, 0,46 ns |

### 3.2 Phụ thuộc **theo chu kỳ** — bản chất của bài toán

```
 chu kỳ 1 (nạp)   x_reg ← x,  root=0,  rem=0
                       │
 chu kỳ 2         rem₁, root₁ = f(rem₀, root₀, x[7:6])
                       │  ◀── root₁ PHẢI có trước, vì trial₂ = 4·root₁ + 1
 chu kỳ 3         rem₂, root₂ = f(rem₁, root₁, x[5:4])
                       │
 chu kỳ 4         rem₃, root₃ = f(rem₂, root₂, x[3:2])
                       │
 chu kỳ 5         rem₄, root₄ = f(rem₃, root₃, x[1:0])   ← kết quả cuối
                       │
 chu kỳ 6         done = 1
```

> 🔎 **Phụ thuộc nối tiếp ở đây còn chặt hơn phép chia.**
> Ở bộ chia, số bị trừ (`divisor`) là **hằng số** trong suốt 8 bước. Ở bộ khai căn,
> số bị trừ (`trial = 4·root + 1`) **phụ thuộc kết quả các bước trước**. Nghĩa là mỗi
> bước không chỉ cần `rem` của bước trước mà còn cần `root` của bước trước.
>
> Hệ quả: không có cách nào tính trước `trial` cho các bước sau. Đây là lý do khai căn
> **không thể song song hoá** theo bất kỳ cách nào tương tự cây Wallace của phép nhân.

### 3.3 Độ sâu của từng đầu ra, tính bằng chu kỳ

| Đầu ra | Sẵn sàng sau bao nhiêu chu kỳ kể từ `start` |
|---|---:|
| `busy` (lên 1) | **1** |
| `root[3]` (bit cao nhất, sinh ở bước 1) | **2** |
| `root[0]` (bit thấp nhất, sinh ở bước 4) | **5** |
| `rem_reg` (phần dư cuối) | **5** |
| `done` | **6** |

## 4. Dự đoán đường tới hạn — và đối chiếu STA thật

**Dự đoán khi đọc RTL:** đường nặng nhất phải là
`rem_reg[8:0] → rem_shift → so sánh 9 bit → trừ → rem_next → rem_reg`,
vì đó là chuỗi duy nhất chứa chuỗi mượn 9 bit. Đường này **sâu hơn** của I01 (chuỗi mượn
chỉ 5 bit), nên đáng lẽ I02 phải có đường tới hạn **dài hơn** I01.

**STA thật (`timing_report_max.txt`):**

| | Dự đoán từ RTL | STA thật |
|---|---|---|
| Startpoint | `rem_reg[8]` | **`start` (cổng vào)** |
| Endpoint | `rem_reg[*]` | **`_40_` = `iter[1]`** |
| Loại đường | reg → reg (bộ trừ 9 bit) | in → reg (bộ đếm 3 bit) |
| Số cell | ước 5–7 | **3** cổng tổ hợp |
| Độ trễ logic | ước ≥ 1,2 ns (đối chiếu I01) | **0,46 ns** |

### Nguyên nhân gây lệch — và nó **không** giống trường hợp I01

Ở đề I01, lệch có nguyên nhân kỹ thuật chính đáng (fanout 22, bộ trừ hẹp, `set_input_delay`
giả định). Ở đây nguyên nhân hoàn toàn khác và **nghiêm trọng hơn nhiều**:

> 🔴 **Đường được dự đoán KHÔNG TỒN TẠI trong netlist.**
> Không phải nó ngắn hơn dự kiến — nó **đã bị xoá**. `rem_reg`, `root_reg`, bộ so sánh–trừ
> 9 bit đều không có trong `netlist.v`. STA chỉ có thể đo những gì còn lại: một bộ đếm 3
> bit và một FSM 2 bit.

**Kiểm chứng đối chứng bằng I01** (cùng môi trường, cùng họ thuật toán, cùng SDC):

| | I01 (đúng) | I02 (hỏng) | Nhận xét |
|---|---:|---:|---|
| Số cell | 148 | **26** | I02 chỉ bằng 17,6 % |
| Flip-flop | 33 | **7** | I02 chỉ bằng 21 % |
| Cell số học (`xor`/`xnor`) | 7 | **0** | 🔴 dấu hiệu quyết định |
| Bước lặp | 8 | 4 | I02 lặp ít hơn một nửa |
| Độ trễ logic thật | 1,24 ns | **0,46 ns** | |
| Bề rộng chuỗi mượn | 5 bit | **9 bit** (đáng lẽ) | I02 **phải** sâu hơn, nhưng lại nông hơn |

Hàng cuối là mâu thuẫn không thể giải thích bằng tối ưu hoá thông thường: một thiết kế có
chuỗi mượn **rộng gần gấp đôi** mà lại có đường tới hạn **ngắn hơn một nửa** chỉ có thể
xảy ra khi chuỗi mượn đó **không được tổng hợp**.

## 5. Datapath sẽ trông thế nào sau khi vá (dự báo, chưa đo)

| Thành phần phục hồi | Bit | FF | Cell tổ hợp ước tính |
|---|---:|---:|---|
| `x_reg[7:0]` | 8 | 8 | mux nạp/dịch |
| `root_reg[3:0]` | 4 | 4 | mux + dây dịch |
| `rem_reg[8:0]` | 9 | 9 | mux nạp/giữ |
| Bộ so sánh + trừ 9 bit | — | 0 | ~25–40 cell (đối chiếu I01: ~30 cell cho 5 bit) |
| **Cộng phần điều khiển hiện có** | | **7** | 26 cell |
| **Tổng dự kiến** | | **~28 FF** | **~90–120 cell** |

> Ước tính **28 FF** cao hơn dải **18–22** của Charter mục 10. Chênh lệch đến từ
> `rem_reg` rộng **9** bit trong khi theo INV-6 (`rem ≤ 2·root ≤ 30`) chỉ cần **7** bit,
> và từ việc giữ nguyên `x_reg` 8 bit thay vì dùng mux chọn cặp bit theo `iter`
> (tiết kiệm được tới 8 FF). Cả hai đều là đánh đổi bàn ở `tradeoff.md`.
>
> ⬜ **Đây là dự báo, không phải số đo.** Phải vá rồi chạy lại `02_run_synth.sh` mới có
> số thật.

## 6. Vì sao không pipeline được

Giống I01, nhưng chặt hơn: vòng hồi tiếp ở đây có **hai** biến trạng thái
(`rem_reg` và `root_reg`), và `trial` của bước `i+1` phụ thuộc `root_reg` của bước `i`.

Chèn thanh ghi vào giữa so sánh và trừ chỉ làm mỗi bước tốn 2 chu kỳ thay vì 1 → 8 chu
kỳ lặp thay vì 4. **Tần số tăng, số chu kỳ tăng theo cùng tỉ lệ → thời gian thật không
đổi**, mà diện tích tăng.

Cách duy nhất giảm số chu kỳ là **xử lý nhiều bit hơn mỗi bước** — nhưng với khai căn,
mỗi bước đã xử lý 2 bit radicand (tối đa cho radix-2 của `root`). Muốn nhanh hơn phải
chuyển sang radix-4 cho `root`, tức thử 4 giá trị `trial` mỗi bước. Xem `tradeoff.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
