# I02 · Nhật ký vá (PATCHLOG)

**Ngày vá:** 2026-09-24 · **Người duyệt:** giảng viên đã duyệt áp dụng toàn bộ bản vá

## 1. Tóm tắt

| # | File | Loại lỗi | Mô tả một dòng | Ảnh hưởng số liệu |
|---|---|---|---|---|
| P-1 | `04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv` | Lỗi thiết kế | Xoá dòng thừa `root <= '0;` — cổng ra `root` có **hai driver** (D-1) | Có — phải chạy lại synth/STA |

Chỉ **một** thay đổi, **xoá một dòng**. Không đổi giao diện module, không đổi hành vi reset.

## 2. Chi tiết bản vá

### P-1 — Cổng ra `root` có hai driver

**File:** `04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv` · **Dòng:** 59 (bản gốc)
· **Phán xử:** **lỗi ở DUT**

**Trước:**
```systemverilog
    assign root = root_reg;                 // <- DRIVER 1 (lien tuc), dong 51

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_reg    <= '0;
            root_reg <= '0;                 // dong 56 - da xoa thanh ghi that
            rem_reg  <= '0;
            iter     <= '0;
            root     <= '0;                 // <- DRIVER 2 (thu tuc), dong 59  THUA
            busy     <= 1'b0;
```

**Sau:**
```systemverilog
            iter     <= '0;
            // "root <= '0;" removed: root already has ONE driver, the
            // continuous assignment "assign root = root_reg;". Driving it a
            // second time from this always_ff made root an unresolved net;
            // iverilog rejected it and Yosys resolved the conflict by tying
            // root to constant 0, which killed root_reg and the whole datapath.
            // root_reg is cleared just above, so reset behaviour is unchanged.
            busy     <= 1'b0;
```

**Vì sao:** `assign root = root_reg;` đã biến `root` thành một **dây nối**. Trong
SystemVerilog, một biến/dây không được vừa lái bằng phép gán **liên tục** vừa lái bằng phép
gán **thủ tục** trong `always_ff`. Dòng 59 không thêm giá trị gì: `root_reg` đã được xoá
về 0 ngay ở dòng 56, nên `root` **tự động** bằng 0 qua dây nối. Nó chỉ tạo ra xung đột.

**Vì sao nó phá huỷ toàn bộ mạch — chuỗi nhân quả:**

```
   root <= '0        (dong 59)  xung dot voi  assign root = root_reg  (dong 51)
        |
        v  Yosys giai quyet bang HANG SO, chon 1'0 thay vi chon root_reg
   assign root = 4'h0;          (netlist.v:182)
        |
        v  khong ai doc root_reg nua
   root_reg bi xoa              (-4 FF)
        |
        v  trial = (root_reg<<2)|1  khong con nguon
   trial, qbit, rem_next, rem_reg  chet theo
        |
        v
   TOAN BO DUONG DU LIEU BI XOA - root = 0 voi MOI gia tri x
```

**Hai công cụ, hai phản ứng — điểm dạy học:**

| Công cụ | Phản ứng | Hậu quả |
|---|---|---|
| Icarus Verilog 12.0 `-g2012` | ❌ `error: root Unable to assign to unresolved wires.` → **COMPILE_FAIL** | Dừng ngay, không sinh được file mô phỏng |
| Yosys 0.33 | ⚠️ `Warning: Driver-driver conflict for \root [3..0] ... Resolved using constant.` → **tiếp tục** | Sinh ra một netlist trông rất bình thường nhưng `root` nối chết về `4'h0` |

Yosys **cảnh báo đủ 4 lần**, mỗi bit một lần, trước khi bất cứ thứ gì hỏng.

**Hệ quả:** `root` chỉ còn một driver duy nhất. Vì dòng 56 đã xoá `root_reg` trong reset,
**hành vi reset của `root` giữ nguyên hoàn toàn**. Phương án thay thế (biến `root` thành
thanh ghi thủ tục thật) đã bị bác bỏ theo đúng khuyến nghị của known_issues §6: nó đòi
**nhân đôi thanh ghi** (+4 FF) mà không được lợi gì.

## 3. Kết quả xác minh sau khi vá

| Bước | Trước khi vá | Sau khi vá |
|---|---|---|
| Mô hình chuẩn Python | `I02 golden reference PASS` (mã thoát 0) | `I02 golden reference PASS` (mã thoát 0) — **không sửa** |
| Biên dịch | ❌ `COMPILE_FAIL`, mã thoát 1 — `i02_integer_sqrt.sv:59: error: root Unable to assign to unresolved wires.` | ✅ sạch, mã thoát 0 |
| Mô phỏng | ❌ chưa bao giờ chạy được | ✅ `I02 RTL TB PASS`, `$finish` tại 795 — 13/13 ca đạt |
| Quét toàn miền 256 giá trị | — (không chạy được) | ✅ **0 sai / 256** (`floor(sqrt(x))` đúng với mọi `x`) |
| Tổng hợp | 26 cell · 7 FF · 241,4816 µm² · `assign root = 4'h0;` (**mạch rỗng**) | ✅ **118 cell · 26 FF · 1122,3264 µm²** · 0 ERROR · 0 `Driver-driver conflict` · `root` **không còn** nối hằng |

Chi tiết cell sau khi vá:

```
   Number of cells:                118
     sky130_fd_sc_hd__a21boi_0       1
     sky130_fd_sc_hd__a21oi_1        4
     sky130_fd_sc_hd__a222oi_1       6
     sky130_fd_sc_hd__a22oi_1        7
     sky130_fd_sc_hd__and2_0         7
     sky130_fd_sc_hd__clkinv_1       4
     sky130_fd_sc_hd__dfxtp_1       26
     sky130_fd_sc_hd__lpflow_isobufsrc_1     15
     sky130_fd_sc_hd__maj3_1         4
     sky130_fd_sc_hd__mux2i_1        4
     sky130_fd_sc_hd__nand2_1       11
     sky130_fd_sc_hd__nand2b_1       1
     sky130_fd_sc_hd__nor2_1         6
     sky130_fd_sc_hd__nor3_1         2
     sky130_fd_sc_hd__nor3b_1        1
     sky130_fd_sc_hd__nor4b_1        1
     sky130_fd_sc_hd__o21a_1         1
     sky130_fd_sc_hd__o21ai_0        6
     sky130_fd_sc_hd__o21bai_1       1
     sky130_fd_sc_hd__xnor2_1        9
     sky130_fd_sc_hd__xor2_1         1

   Chip area for module '\i02_integer_sqrt': 1122.326400
```

**Kiểm đếm FF (quy trình rẻ tiền, hiệu quả):** 26 FF khớp với khai báo RTL —
`x_reg` (8) + `root_reg` (4) + `rem_reg` (9) + `iter` (2) + `busy`, `done` (2) +
`state` (2) = 27, Yosys tối ưu còn 26. Trước khi vá chỉ có **7** FF: đúng bằng
`busy + done + state` (4) cộng một phần `iter` — toàn bộ đường dữ liệu (`x_reg`,
`root_reg`, `rem_reg` = 21 FF) đã bị xoá sạch.

Diện tích tăng 241,48 → 1122,33 µm² (×4,6) không phải "mạch phình ra": số cũ là diện tích
của một mạch **không có đường dữ liệu**.

Lệnh đã chạy để xác minh:

```bash
D=<thu muc de I02>
LIB=<.../sky130hd.lib>
T=$(mktemp -d)

python3 $D/05_VERIFICATION/golden_model/reference_model.py

iverilog -g2012 -o $T/sim.vvp \
   $D/04_IMPLEMENTATION/rtl/*.sv \
   $D/05_VERIFICATION/testbench/*.sv
cd $T && vvp sim.vvp | tail -20

yosys -Q -p "read_verilog -sv $D/04_IMPLEMENTATION/rtl/*.sv; \
   hierarchy -check -top i02_integer_sqrt; proc; opt; fsm; opt; memory; opt; techmap; opt; \
   dfflibmap -liberty $LIB; abc -liberty $LIB; setundef -zero; splitnets; opt_clean -purge; \
   stat -liberty $LIB"
```

(`05_VERIFICATION/golden_model/` không có file `.sv`.)

## 4. Cách quay lui

```bash
cp 08_ORIGINAL_SOURCE/rtl/*            04_IMPLEMENTATION/rtl/
cp 08_ORIGINAL_SOURCE/golden_model/*   05_VERIFICATION/golden_model/
cp 08_ORIGINAL_SOURCE/testbench/*      05_VERIFICATION/testbench/
```

## 5. Việc còn lại

1. **Cảnh báo còn lại của Icarus** (không phải lỗi, không chặn gì):
   ```
   i02_integer_sqrt.sv:37: sorry: constant selects in always_* processes are not
   currently supported (all bits will be included).
   ```
   Đây là giới hạn của Icarus khi xây **danh sách nhạy** cho `x_reg[INPUT_W-1 -: 2]` trong
   `always_comb`: nó làm khối nhạy với **toàn bộ** `x_reg` thay vì 2 bit. Vì `always_comb`
   vốn phải nhạy với mọi tín hiệu đọc trong khối, việc "thêm bit vào danh sách nhạy"
   **không làm sai kết quả** — đã xác nhận bằng quét đủ 256 giá trị (0 sai). **Cố ý không
   sửa**: đổi cú pháp chỉ để chiều một cảnh báo của một công cụ sẽ vi phạm nguyên tắc "sửa
   tối thiểu, mỗi thay đổi truy được về một lỗi cụ thể".
2. Testbench của hồ sơ chỉ có 13 ca. Quét đủ 256 giá trị đã được chạy bằng testbench tạm
   **ngoài hồ sơ** (kết quả 0/256 sai). Nếu muốn con số này nằm trong hồ sơ thì phải thêm
   vòng quét vào `i02_integer_sqrt_tb.sv` — chưa làm, để giữ testbench đúng nguyên trạng
   ngoài phạm vi lỗi đã phán xử.

## 6. Áp dụng lại (2026-09-24)

**Lý do:** một bước sinh tài liệu tự động (`generate2.py`) đã chép mã nguồn gốc từ
`runs/<mã>/work/` đè lên `04_IMPLEMENTATION/rtl/`, `05_VERIFICATION/golden_model/` và
`05_VERIFICATION/testbench/`, làm **mất bản vá**. Lỗi của bộ sinh đã được sửa; trước khi áp
dụng lại, cả bốn file mã nguồn đã được so sánh và xác nhận **trùng khớp từng byte** với
`08_ORIGINAL_SOURCE/` (tức đã quay về trạng thái chưa vá — dòng `root <= '0;` đã quay lại).

**Đã áp dụng lại:** bản vá duy nhất **P-1** — xoá `root <= '0;` trong nhánh reset của
`always_ff`, thay bằng khối chú thích giải thích. Không có thay đổi nào khác; `golden_model/`
và `testbench/` không cần sửa (lần vá đầu cũng không sửa chúng).

**Kết quả xác minh lần này** (chạy lại bằng đúng lệnh ở §3):

| Bước | Kết quả |
|---|---|
| Mô hình chuẩn Python | ✅ `I02 golden reference PASS`, mã thoát 0 |
| Biên dịch `iverilog -g2012` | ✅ mã thoát 0; **hết** lỗi `Unable to assign to unresolved wires`. Chỉ còn cảnh báo `sorry: constant selects...` dòng 37 — đúng như §5.1, không chặn gì |
| Mô phỏng `vvp` | ✅ `I02 RTL TB PASS`, `$finish` tại **795**, 13/13 ca đạt; không `ERROR`/`FATAL`/`mismatch` |
| Quét toàn miền 256 giá trị | ✅ `I02 SWEEP: wrong = 0 / 256` (testbench tạm ngoài hồ sơ, như lần đầu) |
| Tổng hợp Yosys | ✅ mã thoát 0, 0 ERROR, **0 `Driver-driver conflict`** |

```
   Number of cells:                118
     sky130_fd_sc_hd__dfxtp_1       26
   Chip area for module '\i02_integer_sqrt': 1122.326400
```

**Đối chiếu §3:** 118 cell · 26 FF · 1122,3264 µm² — **khớp tuyệt đối** với con số sau lần
vá đầu (118 / 26 / 1122,3264). Bảng phân loại cell cũng trùng từng dòng với danh sách ở §3.
`$finish` tại 795 và kết quả quét 0/256 cũng khớp. Đường dữ liệu (`x_reg`, `root_reg`,
`rem_reg`) đã sống lại: 26 FF so với 7 FF của bản hỏng.

**Việc còn lại ở §5 vẫn giữ nguyên** — cảnh báo `sorry:` của Icarus vẫn cố ý không sửa, và
vòng quét 256 giá trị vẫn nằm ngoài testbench của hồ sơ.
