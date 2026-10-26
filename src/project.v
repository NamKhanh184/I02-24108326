// ─────────────────────────────────────────────────────────────────────────────
//  EEE703128 — Bài kiểm tra số 2 · KHUNG MẪU
//
//  ĐỌC TRƯỚC KHI SỬA
//  1. Đổi <MSSV> trong tên module thành mã số sinh viên của em.
//     Tên module PHẢI bắt đầu bằng  tt_um_  thì chuỗi công cụ mới nhận.
//  2. Giữ nguyên danh sách cổng. KHÔNG thêm, KHÔNG bớt, KHÔNG đổi tên.
//     Kể cả khi đề của em không dùng clk và rst_n, vẫn phải khai báo chúng.
//  3. Viết thiết kế của em vào chỗ ghi "PHẦN CỦA EM".
//  4. Phần dưới cùng là VÍ DỤ MẪU đã chạy được: case threshold_alarm của học phần.
//     Đọc nó để hiểu cách nối chân, rồi xoá đi và viết đề của mình.
//
//  Quy ước bắt buộc của chuỗi công cụ:
//    · `default_nettype none  ở đầu và `default_nettype wire ở cuối
//    · rst_n tích cực mức THẤP (rst_n = 0 nghĩa là đang reset)
//    · Mọi chân ra phải được gán giá trị, không được để hở
//    · uio_oe[i] = 1 nghĩa là chân hai chiều thứ i làm ĐẦU RA
// ─────────────────────────────────────────────────────────────────────────────
`default_nettype none

module i02_integer_sqrt_wrapper (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] x,
    output wire [3:0] root,
    output wire       busy,
    output wire       done
);
    reg [7:0] x_reg;
    reg [3:0] root_reg;
    reg busy_reg;
    reg done_reg;
    reg [8:0] rem_reg;
    reg [2:0] iter;
    reg [1:0] state;

    localparam S_IDLE = 2'd0;
    localparam S_ITER = 2'd1;
    localparam S_DONE = 2'd2;

    reg [8:0] rem_shift;
    reg [8:0] trial;
    reg [8:0] rem_next;
    reg qbit;

    always @* begin
        rem_shift = (rem_reg << 2) | x_reg[7:6];
        trial = (root_reg << 2) | 1'b1;
        if (rem_shift >= trial) begin
            rem_next = rem_shift - trial;
            qbit = 1'b1;
        end else begin
            rem_next = rem_shift;
            qbit = 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            x_reg <= 0;
            root_reg <= 0;
            rem_reg <= 0;
            iter <= 0;
            busy_reg <= 0;
            done_reg <= 0;
            state <= S_IDLE;
        end else begin
            done_reg <= 0;
            case (state)
                S_IDLE: begin
                    busy_reg <= 0;
                    if (start) begin
                        x_reg <= x;
                        root_reg <= 0;
                        rem_reg <= 0;
                        iter <= 0;
                        busy_reg <= 1;
                        state <= S_ITER;
                    end
                end
                S_ITER: begin
                    busy_reg <= 1;
                    rem_reg <= rem_next;
                    root_reg <= (root_reg << 1) | qbit;
                    x_reg <= x_reg << 2;
                    if (iter == 3) begin
                        busy_reg <= 0;
                        state <= S_DONE;
                    end else begin
                        iter <= iter + 1'b1;
                    end
                end
                S_DONE: begin
                    busy_reg <= 0;
                    done_reg <= 1;
                    state <= S_IDLE;
                end
                default: begin
                    busy_reg <= 0;
                    state <= S_IDLE;
                end
            endcase
        end
    end
    assign root = root_reg;
    assign busy = busy_reg;
    assign done = done_reg;
endmodule

module tt_um_eee703128_24108326 (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire [3:0] root;
    wire busy;
    wire done;

    i02_integer_sqrt_wrapper dut_i02 (
        .clk(clk),
        .rst_n(rst_n),
        .start(ena && uio_in[0]),
        .x(ui_in),
        .root(root),
        .busy(busy),
        .done(done)
    );

    assign uo_out = {2'b00, busy, done, root};
    assign uio_out = 8'b0;
    assign uio_oe = 8'b0;
endmodule

`default_nettype wire
