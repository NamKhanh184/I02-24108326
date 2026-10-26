# I02 · Phần điều khiển (Control)

---

## 1. Phần điều khiển là thứ **duy nhất** còn sống

Đây là điểm riêng của đề I02, và nó phải được nói thẳng ngay từ đầu:

| Thành phần | FF trong RTL | FF trong netlist | Tỉ lệ sống sót |
|---|---:|---:|---:|
| **Điều khiển** (`state[1:0]`, `iter[2:0]`, `busy`, `done`) | 7 | **7** | **100 %** |
| **Datapath** (`x_reg`, `root_reg`, `rem_reg`) | 21 | **0** | **0 %** |
| **Tổng** | 28 | **7** | 25 % |

Công suất phản ánh đúng điều đó: `power_report.txt` ghi **Sequential 93,7 %** /
Combinational **6,3 %**. Tỉ lệ tổ hợp 6,3 % là chữ ký của một mạch **chỉ còn thanh ghi
trạng thái và bộ đếm** — đối chiếu đề I01 (cùng họ thuật toán, còn nguyên datapath) có
tổ hợp **15,5 %**.

> Nghịch lý đáng ghi nhớ: **phần điều khiển sống sót trọn vẹn chính vì nó không phụ thuộc
> `root`.** `iter` và `state` chỉ phụ thuộc lẫn nhau và phụ thuộc `start`. Khi `root` bị
> nối về hằng 0 và kéo cả datapath chết theo, FSM vẫn chạy đúng — nó vẫn đếm 4 bước, vẫn
> phát `done` sau 6 chu kỳ. **Một mạch có vỏ điều khiển hoàn hảo bọc quanh một khoảng
> trống.**

## 2. Ba cơ chế điều khiển trong RTL

### 2.1 Cơ chế **nạp** — chốt toán hạng đúng một lần

```systemverilog
S_IDLE: begin
    busy <= 1'b0;
    if (start) begin
        x_reg    <= x;        // ← chốt toán hạng
        root_reg <= '0;       // ← xoá trạng thái cũ
        rem_reg  <= '0;
        iter     <= '0;
        busy     <= 1'b1;
        state    <= S_ITER;
    end
end
```

Sau cạnh nạp, cổng `x` **không còn ảnh hưởng gì** — mọi thứ đã nằm trong `x_reg`. Ba lệnh
xoá (`root_reg`, `rem_reg`, `iter`) là thứ bảo đảm phép tính **thứ hai** không mang theo
rác của phép tính thứ nhất.

> ⚠️ Trong netlist, chỉ lệnh `iter <= '0` còn tồn tại. Hai lệnh kia xoá những thanh ghi
> đã bị xoá.

### 2.2 Cơ chế **đếm bước** (loop counter)

```systemverilog
localparam int ITER_W = (ROOT_W <= 1) ? 1 : $clog2(ROOT_W+1);   // = $clog2(5) = 3
...
if (iter == ROOT_W-1) begin        // ROOT_W-1 = 3
    busy  <= 1'b0;
    state <= S_DONE;
end else begin
    iter <= iter + 1'b1;
end
```

`ITER_W = $clog2(ROOT_W+1) = $clog2(5) = 3` — netlist có đúng `iter[0..2]`. **Khớp.**

**Điều kiện dừng chỉ phụ thuộc `iter`**, hoàn toàn không phụ thuộc dữ liệu. Đây chính là
điều Charter mục 10 yêu cầu:

> “Dùng vòng lặp **thử dần** cho dễ — đề cấm, vì nó cho số chu kỳ **thay đổi theo dữ
> liệu**.”

RTL **không** mắc lỗi đó. Đây là điểm thiết kế làm đúng, và nó sống sót nguyên vẹn trong
netlist.

> Cách viết `iter == ROOT_W-1` (dùng localparam) thay vì `iter == 3` (hằng số cứng) là
> điểm cộng: module vẫn đúng khi đổi `INPUT_W`.

### 2.3 Cơ chế **bắt tay ra ngoài** (handshake)

| Tín hiệu | Chiều | Ý nghĩa hợp đồng | Trạng thái |
|---|---|---|---|
| `start` | vào | “Nạp `x` và bắt đầu” | ✅ Chỉ đọc ở `S_IDLE`. Giữ dài → khởi động lại liên tiếp |
| `busy` | ra | “Đang lặp” | ✅ 1 trong đúng 4 chu kỳ lặp |
| `done` | ra | “`root` hợp lệ **ngay chu kỳ này**” | ✅ Xung 1 chu kỳ (`done <= 1'b0;` dòng 64 là mặc định) |
| `root` | ra | Kết quả | 🔴 **hằng `4'h0`** — bắt tay đúng nhưng **dữ liệu rỗng** |

**Không có `ready` đi vào** → không có back-pressure. Tầng ngoài phải chốt `root` đúng
chu kỳ `done=1`.

> 🔴 **Đây là tình huống nguy hiểm nhất về mặt tích hợp:** giao thức bắt tay hoạt động
> **hoàn hảo**. `busy` lên đúng lúc, `done` phát đúng 1 chu kỳ, đúng sau 6 chu kỳ. Một
> tầng ngoài chỉ kiểm giao thức sẽ **không phát hiện được gì bất thường** — nó nhận được
> `root = 0` cho mọi `x` và coi đó là kết quả hợp lệ. Chỉ có checker so giá trị (như
> testbench đã viết) mới bắt được, và testbench thì chưa chạy được.

## 3. Bảng tín hiệu điều khiển và tác dụng lên datapath

| Tín hiệu | Sinh ở đâu | Tác dụng lên datapath | Dòng | Còn trong netlist? |
|---|---|---|---:|:-:|
| `start` (khi ở `S_IDLE`) | cổng vào | Nạp `x_reg`; xoá `root_reg`, `rem_reg`, `iter` | 69–76 | 🟡 chỉ phần `iter` |
| `state == S_ITER` | FF trạng thái | Cho phép: `rem_reg←rem_next`, `root_reg←(root_reg<<1)\|qbit`, `x_reg←x_reg<<2` | 79–84 | 🟡 chỉ phần điều khiển |
| `iter == ROOT_W-1` | so sánh 3 bit | Kết thúc vòng lặp: `busy←0`, `state←S_DONE` | 86–88 | ✅ |
| `qbit` | bộ so sánh 9 bit (datapath) | **Điều khiển ngược datapath**: chọn `rem_next = rem_shift − trial` hay `= rem_shift` | 42–48 | ❌ **bị xoá** |
| `!rst_n` | cổng vào | Xoá toàn bộ thanh ghi (đồng bộ) | 54–62 | ✅ |

> Hàng `qbit` một lần nữa cho thấy đặc trưng của thuật toán số học lặp: **một tín hiệu
> vừa là dữ liệu (một bit của `root`), vừa là điều khiển (chọn nhánh trừ)**. Khi nó biến
> mất, phần điều khiển vẫn chạy — vì `iter` và `state` không bao giờ phụ thuộc nó.

## 4. Quan hệ điều khiển ↔ datapath

```
 ┌──────────────────── ĐIỀU KHIỂN (CÒN SỐNG) ─────────────────────┐
 │                                                                │
 │  start ─▶┌─────────────┐                                       │
 │          │   FSM       │◀──── iter == ROOT_W-1 ────┐           │
 │          │ state[1:0]  │                           │           │
 │          └──┬──────────┘                    ┌──────┴──────┐    │
 │             │                               │  iter[2:0]  │    │
 │             └─ lệnh: NẠP / DỊCH / GIỮ ─────▶│  3 × dfxtp  │    │
 │                       │                     └─────────────┘    │
 └───────────────────────┼────────────────────────────────────────┘
                         │
    ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┼╌╌╌╌ DATAPATH (ĐÃ BỊ XOÁ) ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
    ╎     ┌──────────────┼──────────────┬──────────────┐          ╎
    ╎     ▼              ▼              ▼              ▼          ╎
    ╎ ┌────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐    ╎
    ╎ │ x_reg  │   │ rem_reg  │   │ root_reg │   │ so sánh  │    ╎
    ╎ │  8 bit │   │  9 bit   │   │  4 bit   │   │  + trừ   │    ╎
    ╎ └────────┘   └──────────┘   └────▲─────┘   └────┬─────┘    ╎
    ╎                                  │ qbit         │          ╎
    ╎                                  └──────────────┘          ╎
    ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌

                                             root[3:0] ──▶ 4'h0 🔴
```

## 5. Vì sao FSM cần cả `state` lẫn `iter`

| Phương án | Trạng thái | FF | Nhận xét |
|---|---:|---:|---|
| Tách `state` + `iter` (đang dùng) | 3 + đếm 0…3 | 2 + 3 = **5** | Logic đơn giản, **mở rộng được**: đổi `INPUT_W` thì chỉ `ITER_W` đổi |
| Gộp: mỗi bước lặp là một trạng thái | 3 + 4 = 7 | ⌈log₂7⌉ = **3** | Ít FF hơn 2, nhưng **không mở rộng được**: `INPUT_W=16` sẽ cần 11 trạng thái |
| One-hot 7 trạng thái | 7 | **7** | Nhanh nhất, tốn FF nhất |

Phương án tách là đúng: **trạng thái mô tả *pha*, bộ đếm mô tả *tiến độ***. Đây là điều
kiện để tham số `INPUT_W` có ý nghĩa thật — và mô hình chuẩn đã chứng minh thuật toán
đúng ở cả 16 bit (`test_16bit_scaling()` — PASS).

## 6. Điều cần sửa ở phần điều khiển

**Không có gì.** Đây là kết luận quan trọng: phần điều khiển của I02 **đúng, đầy đủ, và
không cần sửa**.

| Hạng mục | Trạng thái |
|---|---|
| FSM đầy đủ nhánh, có `default` | ✅ |
| Bộ đếm mở rộng được theo `INPUT_W` | ✅ |
| Số chu kỳ cố định, không phụ thuộc dữ liệu | ✅ — đúng yêu cầu Charter mục 10 |
| Bắt tay `start`/`busy`/`done` đúng chuẩn | ✅ |
| Reset đồng bộ, xoá đủ thanh ghi | ✅ |

Toàn bộ lỗi nằm ở **một dòng trong phần khai báo đầu ra** (dòng 59: `root <= '0;`), không
nằm ở phần điều khiển. Bản vá một dòng ở `05_VERIFICATION/known_issues.md` sẽ phục hồi
toàn bộ datapath mà **không cần động tới bất kỳ dòng điều khiển nào**.

> Đây là tin tốt duy nhất của hồ sơ này, và nó đáng được nói rõ: thiệt hại rất lớn
> (74 % thiết kế biến mất) nhưng nguyên nhân rất nhỏ và sửa rất rẻ.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
