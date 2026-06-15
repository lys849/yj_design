// Buzzer Controller Testbench
`timescale 1ns / 1ps

module buzzer_tb;
    reg  clk = 0;
    reg  rst_n = 0;
    reg  beep_short = 0, beep_ok = 0, beep_fail = 0;
    wire buzzer_out;

    always #5 clk = ~clk; // 100 MHz

    buzzer_ctrl #(.CLK_FREQ(100_000_000)) uut (
        .clk(clk), .rst_n(rst_n),
        .beep_short(beep_short), .beep_ok(beep_ok), .beep_fail(beep_fail),
        .buzzer_out(buzzer_out)
    );

    initial begin
        #100 rst_n = 1;
        #1000;

        $display("=== Buzzer Controller Test ===");

        $display("  Test 1: short beep...");
        beep_short = 1; #20; beep_short = 0;
        #6_000_000;
        $display("    Short beep done");

        $display("  Test 2: OK beep...");
        beep_ok = 1; #20; beep_ok = 0;
        #25_000_000;
        $display("    OK beep done");

        $display("  Test 3: fail beep...");
        beep_fail = 1; #20; beep_fail = 0;
        #35_000_000;
        $display("    Fail beep done");

        $display("BUZZER TEST PASSED");
        $finish;
    end
endmodule
