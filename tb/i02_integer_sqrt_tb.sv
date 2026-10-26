`default_nettype none
`timescale 1ns/1ps

module i02_integer_sqrt_tb;
    logic clk = 0;
    logic rst_n = 0;
    logic start = 0;
    logic [7:0] x;
    logic [3:0] root;
    logic busy, done;

    i02_integer_sqrt dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .x(x),
        .root(root),
        .busy(busy),
        .done(done)
    );

    always #5 clk = ~clk;

    task automatic run_case(input logic [7:0] xv, input logic [3:0] expected);
        begin
            @(negedge clk);
            x = xv;
            start = 1;
            @(negedge clk);
            start = 0;
            wait(done);

            if (root !== expected)
                $fatal(1, "sqrt mismatch x=%0d got=%0d exp=%0d", xv, root, expected);
        end
    endtask

    initial begin
        x = '0;
        repeat (2) @(posedge clk);
        rst_n = 1;

        run_case(8'd0,   4'd0);
        run_case(8'd1,   4'd1);
        run_case(8'd2,   4'd1);
        run_case(8'd3,   4'd1);
        run_case(8'd4,   4'd2);
        run_case(8'd8,   4'd2);
        run_case(8'd9,   4'd3);
        run_case(8'd15,  4'd3);
        run_case(8'd16,  4'd4);
        run_case(8'd63,  4'd7);
        run_case(8'd64,  4'd8);
        run_case(8'd65,  4'd8);
        run_case(8'd255, 4'd15);

        $display("I02 RTL TB PASS");
        $finish;
    end
endmodule

`default_nettype wire
