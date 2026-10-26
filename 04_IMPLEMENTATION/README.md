# I02 · Tầng 04 — Hiện thực (Implementation)

---

## 1. Nội dung thư mục

```
04_IMPLEMENTATION/
├── rtl/               i02_integer_sqrt.sv
├── constraints/       design.sdc
├── scripts/           01_run_sim.sh · 02_run_synth.sh · 03_run_sta.tcl
│                      04_run_librelane.sh · config.json · config_librelane.json
└── README.md
```

**Top module:** `i02_integer_sqrt`
**Bằng chứng chọn top:** `i02_integer_sqrt_tb.sv` khởi tạo module `i02_integer_sqrt`
thành `dut`.


## 2. Thứ tự chạy

```bash
python3 05_VERIFICATION/golden_model/reference_model.py     # ✅ PASS
bash 04_IMPLEMENTATION/scripts/01_run_sim.sh                # ✅ PASS
bash 04_IMPLEMENTATION/scripts/02_run_synth.sh              # ✅ PASS
sta -no_splash -exit 04_IMPLEMENTATION/scripts/03_run_sta.tcl   # ✅ PASS
bash 04_IMPLEMENTATION/scripts/04_run_librelane.sh          # cần PDK sky130A; có lần chạy hoàn tất 2026-10-26
```

Mỗi script tự kiểm tra công cụ và **dừng có thông báo** nếu thiếu, thay vì tạo kết quả giả.

## 3. Sửa nguồn tối thiểu đã áp dụng

Nguồn gốc lấy từ `I02_FINAL_MENTOR_PACKAGE_v1_0`. Bản sao trong thư mục này đã được vá
lỗi RTL D-1; bản gốc được giữ nguyên trong `08_ORIGINAL_SOURCE/`.

**`rtl/i02_integer_sqrt.sv`** — bỏ phép gán thủ tục dư thừa `root <= '0;` trong nhánh
reset. `root` đã được lái bởi `assign root = root_reg`; xóa `root_reg` trong reset đã
đưa `root` về 0, nên hành vi reset không đổi. Phép gán thứ hai gây lỗi elaboration với
Icarus và xung đột driver khi tổng hợp bằng Yosys.

Chi tiết và kết quả đối chiếu trước/sau: [`../08_ORIGINAL_SOURCE/PATCHLOG.md`](../08_ORIGINAL_SOURCE/PATCHLOG.md)
và [`../05_VERIFICATION/known_issues.md`](../05_VERIFICATION/known_issues.md).


## 4. Môi trường đã dùng để sinh bằng chứng

| Công cụ | Phiên bản |
|---|---|
| Mô phỏng | Icarus Verilog 12.0 (stable) |
| Tổng hợp | Yosys 0.33 (git sha1 2584903a060) |
| STA + công suất | OpenSTA 3.1.0 |
| Liberty | `sky130_fd_sc_hd__tt_025C_1v80.lib` (typical · 25 °C · 1,80 V) |
| LibreLane + sky130A | ✅ flow hoàn tất 2026-10-26; xem `../06_GDSII/physical_report.md` |

## 5. Cài đặt công cụ trên WSL Ubuntu

```bash
sudo apt update && sudo apt install -y iverilog yosys gtkwave
# OpenSTA: can cmake swig tcl-dev flex bison libeigen3-dev libgtest-dev + CUDD 3.0.0
pip install librelane volare && volare enable --pdk sky130 <commit>
export PDK_ROOT=$HOME/.volare
```

Gọn hơn: dùng **OSS CAD Suite** (`source <oss-cad-suite>/environment`) — có sẵn iverilog,
yosys, OpenSTA, OpenROAD, KLayout, Magic, Netgen.

---

*Phiên bản: v1.0 · Ngày: 2026-09-24*
