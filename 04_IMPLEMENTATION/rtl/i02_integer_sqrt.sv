module i02_integer_sqrt #(
    parameter int INPUT_W = 8
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              start,
    input  logic [INPUT_W-1:0] x,

    output logic [INPUT_W/2-1:0] root,
    output logic              busy,
    output logic              done
);

    localparam int ROOT_W = INPUT_W/2;
    localparam int REM_W  = INPUT_W + 1;
    localparam int ITER_W = (ROOT_W <= 1) ? 1 : $clog2(ROOT_W+1);

    logic [INPUT_W-1:0] x_reg;
    logic [ROOT_W-1:0] root_reg;
    logic [REM_W-1:0] rem_reg;
    logic [ITER_W-1:0] iter;

    logic [1:0] next_pair;
    logic [REM_W-1:0] rem_shift;
    logic [REM_W-1:0] trial;
    logic [REM_W-1:0] rem_next;
    logic qbit;

    typedef enum logic [1:0] {
        S_IDLE,
        S_ITER,
        S_DONE
    } state_t;

    state_t state;

    always_comb begin
        next_pair = x_reg[INPUT_W-1 -: 2];
        rem_shift = (rem_reg << 2) | next_pair;
        trial     = (root_reg << 2) | 1'b1;

        if (rem_shift >= trial) begin
            rem_next = rem_shift - trial;
            qbit     = 1'b1;
        end else begin
            rem_next = rem_shift;
            qbit     = 1'b0;
        end
    end

    assign root = root_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            x_reg    <= '0;
            root_reg <= '0;
            rem_reg  <= '0;
            iter     <= '0;
            // "root <= '0;" removed: root already has ONE driver, the
            // continuous assignment "assign root = root_reg;". Driving it a
            // second time from this always_ff made root an unresolved net;
            // iverilog rejected it and Yosys resolved the conflict by tying
            // root to constant 0, which killed root_reg and the whole datapath.
            // root_reg is cleared just above, so reset behaviour is unchanged.
            busy     <= 1'b0;
            done     <= 1'b0;
            state    <= S_IDLE;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        x_reg    <= x;
                        root_reg <= '0;
                        rem_reg  <= '0;
                        iter     <= '0;
                        busy     <= 1'b1;
                        state    <= S_ITER;
                    end
                end

                S_ITER: begin
                    busy <= 1'b1;

                    rem_reg  <= rem_next;
                    root_reg <= (root_reg << 1) | qbit;
                    x_reg    <= x_reg << 2;

                    if (iter == ROOT_W-1) begin
                        busy  <= 1'b0;
                        state <= S_DONE;
                    end else begin
                        iter <= iter + 1'b1;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                    busy  <= 1'b0;
                end
            endcase
        end
    end

endmodule
