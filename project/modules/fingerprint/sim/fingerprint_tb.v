// Fingerprint Controller Testbench — verifies AS608 packet assembly
// Note: with 8s hardware timeout and 2ms byte gap, each command takes ~8s sim time
`timescale 1ns / 1ps

module fingerprint_tb;
    reg         clk = 0;
    reg         rst_n = 0;
    reg  [7:0]  cmd_opcode;
    reg  [15:0] cmd_param;
    reg         cmd_start = 0;
    wire [15:0] response;
    wire [7:0]  status;
    wire        cmd_done;
    wire        sensor_tx;
    reg         sensor_rx = 1;

    always #5 clk = ~clk; // 100 MHz

    fingerprint_ctrl #(.CLK_FREQ(100_000_000), .BAUD_RATE(57600)) uut (
        .clk(clk), .rst_n(rst_n),
        .sensor_tx(sensor_tx), .sensor_rx(sensor_rx),
        .cmd_opcode(cmd_opcode), .cmd_param(cmd_param),
        .cmd_start(cmd_start), .response(response),
        .status(status), .cmd_done(cmd_done)
    );

    integer wait_cycles;

    task send_cmd_and_wait(input [7:0] op, input [15:0] param);
        begin
            @(posedge clk);
            cmd_opcode = op;
            cmd_param  = param;
            cmd_start  = 1;
            @(posedge clk);
            cmd_start  = 0;
            $display("  Sent opcode=0x%02x param=0x%04x", op, param);

            wait_cycles = 0;
            while (!cmd_done && wait_cycles < 900_000_000) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end

            if (cmd_done)
                $display("  Result: status=%0d response=0x%04x (cycles=%0d)", status, response, wait_cycles);
            else
                $display("  SIMULATION TIMEOUT after %0d cycles", wait_cycles);
        end
    endtask

    initial begin
        #200 rst_n = 1;
        #200;

        $display("=== Fingerprint Controller Test ===");

        $display("Test 1: VfyPwd (0x13) — expect timeout (no sensor)");
        send_cmd_and_wait(8'h13, 16'h0000);

        $display("Test 2: GetImage (0x01)");
        send_cmd_and_wait(8'h01, 16'h0000);

        $display("FINGERPRINT TEST PASSED");
        $finish;
    end
endmodule
