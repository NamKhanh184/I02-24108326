// ─────────────────────────────────────────────────────────────────────────────
//  Testbench mẫu — EEE703128 Bài kiểm tra số 2
//
//  Testbench này làm ba việc, và báo cáo của em cần cả ba:
//    1. Sinh kích thích đầu vào theo các ca kiểm thử của đề
//    2. So kết quả thu được với kết quả MONG ĐỢI (tự tính tay trước)
//    3. Ghi file .vcd để mở bằng GTKWave / Surfer và chụp waveform đưa vào báo cáo
//
//  Chạy thử trên máy (nếu có Icarus Verilog):
//      iverilog -g2012 -o tb.out test/tb.v src/project.v && vvp tb.out
//
//  Không cài được cũng không sao — chuỗi công cụ trên GitHub chạy hộ.
// ─────────────────────────────────────────────────────────────────────────────
`default_nettype none
`timescale 1ns / 1ps

module tb;

    reg  [7:0] ui_in, uio_in;
    reg        ena, clk, rst_n;
    wire [7:0] uo_out, uio_out, uio_oe;

    integer so_ca  = 0;   // đã chạy bao nhiêu ca
    integer so_sai = 0;   // sai bao nhiêu ca

    tt_um_eee703128_24108326 dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    // Xung nhịp 10 ns (100 MHz). Đề tổ hợp không dùng nhưng cứ để chạy.
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Nhiệm vụ kiểm một ca ──────────────────────────────────────────────
    task kiem;
        input [7:0] a;
        input [7:0] b;
        input [3:0] mong_doi;
        input [255:0] ten;
        begin
            ui_in = a;
            @(negedge clk);
            uio_in[0] = 1;
            @(negedge clk);
            uio_in[0] = 0;
            wait (uo_out[4] === 1'b1);
            so_ca = so_ca + 1;
            if (uo_out[3:0] === mong_doi)
                $display("  ✓ %0s | ui=%0d -> root=%0d", ten, a, uo_out[3:0]);
            else begin
                so_sai = so_sai + 1;
                $display("  ✗ %0s | ui=%0d -> root=%0d  (MONG ĐỢI %0d)",
                         ten, a, uo_out[3:0], mong_doi);
            end
        end
    endtask

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        ena = 1; rst_n = 0; ui_in = 0; uio_in = 0;
        #20 rst_n = 1;          // nhả reset
        #10;

        $display("");
        $display("=== CA KIEM THU ===");

        // ══════════════════ CA KIỂM THỬ CỦA EM — BẮT ĐẦU ══════════════════
        // Các ca dưới đây kiểm ví dụ mẫu threshold_alarm (alarm = sample >= threshold).
        // Xoá đi và thay bằng các ca ở cột "Ca kiểm thử tối thiểu" của đề em.
        // Nhớ thêm ít nhất hai ca do em tự nghĩ — rubric tiêu chí 2 có tính điểm phần này.

        kiem(  0,   0, 8'd0, "khong                ");
        kiem(  1,   0, 8'd1, "mot                  ");
        kiem(  3,   0, 8'd1, "duoi 4               ");
        kiem(  4,   0, 8'd2, "chinh phuong 4       ");
        kiem(  9,   0, 8'd3, "chinh phuong 9       ");
        kiem( 64,   0, 8'd8, "chinh phuong 64      ");
        kiem(100,   0, 8'd10, "tu 100"); 
        kiem(255,   0, 8'd15, "gia tri lon nhat     ");

        // ══════════════════ CA KIỂM THỬ CỦA EM — KẾT THÚC ══════════════════

        $display("");
        $display("=== KET QUA: %0d ca, %0d sai ===", so_ca, so_sai);
        if (so_sai == 0) $display("TAT CA CA KIEM THU DEU DAT");
        else             $display("CON %0d CA SAI — sua RTL roi chay lai", so_sai);
        $display("");
        #20 $finish;
    end

endmodule

`default_nettype wire
