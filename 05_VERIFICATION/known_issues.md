# I02 · Lỗi đã biết và phán xử (Known Issues)

> ## ✅ Trạng thái: **ĐÃ ÁP DỤNG** — 2026-09-24
>
> Giảng viên đã duyệt. Bản vá D-1 **đã được đưa vào hồ sơ**, đúng nguyên văn đề xuất
> (xoá một dòng, không thêm gì).
> Nhật ký đầy đủ: [`08_ORIGINAL_SOURCE/PATCHLOG.md`](../08_ORIGINAL_SOURCE/PATCHLOG.md).
>
> | Bản vá | Lỗi | File | Trạng thái |
> |---|---|---|---|
> | P-1 | D-1 `root` có hai driver | `04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv` dòng 59 | ✅ đã áp dụng — xoá `root <= '0;` |
>
> **Kết quả xác minh bằng công cụ thật (iverilog 12.0 · Yosys 0.33 · sky130hd):**
>
> | Bước | Trước khi vá | Sau khi vá |
> |---|---|---|
> | Mô hình chuẩn Python | PASS | PASS (không sửa) |
> | Biên dịch | ❌ `COMPILE_FAIL` — `root Unable to assign to unresolved wires.`, mã thoát 1 | ✅ sạch, mã thoát 0 |
> | Mô phỏng | ❌ chưa bao giờ chạy được | ✅ `I02 RTL TB PASS` tại 795 — 13/13 ca đạt |
> | Quét toàn miền 256 giá trị | — (không chạy được) | ✅ **0 sai / 256** |
> | Tổng hợp | 26 cell · 7 FF · 241,4816 µm² · `assign root = 4'h0;` | ✅ **118 cell · 26 FF · 1122,3264 µm²** · 0 `Driver-driver conflict` |
>
> **Kiểm đếm FF xác nhận chẩn đoán §3:** trước khi vá chỉ có **7** FF — toàn bộ đường dữ
> liệu (`x_reg` 8 + `root_reg` 4 + `rem_reg` 9 = 21 FF) đã bị xoá sạch. Sau khi vá: **26**
> FF, khớp với khai báo RTL (27 bit, Yosys gộp 1). Diện tích tăng ×4,6 **không** phải mạch
> phình ra — số cũ là diện tích của một mạch **không có đường dữ liệu**.
>
> Không có chênh lệch nào giữa bản vá đã soạn và bản vá đã áp dụng.
>
> **Lưu ý:** Phần dưới đây là chẩn đoán lịch sử của phiên bản *trước khi vá*. Các thông
> báo `COMPILE_FAIL`, netlist rỗng và kết luận “RTL chưa bị sửa” mô tả trạng thái cũ,
> không phải trạng thái hiện tại. Kết quả sau vá được tóm tắt ở bảng trên.

---


**Trạng thái mô phỏng RTL: ❌ `COMPILE_FAIL`** — lỗi ở giai đoạn **elaboration**.
**Trạng thái netlist: 🔴 RỖNG** — cổng ra bị nối về hằng số, 74 % thiết kế bị xoá.

---

## 1. Thông báo lỗi — trích **nguyên văn**

### 1.1 Từ `05_VERIFICATION/iverilog_compile.log`

```
runs/I02/work/i02_integer_sqrt.sv:37: sorry: constant selects in always_* processes
                                      are not currently supported (all bits will be included).
runs/I02/work/i02_integer_sqrt.sv:59: error: root Unable to assign to unresolved wires.
1 error(s) during elaboration.
```

`05_VERIFICATION/simulation.log` **rỗng** (BRIEF ghi `(khong co)`) — đúng như mong đợi.

### 1.2 Từ `06_GDSII/synthesis/yosys.log` (dòng 170–173)

```
Warning: Driver-driver conflict for \root [3] between cell $auto$ff.cc:266:slice$134.Q
         and constant 1'0 in i02_integer_sqrt: Resolved using constant.
Warning: Driver-driver conflict for \root [2] ... Resolved using constant.
Warning: Driver-driver conflict for \root [1] ... Resolved using constant.
Warning: Driver-driver conflict for \root [0] ... Resolved using constant.
```

### 1.3 Từ `06_GDSII/synthesis/netlist.v` (dòng 182)

```verilog
assign root = 4'h0;
```

Và cổng vào `x[7:0]` có **0 tham chiếu** trong toàn bộ thân module.

### 1.4 Sửa nguồn tối thiểu đã áp dụng trước đó

```json
{"properties.sv": ["Thay $isunknown(...) bang phep XOR rut gon (1 cho):
                    Icarus khong ho tro he thong ham nay."]}
```

→ **Không liên quan** tới lỗi này. RTL chưa bị sửa gì.

---

## 2. Phán xử

> ## 🔨 **LỖI NẰM TRONG DUT** — một dòng, hậu quả toàn cục
>
> | Tầng | Có lỗi? | Mức độ |
> |---|:-:|---|
> | **DUT (RTL)** | ✅ **CÓ** | **Xung đột driver trên cổng ra `root`** — dòng 51 và dòng 59 cùng lái `root` |
> | Mô hình chuẩn (Python) | ❌ không | `python_reference_run.log` = PASS: 256 ca vét cạn + 10 000 random + kiểm 16 bit |
> | Testbench | ⚠️ **thiếu 2 ca**, nhưng **không** gây lỗi này | Thiếu `x=100`, `x=99` của Charter mục 8 — xem §7 |
> | Giới hạn công cụ | ❌ **không** | Cả Icarus lẫn Yosys đều **phát hiện đúng**. Khác biệt chỉ ở mức phản ứng: Icarus **dừng**, Yosys **cảnh báo rồi tiếp tục** |
>
> **Nguyên nhân gốc: đúng MỘT dòng mã.** Hậu quả: 20/27 flip-flop bị xoá, cổng vào `x`
> trở nên vô dụng, và mọi số liệu tổng hợp / STA / công suất trở nên vô nghĩa.

---

## 3. Lỗi D-1 — cổng ra `root` có **hai driver**

### 3.1 Hai đoạn mã xung đột

```systemverilog
    output logic [INPUT_W/2-1:0] root,      // dòng 9 — khai báo cổng ra kiểu `logic`
    ...
    assign root = root_reg;                 // ★ DRIVER 1 — phép gán LIÊN TỤC (dòng 51)
    ...
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_reg    <= '0;
            root_reg <= '0;
            rem_reg  <= '0;
            iter     <= '0;
            root     <= '0;                 // ★ DRIVER 2 — phép gán THỦ TỤC (dòng 59)
            busy     <= 1'b0;
```

### 3.2 Vì sao sai — quy tắc ngôn ngữ

Trong SystemVerilog, một tín hiệu kiểu `logic` được phép có **đúng một** trong hai loại
driver:

| Loại driver | Cú pháp | Bản chất phần cứng |
|---|---|---|
| Liên tục (continuous) | `assign root = ...;` | Dây nối / logic tổ hợp |
| Thủ tục (procedural) | `root <= ...;` trong `always_ff` | Đầu ra flip-flop |

Hai loại này **không thể cùng tồn tại** trên một tín hiệu — đó là hai mạch vật lý khác
nhau cùng lái một nút. Icarus phát biểu đúng:

```
error: root Unable to assign to unresolved wires.
```

Từ “unresolved wires” nghĩa là: `root` đã bị phép `assign` biến thành **wire**, và wire
không thể là đích của phép gán thủ tục.

### 3.3 Vì sao dòng 59 **hoàn toàn thừa**

Đây là điểm mấu chốt để hiểu bản chất lỗi:

```systemverilog
root_reg <= '0;        // dòng 57 — đã xoá thanh ghi
root     <= '0;        // dòng 59 — THỪA, vì assign root = root_reg đã lo việc này
```

`root` **chỉ là một dây nối** từ `root_reg`. Khi `root_reg` được xoá về 0 ở dòng 57 thì
`root` **tự động** bằng 0. Dòng 59 không thêm giá trị gì — nó chỉ tạo ra xung đột.

> 📌 **Đây là lỗi của thói quen, không phải của hiểu biết.** Người viết có thói quen tốt
> “reset mọi thứ trong nhánh reset”, và áp dụng thói quen đó cho cả cổng ra — quên rằng
> cổng ra này đã được lái bằng `assign`. Thói quen đúng, áp dụng sai chỗ.

### 3.4 Hai công cụ, hai phản ứng — và hậu quả

| Công cụ | Phản ứng | Kết quả |
|---|---|---|
| **Icarus Verilog 12.0** | `error:` → **dừng elaboration** | Không sinh file thực thi. **Trung thực và đúng đắn** |
| **Yosys 0.33** | `Warning:` → **tiếp tục, tự giải quyết bằng hằng số** | Sinh netlist trong đó `root` bị nối chết về `4'h0` |

Yosys chọn hằng `1'0` thay vì chọn `root_reg`. Một khi `root` là hằng, không ai đọc
`root_reg` nữa → `root_reg` chết → `trial` (phụ thuộc `root_reg`) chết → `qbit`,
`rem_next` chết → `rem_reg`, `rem_shift`, `next_pair`, `x_reg` chết theo dây chuyền.

**Hiệu ứng domino từ một dòng:**

```
   root <= '0  (dòng 59)
        │
        ▼  xung đột với assign root = root_reg
   Yosys chọn hằng: assign root = 4'h0
        │
        ▼  không ai đọc root_reg
   root_reg bị xoá        (−4 FF)
        │
        ▼  trial = (root_reg<<2)|1  không còn nguồn
   bộ so sánh + trừ 9 bit bị xoá   (−~30 cell)
        │
        ▼  qbit, rem_next không còn ai tạo
   rem_reg bị xoá         (−9 FF)
        │
        ▼  rem_shift không còn ai đọc → next_pair chết
   x_reg bị xoá           (−8 FF)
        │
        ▼  x_reg không còn ai nạp
   CỔNG VÀO x[7:0] KHÔNG ĐƯỢC DÙNG  (0 tham chiếu trong netlist)
```

**Tổng thiệt hại: 21 FF khai báo → 0 FF; 27 bit thanh ghi → còn 7.**

### 3.5 Bản vá tối thiểu — **XOÁ MỘT DÒNG**

```diff
--- a/04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv
+++ b/04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv
@@ -53,7 +53,6 @@
     always_ff @(posedge clk) begin
         if (!rst_n) begin
             x_reg    <= '0;
             root_reg <= '0;
             rem_reg  <= '0;
             iter     <= '0;
-            root     <= '0;
             busy     <= 1'b0;
             done     <= 1'b0;
             state    <= S_IDLE;
```

**Một dòng bị xoá. Không thêm dòng nào. Không đổi hành vi.**

Sau bản vá: `root` chỉ còn một driver duy nhất (`assign root = root_reg;`), và vì dòng 57
đã xoá `root_reg` trong reset, hành vi reset của `root` **giữ nguyên hoàn toàn**.

### 3.6 Phương án thay thế (KHÔNG khuyến nghị)

Nếu vì lý do nào đó muốn giữ `root` là thanh ghi thật:

```diff
-    assign root = root_reg;
+    // root trở thành thanh ghi thủ tục — phải gán ở MỌI nhánh
```

…nhưng khi đó phải thêm `root <= (root_reg << 1) | qbit;` vào `S_ITER` và giữ đồng bộ
với `root_reg` — tức **nhân đôi thanh ghi** (+4 FF) mà không được lợi gì. **Không nên.**

---

## 4. Lỗi D-2 — hệ quả: netlist không phải bộ khai căn

Đây không phải lỗi độc lập mà là **hệ quả trực tiếp** của D-1. Ghi riêng vì nó là thứ
phải báo cáo với giảng viên.

### 4.1 Bằng chứng

| Dấu hiệu | Bằng chứng | Kết luận |
|---|---|---|
| Cổng ra nối chết | `netlist.v:182`: `assign root = 4'h0;` | `root` luôn bằng 0 với **mọi** `x` |
| Cổng vào vô dụng | `x[` xuất hiện **0 lần** trong thân module netlist | Đầu vào không ảnh hưởng gì tới đầu ra |
| Thiếu flip-flop | `synth_stat.txt`: **7** FF; Charter mục 10: **18–22** | Thiếu 11–15 FF |
| Thiếu cell số học | `synth_stat.txt`: **0** cell `xor`/`xnor` | Không có bộ so sánh–trừ nào |
| Đường tới hạn quá ngắn | `timing_report_max.txt`: 4 cell, logic thật **0,46 ns** | So I01 (cùng họ): **1,24 ns** |

7 flip-flop còn lại: `iter[0..2]`, `state[0..1]`, `busy`, `done` — **toàn bộ là điều
khiển, không một bit datapath nào**.

### 4.2 Vì sao đây là tình huống nguy hiểm

> 🔴 **Mạch trong netlist hành xử ĐÚNG về mặt giao thức.**
> `busy` lên 1 đúng 4 chu kỳ. `done` phát xung đúng 1 chu kỳ, đúng sau 6 chu kỳ từ
> `start`. Một tầng ngoài chỉ kiểm giao thức sẽ **không phát hiện được gì bất thường** —
> nó nhận `root = 0` cho mọi `x` và coi đó là kết quả hợp lệ.
>
> Chỉ có checker **so giá trị** mới bắt được. Testbench I02 **có** viết checker đúng
> (`assert(root === expected)`) nhưng chưa bao giờ chạy được.

### 4.3 Hàng rào cuối cùng đã bị bỏ qua

`05_VERIFICATION/test_matrix.csv` ghi `L4-GATE, ..., Mo phong gate-level tren netlist,
CHUA CHAY, -`.

**Một ca mô phỏng gate-level duy nhất với `x = 4` sẽ ra `root = 0` thay vì `2` và phát
hiện lỗi ngay lập tức.** Mô phỏng gate-level là bước **duy nhất** trong toàn bộ luồng có
khả năng phát hiện việc logic bị tổng hợp xoá — mô phỏng RTL không thể (nó đọc RTL, không
đọc netlist), và STA/công suất càng không thể (chúng chỉ đo cái đang có).

---

## 5. Cảnh báo phụ — `sorry: constant selects` (dòng 37)

```
i02_integer_sqrt.sv:37: sorry: constant selects in always_* processes are not
                        currently supported (all bits will be included).
```

Dòng 37–38:

```systemverilog
always_comb begin
    next_pair = x_reg[INPUT_W-1 -: 2];     // ← phép chọn khoảng có chỉ số cố định
```

| Câu hỏi | Trả lời |
|---|---|
| Có phải lỗi không? | **Không.** Từ khoá là `sorry:` (hạn chế công cụ), không phải `error:` |
| Icarus đang nói gì? | Nó không thu hẹp danh sách nhạy cảm theo từng bit mà **đưa cả `x_reg` vào** |
| Có ảnh hưởng kết quả không? | **Không.** Danh sách nhạy cảm rộng hơn cần thiết chỉ khiến khối tính lại nhiều hơn. Với `always_comb`, ngữ nghĩa vốn đã là “tính lại khi bất cứ đầu vào nào đổi” |
| Yosys có báo gì không? | Không có cảnh báo tương ứng |
| Đề I01 có cảnh báo tương tự không? | **Có** — cùng loại, ở dòng 34, và mô phỏng I01 vẫn **PASS**. Đó là bằng chứng trực tiếp rằng cảnh báo này vô hại |

**Kết luận: bỏ qua. Không sửa.**

---

## 6. Vì sao **không** phải lỗi mô hình chuẩn

Mô hình chuẩn `05_VERIFICATION/golden_model/reference_model.py` được kiểm rất kỹ và
**PASS toàn bộ**:

| Hàm test | Phạm vi | Kết quả |
|---|---|---|
| `test_full_domain()` | **Cả 256 giá trị** `x`, kiểm `root² ≤ x < (root+1)²` và `len(trace)==4` | ✅ PASS |
| `test_boundaries()` | 23 giá trị biên gồm `0,1,2,3,4,8,9,15,16,24,25,26,63,64,65,80,81,82,224,225,226,254,255` | ✅ PASS |
| `test_perfect_squares()` | 16 số chính phương `k²`, `k ∈ [0,16)` | ✅ PASS |
| `test_cycle_count()` | `len(trace) == 4` với 8 giá trị | ✅ PASS |
| `test_trial_recurrence()` | `trial == 4·root_trước + 1` ở mọi bước, với `x = 0xa5` → `root = 12` | ✅ PASS |
| `test_16bit_scaling()` | `width=16` → `len(trace) == 8` | ✅ PASS |
| `test_random()` | 10 000 ca ngẫu nhiên (seed 2026), so với `math.isqrt` | ✅ PASS |

Thuật toán **đã được hiểu và mô tả đúng**. Lỗi hoàn toàn nằm ở khâu chuyển sang RTL, và
chỉ ở một dòng.

---

## 7. Khuyết tật của testbench — không gây lỗi, nhưng phải sửa

Testbench có **13 ca**, mỗi ca có assertion so `root` với giá trị kỳ vọng — chất lượng
tốt. Nhưng:

| Khuyết tật | Chi tiết |
|---|---|
| **Thiếu 2/5 ca Charter mục 8** | Không có `x = 100` (→ 10) và `x = 99` (→ 9) |
| Không có ca nào cho **mẫu `root` xen kẽ** | Mọi `root` được kiểm đều thuộc `{0,1,2,3,4,7,8,15}` = `{0000,0001,0010,0011,0100,0111,1000,1111}`. **Không mẫu nào dạng `1010` hay `1001`** |
| Không đếm số chu kỳ | Dùng `wait(done)` nên không biết đã trôi qua mấy chu kỳ. Charter mục 2 câu 1 yêu cầu “kiểm chứng trên waveform” |
| Không quét vét cạn | 13/256 = **5,1 %**, trong khi mô hình chuẩn quét hết 256 |

### Vì sao `x = 100` **bắt buộc** phải có

Trong phép tính `√100`, bộ so sánh rơi vào trường hợp **`rem_shift == trial`** tại **hai**
bước (`1 == 1` ở bước 1 và `9 == 9` ở bước 3):

| Nếu RTL viết | `√100` cho ra | Đúng? |
|---|---:|:-:|
| `rem_shift >= trial` (đúng) | **10** | ✅ |
| `rem_shift > trial` (sai) | **8** | ❌ |

Diễn biến từng chu kỳ ở `03_ARCHITECTURE/timing_diagram.md` §3.

### Bổ sung tối thiểu

```systemverilog
run_case(8'd99, 9);      // ca Charter muc 8 — mau root = 1001
run_case(8'd100,10);     // ca Charter muc 8 — mau root = 1010, kiem ranh gioi >=
```

Và mạnh hơn — thay 13 ca cố định bằng quét vét cạn với checker tính chất:

```systemverilog
integer xv;
for (xv = 0; xv < 256; xv = xv + 1) begin
    @(negedge clk); x = xv[7:0]; start = 1'b1;
    @(negedge clk); start = 1'b0;
    wait(done);
    assert (root*root <= xv && xv < (root+1)*(root+1))
        else $fatal(1, "sqrt sai: x=%0d root=%0d", xv, root);
end
```

---

## 8. Giá trị dạy học

| Lỗi | Vì sao đáng dạy |
|---|---|
| **D-1** (xung đột driver) | Bẫy kinh điển của SystemVerilog. Dạy được: (a) một `logic` chỉ được có **một loại** driver; (b) cổng ra đã lái bằng `assign` thì **không** gán lại trong `always_ff`; (c) thói quen “reset mọi thứ” phải dừng ở ranh giới đó |
| **D-2** (netlist rỗng) | 🔴 **Bài học lớn nhất của cả gói.** Dạy được: một chuỗi công cụ có thể cho ra **toàn dấu ✅** (tổng hợp PASS, STA PASS, công suất có số) trong khi sản phẩm hoàn toàn rỗng. Ba kỹ thuật chẩn đoán rút ra: `grep "assign" netlist.v` · đếm FF đối chiếu Charter mục 10 · `grep "Warning" yosys.log` |
| **Yosys `Warning` vs Icarus `error`** | Dạy được: hai công cụ có mức nghiêm ngặt khác nhau với **cùng một lỗi**. Không bao giờ chỉ tin một công cụ. Nên cấu hình Yosys coi `Driver-driver conflict` là lỗi chặn |
| **Mô phỏng gate-level bị bỏ qua** | Dạy được vai trò **không thể thay thế** của bước này: nó là bước **duy nhất** phát hiện được logic bị tổng hợp xoá |
| **Testbench thiếu ca biên `>=`** | Dạy được cách thiết kế ca theo **mẫu bit của kết quả**, không chỉ theo giá trị. `x=100` và `x=99` không phải ca ngẫu nhiên — chúng nhắm thẳng vào ranh giới `>` / `>=` |

---

## 9. Thứ tự vá đề xuất và tiêu chí nghiệm thu

| Bước | Việc | Nghiệm thu |
|---:|---|---|
| 1 | **Xoá dòng 59** (`root <= '0;`) | `iverilog -g2012` chạy sạch; `simulation.log` có nội dung |
| 2 | Chạy lại mô phỏng RTL với 13 ca hiện có | `I02 RTL TB PASS` |
| 3 | Thêm ca `x=99`, `x=100` (Charter mục 8) | Cả hai PASS; nếu `x=100` ra `8` thì có lỗi `>` / `>=` |
| 4 | Thêm đếm chu kỳ (ca B-4) | `cyc == 6` với mọi `x` |
| 5 | Quét **vét cạn 256 ca** với checker tính chất | PASS toàn miền, khớp `reference_model.py` |
| 6 | **Chạy lại tổng hợp** | 🔴 **`assign root = 4'h0;` BIẾN MẤT** khỏi netlist · **không còn** `Driver-driver conflict` trong `yosys.log` · FF tăng từ **7** lên vùng **18–22** (Charter mục 10) · xuất hiện cell `xor`/`xnor` |
| 7 | Kiểm cổng `x` đã được dùng | `x[` xuất hiện trong thân module netlist |
| 8 | **Chạy mô phỏng gate-level** (`L4-GATE`) | Netlist cho `root` đúng với mọi `x` — đây là hàng rào đáng lẽ đã bắt được lỗi |
| 9 | Chạy lại STA | Đường tới hạn **dự kiến** chuyển sang chuỗi `rem_reg → so sánh–trừ 9 bit → rem_reg`, logic thật dự kiến **> 1,24 ns** (đối chiếu I01). Phải kiểm, không được đoán |
| 10 | Cập nhật mọi tài liệu có trích số liệu | Thay 26 cell / 7 FF / 241,4816 µm² / 1,46 ns / 3,22e-05 W bằng số mới |

---

## 10. Tuyên bố bắt buộc

> ✅ **CẬP NHẬT 2026-09-24 — bản vá ĐÃ ĐƯỢC ÁP DỤNG.** Xem khối trạng thái ở **đầu tài
> liệu** và `08_ORIGINAL_SOURCE/PATCHLOG.md`. Đoạn dưới đây giữ lại để thấy hồ sơ đã ở
> trạng thái nào **trước** khi vá.
>
> ~~Bản vá trong tài liệu này CHƯA được áp dụng.~~
> `04_IMPLEMENTATION/rtl/i02_integer_sqrt.sv` ~~vẫn là bản gốc của thầy, kể cả dòng 59~~ →
> **dòng 59 đã được xoá**; giảng viên **đã duyệt**. Bản gốc nằm nguyên vẹn ở
> `08_ORIGINAL_SOURCE/rtl/`.
>
> 🔴 Số liệu tổng hợp / STA / công suất **cũ** (26 cell · 7 flip-flop · 241,4816 µm² ·
> arrival 1,46 ns · slack 8,40 ns · 3,22e-05 W) là số liệu của một netlist **KHÔNG CHỨA
> đường dữ liệu khai căn** — mô tả một bộ đếm 3 bit kèm FSM 2 bit. **Không được trích dẫn**.
>
> ✅ Số đo lại sau khi vá: **118 cell · 26 FF · 1122,3264 µm²**. Số liệu STA và công suất
> trong `06_GDSII/` **vẫn là số cũ** cho tới khi luồng được chạy lại — chỉ số tổng hợp ở
> trên là đã đo trên mã đã vá.
>
> Sau khi vá và chạy lại, toàn bộ các file sau phải được cập nhật số liệu:
> `02_SPECIFICATION/parameters.md` · `02_SPECIFICATION/timing.md` ·
> `03_ARCHITECTURE/block_diagram.md` · `03_ARCHITECTURE/tradeoff.md` ·
> `06_GDSII/physical_report.md` · `07_TRACEABILITY/RTM.csv` ·
> `implementation-notes_I02.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
