module i02_integer_sqrt_tb;

    logic clk=0, rst_n=0, start=0;
    logic [7:0] x;
    logic [3:0] root;
    logic busy, done;

    i02_integer_sqrt dut(
        .clk(clk), .rst_n(rst_n), .start(start), .x(x),
        .root(root), .busy(busy), .done(done));

    always #5 clk=~clk;

    task automatic run_case(input [7:0] xv, input [3:0] expected);
        begin
            @(negedge clk);
            x=xv;
            start=1;
            @(negedge clk);
            start=0;

            wait(done);

            assert(root === expected)
                else $fatal(1,"sqrt mismatch x=%0d got=%0d exp=%0d",
                            xv, root, expected);
        end
    endtask

    initial begin
        x='0;
        repeat(2) @(posedge clk);
        rst_n=1;

        run_case(8'd0,0);
        run_case(8'd1,1);
        run_case(8'd2,1);
        run_case(8'd3,1);
        run_case(8'd4,2);
        run_case(8'd8,2);
        run_case(8'd9,3);
        run_case(8'd15,3);
        run_case(8'd16,4);
        run_case(8'd63,7);
        run_case(8'd64,8);
        run_case(8'd65,8);
        run_case(8'd255,15);

        $display("I02 RTL TB PASS");
        $finish;
    end
endmodule
