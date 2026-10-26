# I02 · Máy trạng thái (FSM)

---

## 1. Có FSM không? — Có, và là loại Moore

**Bằng chứng có FSM:**

```systemverilog
typedef enum logic [1:0] {      // RTL dòng 29–33
    S_IDLE,
    S_ITER,
    S_DONE
} state_t;

state_t state;                   // RTL dòng 35
```

Netlist giữ đúng 2 FF trạng thái: `\state[0]`, `\state[1]`
(`06_GDSII/synthesis/netlist.v`).

**Bằng chứng là Moore:**

| Tiêu chí | Kiểm trên I02 |
|---|---|
| `busy`, `done` là chân `Q` của FF? | ✅ gán bằng `<=` trong `always_ff` → netlist: `Q` của `dfxtp_1` (`_38_` → `done`) |
| `root` phụ thuộc đầu vào trong cùng chu kỳ? | ❌ Không — `assign root = root_reg;` từ **thanh ghi** |
| Có đường tổ hợp nào từ cổng vào ra cổng ra? | ❌ Không có |

→ **Moore thuần.**

> ⚠️ Lưu ý: `root` trong netlist là hằng `4'h0` — điều đó **không** đổi phân loại FSM.
> Phân loại được xác định từ **RTL**, còn netlist chỉ cho biết cái gì bị xoá.

## 2. Mã hoá trạng thái — và một mã **không dùng**

`typedef enum logic [1:0]` với **3** giá trị, nhưng mã hoá **2 bit** → có **4** tổ hợp,
trong đó **một tổ hợp không được gán tên**:

| Trạng thái | Mã `state[1:0]` | Nghĩa | Số chu kỳ ở lại |
|---|---|---|---|
| `S_IDLE` | `2'b00` | Chờ `start` | không giới hạn |
| `S_ITER` | `2'b01` | Đang lặp so sánh–trừ | **đúng 4** |
| `S_DONE` | `2'b10` | Phát `done` | **1** |
| *(không tên)* | **`2'b11`** | ⚠️ **mã thừa** | bắt bởi nhánh `default` |

**Kiểu mã: nhị phân, 2 bit.** Yosys giữ nguyên — netlist chỉ có 2 FF trạng thái.

> Đây là điểm khác với đề I01 (4 trạng thái, dùng hết 4 mã). Ở I02 có **một mã thừa**, và
> việc RTL có nhánh `default` bắt nó là **thiết kế phòng thủ đúng** — xem §5.

## 3. Sơ đồ trạng thái ASCII (đọc từ RTL thật)

```
                    reset đồng bộ (!rst_n)
                           │
                           ▼
       ┌───────────────────────────────────────────┐
       │                                           │
       │             ┌──────────────┐              │
       └────────────▶│   S_IDLE     │              │
        (từ S_DONE)  │   2'b00      │              │
                     │  busy ← 0    │              │
                     └──────┬───────┘              │
                            │ start = 1            │
                            │ x_reg ← x            │
                            │ root_reg ← 0         │
                            │ rem_reg  ← 0         │
                            │ iter     ← 0         │
                            │ busy     ← 1         │
                            ▼                      │
              iter != 3  ┌──────────────┐          │
            ┌───────────▶│   S_ITER     │          │
            │  iter++    │   2'b01      │          │
            │  rem ← next│  busy ← 1    │          │
            │  root ←    │              │          │
            │  (root<<1) │              │          │
            │    | qbit  │              │          │
            │  x_reg<<=2 │              │          │
            └────────────┤              │          │
                         └──────┬───────┘          │
                                │ iter == ROOT_W-1 = 3
                                │ (bước lặp thứ 4 VẪN thực hiện)
                                │ busy ← 0
                                ▼                  │
                         ┌──────────────┐          │
                         │   S_DONE     │──────────┘
                         │   2'b10      │
                         │  done ← 1    │
                         │  busy ← 0    │
                         └──────────────┘

       ╔══════════════════════════════════════════════════╗
       ║  mã 2'b11 — KHÔNG CÓ TÊN, KHÔNG KHẢ ĐẠT          ║
       ║  nhánh `default` đưa về S_IDLE, busy ← 0         ║
       ╚══════════════════════════════════════════════════╝
```

## 4. Bảng chuyển trạng thái đầy đủ

| # | Trạng thái | `start` | `iter == 3` | Kế tiếp | Đầu ra / hành động | Dòng |
|---|---|:-:|:-:|---|---|---:|
| T1 | bất kỳ + `!rst_n` | × | × | `S_IDLE` | tất cả thanh ghi ← 0 | 54–62 |
| T2 | `S_IDLE` | 0 | × | `S_IDLE` | `busy←0`, `done←0` | 67–68 |
| T3 | `S_IDLE` | 1 | × | **`S_ITER`** | `x_reg←x`; xoá `root_reg`,`rem_reg`,`iter`; `busy←1` | 69–76 |
| T4 | `S_ITER` | × | 0 | `S_ITER` | `rem_reg←rem_next`, `root_reg←(root_reg<<1)\|qbit`, `x_reg←x_reg<<2`, `iter←iter+1`, `busy←1` | 79–91 |
| T5 | `S_ITER` | × | 1 | **`S_DONE`** | ba phép gán datapath **vẫn thực hiện**; `busy←0` | 79–88 |
| T6 | `S_DONE` | × | × | `S_IDLE` | **`done←1`**, `busy←0` | 94–98 |
| T7 | `2'b11` (`default`) | × | × | `S_IDLE` | `busy←0` | 100–103 |

### Kiểm tính đầy đủ

| Trạng thái | Điều kiện ra phủ kín? | Kiểm |
|---|:-:|---|
| `S_IDLE` | ✅ | `start` + `!start` |
| `S_ITER` | ✅ | `iter==3` + `iter!=3` |
| `S_DONE` | ✅ | vô điều kiện |
| `2'b11` | ✅ | `default`, vô điều kiện |

→ **Không có nhánh thiếu, không suy ra latch.** Mọi trạng thái có tên đều khả đạt — khác
với đề H07 (nơi `VALID` là trạng thái chết).

### Chi tiết quyết định tính đúng — hàng T5

```systemverilog
S_ITER: begin
    busy <= 1'b1;

    rem_reg  <= rem_next;                       // ①
    root_reg <= (root_reg << 1) | qbit;         // ②
    x_reg    <= x_reg << 2;                     // ③

    if (iter == ROOT_W-1) begin                 // ← if nằm SAU ①②③
        busy  <= 1'b0;
        state <= S_DONE;
    end else begin
        iter <= iter + 1'b1;
    end
end
```

Ba phép gán ①②③ nằm **trước** câu `if`, nên chúng thực hiện ở **cả 4** lần vào `S_ITER`.
Nếu ai đó đưa chúng vào nhánh `else`, `root` sẽ thiếu đúng **1 bit** — `√255` sẽ ra `7`
thay vì `15`. Testbench bắt được ngay bằng ca `x=255`.

> Đây là **cùng một cái bẫy** với đề I01 (xem `../I01_Bo_chia_so_nguyen_8bit_cho_4bit_theo_thuat_toan_khoi_phuc/03_ARCHITECTURE/fsm.md` §4). Hai đề
> khác nhau, cùng một lỗi off-by-one tiềm ẩn — vì cùng một khuôn thuật toán lặp.

## 5. Xử lý trạng thái bất hợp lệ

| Câu hỏi | Trả lời |
|---|---|
| 2 bit → 4 tổ hợp, mấy tổ hợp có tên? | **3.** Mã `2'b11` **không có tên** |
| Có nhánh `default`? | **Có** — dòng 100–103: `state <= S_IDLE; busy <= 1'b0;` |
| `default` có bao giờ chạy? | **Không** trong RTL sim (mã `2'b11` không khả đạt từ bất kỳ cung nào). Nó là lưới an toàn cho `state = 2'b11` hoặc `X` sau khi bật nguồn |
| FF có chân reset không? | **Không** — cả 7 FF là `dfxtp_1` (D-FF trơn). Reset **đồng bộ**, tổng hợp thành logic trước chân `D` |
| Bật nguồn chưa reset thì sao? | `state` có thể là `2'b11` hoặc `X`. Cần **≥ 1 cạnh `clk` với `rst_n=0`**. Nghĩa vụ tầng ngoài |
| Có thể kẹt vô hạn ở `S_ITER` không? | **Không.** `iter` tăng vô điều kiện trong nhánh `else`, và `iter==3` chắc chắn xảy ra sau 4 bước. Không điều kiện nào phụ thuộc dữ liệu — bằng chứng cấu trúc cho INV-3 |

> Với một FSM có **mã thừa**, nhánh `default` **không phải tuỳ chọn** — nó là thứ duy
> nhất bảo đảm mạch không kẹt ở `2'b11` sau khi bật nguồn. Không được xoá vì “code
> coverage báo không tới”.

## 6. FSM sống sót nguyên vẹn dù datapath chết

Đây là quan sát riêng và quan trọng nhất của đề này:

| Phần | Trong RTL | Trong netlist |
|---|---|---|
| `state[1:0]` | 2 FF | ✅ **2 FF** |
| `iter[2:0]` (`ITER_W = $clog2(5) = 3`) | 3 FF | ✅ **3 FF** |
| `busy`, `done` | 2 FF | ✅ **2 FF** |
| `x_reg`, `root_reg`, `rem_reg` | 21 FF | ❌ **0 FF** |

**Vì sao FSM sống:** `state` và `iter` chỉ phụ thuộc `start`, `rst_n`, và chính chúng.
Chúng **không bao giờ** phụ thuộc `qbit`, `root_reg` hay `rem_reg`. Khi xung đột driver
trên `root` làm datapath chết theo dây chuyền, FSM nằm ngoài chuỗi phụ thuộc đó.

**Hệ quả nguy hiểm:** mạch trong netlist vẫn **hành xử đúng về mặt giao thức** — `busy`
lên đúng 4 chu kỳ, `done` phát đúng 1 chu kỳ sau đúng 6 chu kỳ từ `start`. Chỉ có **giá
trị** là sai (`root` luôn bằng 0). Một kiểm thử chỉ nhìn giao thức sẽ **không phát hiện
được gì**.

> 📌 **Bài học kiểm thử:** kiểm giao thức và kiểm giá trị là hai việc khác nhau, và phải
> làm **cả hai**. Testbench I02 viết đúng (có `assert(root === expected)`), nhưng chưa bao
> giờ chạy được. Một ca mô phỏng **gate-level** duy nhất với `x=4` sẽ ra `root=0` thay vì
> `2` và phát hiện ngay — đó là lý do mục `L4-GATE` trong `test_matrix.csv` (hiện
> `CHUA CHAY`) đáng lẽ là hàng rào cuối cùng.

## 7. Đối chiếu FSM với tính chất thuật toán

| Tính chất thuật toán từng bit | Hiện thân trong FSM | Kiểm được bằng |
|---|---|---|
| **Số bước cố định** = `INPUT_W/2` = 4 | `S_ITER` ở lại đúng 4 chu kỳ, thoát theo `iter` | INV-3; ca B-4 ở `corner_cases.md` |
| **Không phải thử dần** (Charter mục 10 cấm) | `qbit` chỉ ảnh hưởng **datapath**, không ảnh hưởng `state`/`iter` | Đọc bảng §4: không hàng nào có `qbit` ở cột điều kiện |
| **Tham số hoá theo `INPUT_W`** | `ITER_W` và điều kiện thoát đều suy từ `ROOT_W` | Mô hình chuẩn: `test_16bit_scaling()` — PASS |
| **Kết quả chỉ hợp lệ sau khi lặp xong** | `S_DONE` tách riêng khỏi `S_ITER` | INV-7 (`done_pulse`) |

Bốn tính chất này đều **đúng và còn nguyên** trong netlist. Phần điều khiển của I02 không
cần sửa gì.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
