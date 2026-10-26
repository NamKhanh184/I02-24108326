# I02 · Ca biên và lý do chọn (Corner Cases)

---

> **Tình trạng kiểm thử RTL: `COMPILE_FAIL`** (`test_matrix.csv`: TC-001, TC-002 =
> `XEM known_issues.md`). Không ca nào dưới đây đã chạy được trên RTL. Cột “có trong TB”
> chỉ nói testbench *có viết* ca đó, **không** nói ca đó đã PASS.

## 1. Testbench thật có gì

`05_VERIFICATION/testbench/i02_integer_sqrt_tb.sv` liệt kê **13 ca**, mỗi ca có **1
assertion** so `root` với giá trị kỳ vọng:

| # | `x` | kỳ vọng | Ý nghĩa kỹ thuật |
|---:|---:|---:|---|
| 1 | 0 | 0 | Biên dưới tuyệt đối |
| 2 | 1 | 1 | Số chính phương nhỏ nhất khác 0 |
| 3 | 2 | 1 | `k²+1` với `k=1` |
| 4 | 3 | 1 | `k²−1` với `k=2` |
| 5 | 4 | 2 | Số chính phương `2²` |
| 6 | 8 | 2 | Giữa `2²` và `3²` |
| 7 | 9 | 3 | Số chính phương `3²` |
| 8 | 15 | 3 | `k²−1` với `k=4` |
| 9 | 16 | 4 | Số chính phương `4²` |
| 10 | 63 | 7 | `k²−1` với `k=8` — **biên chuyển bit cao** |
| 11 | 64 | 8 | Số chính phương `8²` — **bit 3 của `root` lần đầu bằng 1** |
| 12 | 65 | 8 | `k²+1` với `k=8` |
| 13 | 255 | 15 | **Biên trên tuyệt đối** |

**Chất lượng thiết kế ca: tốt.** Bộ ca này phủ rất bài bản cụm ba
`(k²−1, k², k²+1)` — đúng chỗ mà lỗi off-by-one trong phép so sánh `>=` sẽ lộ ra.

### ⚠️ Nhưng **thiếu 2/5 ca bắt buộc của Charter mục 8**

| Ca Charter yêu cầu | Có trong TB? | Ghi chú |
|---|:-:|---|
| `x = 0` | ✅ | ca 1 |
| `x = 1` | ✅ | ca 2 |
| `x = 255` (kết quả 15) | ✅ | ca 13 |
| **`x = 100` (kết quả 10)** | ❌ **THIẾU** | — |
| **`x = 99` (kết quả 9)** | ❌ **THIẾU** | — |

Hai ca thiếu này **không** phải ngẫu nhiên vô hại. Cặp `(99, 100)` là cụm
`(k²−1, k²)` với `k = 10` — và `10 = 4'b1010` là giá trị `root` duy nhất trong bộ ca yêu
cầu có **mẫu bit xen kẽ**. Mọi giá trị `root` mà TB hiện kiểm đều là
`0, 1, 2, 3, 4, 7, 8, 15` — tức `0000, 0001, 0010, 0011, 0100, 0111, 1000, 1111`. **Không
ca nào cho `root` dạng `1010` hay `1001`.** Nếu logic dịch `root_reg <= (root_reg << 1) |
qbit` bị sai ở một vị trí bit cụ thể, các mẫu “toàn 0 / toàn 1 / một khối liền” có thể
vẫn đúng trong khi mẫu xen kẽ thì sai.

> **Kết luận: phải bổ sung `x=99` và `x=100` — đây là yêu cầu bắt buộc của Charter mục 8,
> không phải tuỳ chọn.**

## 2. Phân loại ca theo tiêu chí kỹ thuật **riêng của đề này**

Với thuật toán khai căn từng bit, tiêu chí có ý nghĩa nhất là **mẫu bit của `root`** —
vì đó chính là chuỗi `qbit` mà 4 bước lặp sinh ra.

| Lớp | Mẫu `root` | Số lần trừ / 4 bước | Ca đại diện | Đã có? |
|---|---|---:|---|:-:|
| **A. Toàn 0** | `0000` | **0** | `x=0` | ✅ ca 1 |
| **B. Toàn 1** | `1111` | **4** | `x=255` | ✅ ca 13 |
| **C. Một khối liền ở đầu** | `1000` | 1 (bước 1) | `x=64` | ✅ ca 11 |
| **D. Một khối liền ở cuối** | `0001`, `0011`, `0111` | 1–3 (các bước cuối) | `x=1`, `x=9`, `x=63` | ✅ ca 2, 7, 10 |
| **E. Xen kẽ** | `1010`, `1001` | 2 | `x=100` (`root=10`), `x=81…99` (`root=9`) | ❌ **THIẾU HOÀN TOÀN** |

Lớp **E** là lớp duy nhất bắt được lỗi “bit `qbit` vào nhầm vị trí” hoặc “`root_reg` dịch
sai chiều”. Đó chính xác là lớp mà Charter mục 8 yêu cầu qua hai ca `99` và `100`.

### Phân loại phụ: theo **vị trí bước lặp sinh ra bit 1 đầu tiên**

| Bước sinh bit 1 đầu tiên | `root` nằm trong khoảng | `x` nằm trong khoảng | Ca đại diện |
|---:|---|---|---|
| Bước 1 | 8…15 | 64…255 | `x=64`, `x=65`, `x=255` ✅ |
| Bước 2 | 4…7 | 16…63 | `x=16`, `x=63` ✅ |
| Bước 3 | 2…3 | 4…15 | `x=4`, `x=8`, `x=9`, `x=15` ✅ |
| Bước 4 | 1 | 1…3 | `x=1`, `x=2`, `x=3` ✅ |
| Không bước nào | 0 | 0 | `x=0` ✅ |

**Lớp này phủ đủ** — TB có ít nhất một ca cho mỗi bước. Tốt.

## 3. Ca tự xây dựng nên bổ sung

| # | Ca | Vì sao cần | Loại |
|---|---|---|---|
| **B-1** | **`x = 100` → `root = 10`** | **Bắt buộc theo Charter mục 8.** Lớp E: mẫu `root = 1010` xen kẽ | **Bắt buộc** |
| **B-2** | **`x = 99` → `root = 9`** | **Bắt buộc theo Charter mục 8.** Lớp E: mẫu `root = 1001`, và là `k²−1` với `k=10` | **Bắt buộc** |
| **B-3** | Quét **vét cạn cả 256 giá trị `x`** | Miền chỉ có 256 phần tử — quét hết là chuyện vài mili-giây. Mô hình chuẩn **đã làm** (`test_full_domain`). RTL mới có 13/256 = **5,1 %** | **Vét cạn** |
| **B-4** | Đo **số chu kỳ** từ `start` tới `done` ngay trong TB | Charter mục 2 câu 1 yêu cầu “kiểm chứng trên waveform”. TB dùng `wait(done)` nên **không biết** đã trôi qua mấy chu kỳ. Giá trị mong đợi: **6** | **Bắt buộc theo Charter mục 2** |
| **B-5** | `start` bật lại **khi đang `busy`** | Đặc tả nói phải bị bỏ qua. Chưa bao giờ được thử | **Ca biên giao thức** |
| **B-6** | Reset **giữa chừng** (`rst_n=0` khi `iter=2`) | Reset **đồng bộ**. Phải chứng minh `busy` về 0, `done` không phát xung rác, và phép tính kế tiếp vẫn đúng | **Ca biên** |
| **B-7** | Kiểm `INPUT_W = 16` bằng cách khởi tạo module với tham số khác | Module tham số hoá nhưng **chưa bao giờ** chạy với giá trị khác 8. Mô hình chuẩn có `test_16bit_scaling()` — PASS. RTL thì chưa | **Ca tham số** |
| **B-8** | Assertion `root*root <= x < (root+1)*(root+1)` thay vì so với bảng cố định | Biến 13 ca cố định thành **một tính chất tổng quát** kiểm được với mọi `x` — điều kiện tiên quyết cho B-3 | **Assertion tính chất** |

### Mẫu mã cho B-3 + B-8 — quét vét cạn với checker tính chất

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

13 dòng thay thế 13 dòng `run_case` — nhưng phủ **256** ca thay vì 13, và **không cần
bảng giá trị kỳ vọng** vì tính chất tự kiểm.

### Mẫu mã cho B-4 — đếm chu kỳ

```systemverilog
integer cyc;
@(negedge clk); x = xv; start = 1'b1;
@(negedge clk); start = 1'b0;
cyc = 0;
while (!done) begin @(posedge clk); cyc = cyc + 1; end
assert (cyc == 6)
    else $fatal(1, "So chu ky sai: got=%0d exp=6 (1 nap + 4 lap + 1 done)", cyc);
```

> ⚠️ Giá trị mong đợi là **6**, không phải 4. Charter viết “đúng 4 chu kỳ” nhưng đó là
> **4 bước lặp**; tổng độ trễ là **6 chu kỳ**. Xem `functional_spec.md` §6.

## 4. Ca **KHÔNG** áp dụng cho đề này — và vì sao

| Ca | Vì sao không áp dụng |
|---|---|
| **Căn có phần thập phân** | Charter mục 3 liệt kê **ngoài phạm vi**. Cổng `root` chỉ 4 bit nguyên, không có trường thập phân |
| **Căn số rộng hơn 8 bit** | Charter mục 3: **ngoài phạm vi** ở mức kiểm thử bắt buộc. Nhưng module **có** tham số `INPUT_W`, nên ca B-7 vẫn đáng làm như mở rộng tự nguyện |
| **CORDIC** | Charter mục 3: **ngoài phạm vi** — đó là đề I05 |
| **Ca số âm** | `x` khai `logic [INPUT_W-1:0]` — không dấu. Căn của số âm không tồn tại trong số nguyên |
| **Ca tràn `root`** | Không thể xảy ra. `√255 = 15,97…` → `root ≤ 15`, vừa đúng 4 bit. Đây là kết luận chứng minh được: `√(2^W−1) < 2^(W/2)` |
| **Ca tràn `rem_reg`** | Không thể xảy ra. Từ INV-6: `rem ≤ 2·root ≤ 30` → `rem_shift ≤ 123`, trong khi `REM_W = 9` bit chứa được tới 511 |
| **Ca số chu kỳ phụ thuộc dữ liệu** | Không áp dụng — số bước cố định bằng 4. Đây là **tính chất**, và ca B-4 chứng minh nó |
| **Ca `X`/`Z` trên `x`** | `interface.md` §4 giao nghĩa vụ này cho tầng ngoài. `properties.sv` chỉ kiểm **đầu ra** không có `X` |
| **Ca pipeline / nhiều phép song song** | Khối chỉ có một bộ so sánh–trừ dùng chung, vòng hồi tiếp không pipeline được |

## 5. Ca phải **bổ sung** khi chuyển sang gate-level / post-layout

| Mức | Ca cần thêm | Vì sao — **đặc biệt quan trọng với đề này** |
|---|---|---|
| **Gate-level** | Chạy **bất kỳ** ca nào trên `06_GDSII/synthesis/netlist.v` | 🔴 **Đây là ca quan trọng nhất của cả hồ sơ.** Netlist có `assign root = 4'h0;` và **0 tham chiếu** tới cổng `x`. Một ca gate-level duy nhất với `x=4` sẽ ra `root=0` thay vì `2` và **phát hiện ngay** lỗi CT-2. Mô phỏng RTL không phát hiện được vì nó còn không chạy nổi |
| **Gate-level** | So sánh danh sách FF netlist với danh sách biến RTL | 7 FF so với ~27 bit khai báo → chênh lệch 20 bit. Đây là kiểm tra **tự động hoá được** bằng script |
| **Gate-level** | Ca khởi tạo `X`: thả netlist chạy **không** reset | 7 FF đều là `dfxtp_1` — **không có chân reset**. Reset tổng hợp thành logic trước chân `D` |
| **Post-layout (SDF)** | Ca `x=255` (lớp B — trừ 4/4 lần) với độ trễ back-annotate | Lớp B ép đường dữ liệu mạnh nhất — nhưng **chỉ có ý nghĩa sau khi vá CT-1/CT-2**, vì hiện tại đường dữ liệu không tồn tại |
| **Post-layout** | Hold check trên vòng `rem_reg → so sánh → rem_reg` | `timing_report_min.txt` hiện dùng clock **lý tưởng**. Và vòng này hiện **không tồn tại** trong netlist |
| **Post-layout** | Công suất với hoạt độ thật (VCD) | Lớp A (`x=0`, không trừ lần nào) và lớp B (`x=255`, trừ 4 lần) sẽ cho công suất khác nhau rõ rệt |

## 6. Bảng tổng kết độ phủ

| Nhóm | Số ca | Có trong TB | Đã chạy | Kết quả |
|---|---:|---:|---:|---|
| Charter mục 8 (5 ca bắt buộc) | 5 | **3** (`0`, `1`, `255`) | 0 | ❌ COMPILE_FAIL, và **thiếu 2 ca** |
| Ca TB tự có ngoài Charter | 10 | 10 | 0 | ❌ COMPILE_FAIL |
| Ca đề xuất B-1…B-8 | 8 | 0 | 0 | ⬜ chưa có |
| Mô hình chuẩn Python | 7 hàm, **256 ca vét cạn** + 10 000 ca random (seed 2026) + quét 16 bit | tất cả | tất cả | ✅ **PASS** |

Bằng chứng mức Python: `05_VERIFICATION/python_reference_run.log` —
`test_full_domain`, `test_boundaries`, `test_perfect_squares`, `test_cycle_count`,
`test_trial_recurrence`, `test_16bit_scaling`, `test_random`.

> **Khoảng cách:** mô hình chuẩn đã chứng minh thuật toán đúng trên **toàn miền 256 giá
> trị** và cả ở độ rộng 16 bit. RTL chưa chứng minh được **một ca nào**. Đóng khoảng cách
> đó bắt đầu bằng **một dòng sửa** ở `05_VERIFICATION/known_issues.md`.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
