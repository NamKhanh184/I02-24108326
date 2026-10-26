# I02 · Sơ đồ khối bên trong (Block Diagram)

---

> **Ảnh chụp lịch sử trước bản vá P-1:** sơ đồ/netlist bên dưới minh hoạ ảnh hưởng của
> lỗi driver kép D-1, không phải trạng thái RTL hiện tại. Bản vá và kết quả hiện tại xem
> [`../05_VERIFICATION/known_issues.md`](../05_VERIFICATION/known_issues.md) và
> [`../06_GDSII/physical_report.md`](../06_GDSII/physical_report.md).

## 1. Sơ đồ vẽ theo **đúng RTL thật**

Đường liền `───` = tín hiệu còn sống trong netlist. Đường chấm `╌╌╌` = tồn tại trong RTL
nhưng **bị tổng hợp xoá** do xung đột driver trên `root`.

```
  x[7:0] ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
     ❌ CỔNG NÀY KHÔNG XUẤT HIỆN MỘT LẦN NÀO TRONG NETLIST          ╎
                                                                    ╎
  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ PHẦN BỊ TỔNG HỢP XOÁ SẠCH ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌▼╌╌╌
  ╎                                                                     ╎
  ╎   ┌──────────────┐        2 bit cao nhất                            ╎
  ╎   │  x_reg[7:0]  │◀───────────────── nạp từ x                       ╎
  ╎   │ dịch trái 2  │──── x_reg[7 -: 2] = next_pair[1:0] ──┐            ╎
  ╎   │  8 FF        │                                      │            ╎
  ╎   └──────────────┘                                      ▼            ╎
  ╎                                        ╔════════════════════════╗   ╎
  ╎   ┌──────────────┐                     ║ rem_shift[8:0] =       ║   ╎
  ╎   │ rem_reg[8:0] │────────────────────▶║ (rem_reg << 2) | pair  ║   ╎
  ╎   │  9 FF        │                     ║   (CHỈ LÀ DÂY)         ║   ╎
  ╎   └──────▲───────┘                     ╚═══════════╤════════════╝   ╎
  ╎          │ rem_next                                │                ╎
  ╎          │                    ┌────────────────────┤                ╎
  ╎          │                    │                    │                ╎
  ╎   ┌──────┴────────────────────┴────────────────────▼──────────┐     ╎
  ╎   │      BỘ SO SÁNH + TRỪ 9 BIT                                │     ╎
  ╎   │      rem_shift >= trial ?                                  │     ╎
  ╎   │        có  → rem_next = rem_shift - trial, qbit = 1        │     ╎
  ╎   │        không → rem_next = rem_shift,       qbit = 0        │     ╎
  ╎   └─────────────────────────┬────────────────────────▲────────┘     ╎
  ╎                             │ qbit                   │ trial[8:0]   ╎
  ╎                             ▼                        │              ╎
  ╎   ┌──────────────────────────────────┐   ╔═══════════╧═══════════╗  ╎
  ╎   │  root_reg[3:0]                   │──▶║ trial = (root_reg<<2) ║  ╎
  ╎   │  root_reg <= (root_reg<<1)|qbit  │   ║         | 1'b1        ║  ╎
  ╎   │  4 FF                            │   ║   = 4·root + 1 (DÂY)  ║  ╎
  ╎   └──────────────┬───────────────────┘   ╚═══════════════════════╝  ╎
  ╎                  │                                                   ╎
  ╎    ⚠️ assign root = root_reg;  (dòng 51)                            ╎
  ╎    ⚠️ root <= '0;              (dòng 59) ← XUNG ĐỘT DRIVER          ╎
  ╎    → Yosys: "Resolved using constant" → assign root = 4'h0;         ╎
  ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌

  ═══════════════ PHẦN CÒN SỐNG TRONG NETLIST (7 FF) ═══════════════════

   start ──────▶┌──────────────────┐
                │   FSM 2 bit      │◀──── iter == ROOT_W-1 ────┐
                │ state[0],state[1]│                           │
                │  S_IDLE/S_ITER/  │                    ┌──────┴──────┐
                │  S_DONE          │                    │ iter[2:0]   │
                │  2 × dfxtp_1     │───────────────────▶│ 3 × dfxtp_1 │
                └────┬────────┬────┘                    └─────────────┘
                     │        │
                     ▼        ▼
                ┌────────┐ ┌────────┐             root[3:0] ──▶ 4'h0 ❌
                │  busy  │ │  done  │
                │1×dfxtp │ │1×dfxtp │
                └────────┘ └────────┘
```

## 2. Bảng ánh xạ cấu trúc RTL → phần cứng sinh ra

Danh sách flip-flop đọc trực tiếp từ `06_GDSII/synthesis/netlist.v` (7 cell `dfxtp_1`):

| Cấu trúc RTL | Dòng | Bit khai báo | Phần cứng thật | FF thật |
|---|---:|---:|---|---:|
| `logic [INPUT_W-1:0] x_reg;` | 18 | 8 | ❌ **bị xoá sạch** | **0** |
| `logic [ROOT_W-1:0] root_reg;` | 19 | 4 | ❌ **bị xoá** — driver bị thay bằng hằng 0 | **0** |
| `logic [REM_W-1:0] rem_reg;` | 20 | 9 | ❌ **bị xoá** | **0** |
| `logic [ITER_W-1:0] iter;` với `ITER_W = $clog2(5) = 3` | 16, 21 | 3 | `iter[0..2]` + bộ tăng 3 bit | **3** |
| `state_t state;` (3 giá trị, 2 bit) | 35 | 2 | `state[0]`, `state[1]` | **2** |
| `output logic busy;` | 10 | 1 | `busy` | **1** |
| `output logic done;` | 11 | 1 | `done` (cell `_38_`) | **1** |
| `output logic [ROOT_W-1:0] root;` | 9 | 4 | ❌ **`assign root = 4'h0;`** (netlist.v:182) | **0** |
| `always_comb` (dòng 37–49) | 37–49 | — | ❌ **bị xoá** — không cell nào của bộ so sánh–trừ còn lại | 0 |
| | | **27 khai báo** | | **7** |

**Thiếu 20 flip-flop trên 27 bit khai báo — tức 74 % thiết kế biến mất.**

Kiểm chéo: `synth_stat.txt` ghi `sky130_fd_sc_hd__dfxtp_1 : 7`. Khớp.

### Nguyên nhân — bằng chứng nguyên văn từ `yosys.log`

```
Warning: Driver-driver conflict for \root [3] between cell $auto$ff.cc:266:slice$134.Q
         and constant 1'0 in i02_integer_sqrt: Resolved using constant.
Warning: Driver-driver conflict for \root [2] ... Resolved using constant.
Warning: Driver-driver conflict for \root [1] ... Resolved using constant.
Warning: Driver-driver conflict for \root [0] ... Resolved using constant.
```

`root` có **hai driver**:

| Driver | Nguồn | Dòng RTL |
|---|---|---:|
| `root_reg` qua phép `assign` liên tục | `assign root = root_reg;` | 51 |
| Hằng `'0` qua phép gán thủ tục trong nhánh reset | `root <= '0;` | 59 |

Yosys **giải quyết bằng cách chọn hằng số**. Một khi `root` là hằng 0, `root_reg` không
còn ai đọc → bị xoá; `trial` phụ thuộc `root_reg` → bị xoá; `rem_next`, `qbit`, `rem_reg`,
`rem_shift`, `next_pair`, `x_reg` lần lượt chết theo. Toàn bộ đường dữ liệu sụp đổ **theo
hiệu ứng dây chuyền từ một dòng mã duy nhất**.

Bằng chứng cuối cùng: `x` — cổng vào 8 bit — có **0 tham chiếu** trong netlist
(không tìm thấy chuỗi `x[` nào trong phần thân module).

Phán xử đầy đủ và bản vá **một dòng** ở `05_VERIFICATION/known_issues.md`.

### Phân bố 26 cell còn lại

| Khối | Cell (từ `synth_stat.txt`) | Vai trò |
|---|---|---|
| Thanh ghi | 7 × `dfxtp_1` | `iter[2:0]`, `state[1:0]`, `busy`, `done` |
| Bộ tăng + so sánh `iter` | 3 × `a211oi_1`, 4 × `nand2_1`, 3 × `nor2_1`, 2 × `a21oi_1` | Đếm 0…3 và so `== ROOT_W−1` |
| Logic FSM | 2 × `and2_0`, `and3_1`, `and3b_1`, `o21ai_0` | Chuyển trạng thái |
| Đường reset | 1 × `clkinv_1` | Reset đồng bộ |
| Bộ đệm | 1 × `lpflow_isobufsrc_1` | |

**Không có một cell số học nào.** So với đề I01 (vốn có 6 × `xnor2_1`, 8 × `a22oi_1`,
7 × `a222oi_1` cho bộ so sánh–trừ), I02 **hoàn toàn vắng bóng** nhóm cell đó. Đây là dấu
hiệu chẩn đoán rất rõ: **một bộ tính căn bậc hai mà không có cell XOR/XNOR nào là một bộ
tính căn bậc hai không tồn tại.**

## 3. Khối con nào nằm trên đường tới hạn

Đọc `06_GDSII/sta/timing_report_max.txt`:

```
Startpoint: start  (input port clocked by clk)
Endpoint:   _40_   (rising edge-triggered flip-flop clocked by clk)   ← Q = iter[1]
```

| Bước | Cell | Fanout | Slew | Delay (ns) | Time (ns) |
|---|---|---:|---:|---:|---:|
| — | `input external delay` | — | — | 1,00 | 1,00 |
| — | `start (in)` | 1 | 0,00 | 0,00 | 1,00 |
| 1 | `_22_` `nor2_1` | 2 | 0,05 | 0,03 | 1,03 |
| 2 | `_26_` `a211oi_1` | 4 | 0,34 | 0,32 | 1,35 |
| 3 | `_31_` `a211oi_1` | 1 | 0,09 | 0,11 | 1,46 |
| 4 | `_40_` `dfxtp_1` | — | — | — | 1,46 |

| Đại lượng | Giá trị |
|---|---:|
| Data arrival time | **1,46 ns** |
| trong đó `set_input_delay` **giả định** | 1,00 ns |
| **Độ trễ logic thật** | **0,46 ns** |
| Data required time | 9,86 ns |
| **Slack** | **8,40 ns (MET)** |
| Số cell trên đường | **4** |

### 🔴 Đọc kết quả cho đúng

**Đường tới hạn là `start → iter[1]` — tức đường điều khiển của bộ đếm bước lặp.**
Endpoint **không phải** `rem_reg` hay `root_reg`, vì hai thanh ghi đó **không tồn tại**.

| Điều mong đợi ở một bộ khai căn đúng | Điều STA thật sự đo |
|---|---|
| `rem_reg → rem_shift → so sánh 9 bit → trừ → rem_reg` | `start → 3 cổng → iter[1]` |
| Độ sâu: chuỗi mượn 9 bit, ~4–6 mức cổng | **3 cổng** |
| Endpoint: `rem_reg[*]` hoặc `root_reg[*]` | **`iter[1]`** |

> **`slack 8,40 ns` không phải tin vui — nó là triệu chứng.** Logic thật chỉ mất 0,46 ns
> vì gần như không còn logic nào. Sau khi vá lỗi driver và tổng hợp lại, số FF dự kiến về
> vùng **18–22** (Charter mục 10) và đường tới hạn gần như chắc chắn chuyển sang chuỗi
> `rem_reg → so sánh–trừ 9 bit → rem_reg`. Đó là **dự đoán**, phải chạy lại STA để xác
> nhận.
>
> Tham chiếu hữu ích: đề I01 (cùng họ thuật toán lặp so sánh–trừ, cùng môi trường) có
> **33 FF · 148 cell · logic thật 1,24 ns**. I02 sau khi vá sẽ nằm ở vùng tương tự hoặc
> nhỏ hơn — vì nó chỉ lặp **4** bước thay vì 8.

## 4. Bảng chẩn đoán nhanh — dùng lại được cho mọi đề

| Dấu hiệu | Cách kiểm | Kết quả ở I02 |
|---|---|---|
| Cổng ra bị nối chết | `grep "assign" netlist.v` | 🔴 `assign root = 4'h0;` |
| Cổng vào không được dùng | Đếm tham chiếu tới tên cổng trong netlist | 🔴 `x`: **0 tham chiếu** |
| Số FF lệch dự báo | So `synth_stat.txt` với Charter mục 10 | 🔴 7 so với 18–22 |
| Xung đột driver | `grep "Driver-driver" yosys.log` | 🔴 4 cảnh báo |
| Thiếu cell số học | Tìm `xor`/`xnor` trong `synth_stat.txt` | 🔴 **0 cell** |
| Đường tới hạn quá ngắn | Đếm cell trong `timing_report_max.txt` | 🔴 4 cell, 0,46 ns logic |

**Sáu dấu hiệu, sáu lần đỏ.** Bất kỳ một dấu hiệu nào trong số đó cũng đủ để dừng lại và
điều tra.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
