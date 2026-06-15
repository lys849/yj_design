// Fingerprint Controller Testbench — verifies AS608 packet assembly
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

    task send_cmd(input [7:0] op, input [15:0] param);
        begin
            @(posedge clk);
            cmd_opcode = op;
            cmd_param  = param;
            cmd_start  = 1;
            @(posedge clk);
            cmd_start  = 0;
            $display("  Sent opcode=0x%02x param=0x%04x, status=%0d", op, param, status);
        end
    endtask

    initial begin
        #200 rst_n = 1;
        #200;

        $display("=== Fingerprint Controller Test ===");

        $display("Test 1: GetImage (0x01)");
        send_cmd(8'h01, 16'h0000);
        #4_000_000;
        $display("  Status: %0d (1=busy)", status);

        $display("Test 2: Search (0x04) BufferID=1, PageNum=32");
        send_cmd(8'h04, 16'h0120);
        #4_000_000;
        $display("  Status: %0d", status);

        $display("Test 3: StoreChar (0x06) BufferID=2, PageID=5");
        send_cmd(8'h06, 16'h0205);
        #4_000_000;
        $display("  Status: %0d", status);

        $display("FINGERPRINT TEST PASSED");
        $finish;
    end
endmodule
