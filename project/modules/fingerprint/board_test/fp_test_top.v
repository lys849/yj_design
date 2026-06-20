// Fingerprint Board Test — VfyPwd with proper boot sequence
// 1. Wait 3s for AS608 power-on init
// 2. Send VfyPwd (default password 0x00000000)
// 3. Retry up to 3 times on failure (500ms between attempts)
// LED[0] = got response, LED[1] = password OK, LED[3] = error/timeout
`timescale 1ns / 1ps

module fp_test_top (
    input  wire       clk_100mhz,
    input  wire       rst_n,
    output wire       fp_sensor_tx,
    input  wire       fp_sensor_rx,
    output reg  [3:0] led
);

    wire [15:0] response;
    wire [7:0]  status;
    wire        cmd_done;
    reg  [7:0]  cmd_opcode;
    reg  [15:0] cmd_param;
    reg         cmd_start;

    fingerprint_ctrl #(.CLK_FREQ(100_000_000)) u_fp (
        .clk(clk_100mhz), .rst_n(rst_n),
        .sensor_tx(fp_sensor_tx), .sensor_rx(fp_sensor_rx),
        .cmd_opcode(cmd_opcode), .cmd_param(cmd_param),
        .cmd_start(cmd_start), .response(response),
        .status(status), .cmd_done(cmd_done)
    );

    localparam T_BOOT_WAIT  = 3'd0;
    localparam T_SEND       = 3'd1;
    localparam T_POLL       = 3'd2;
    localparam T_RETRY_WAIT = 3'd3;
    localparam T_DONE       = 3'd4;

    reg [2:0]  test_state;
    reg [31:0] delay_cnt;
    reg [1:0]  retry_cnt;

    localparam [31:0] BOOT_DELAY  = 32'd300_000_000; // 3 seconds
    localparam [31:0] RETRY_DELAY = 32'd50_000_000;  // 500ms

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= T_BOOT_WAIT;
            delay_cnt  <= 32'd0;
            retry_cnt  <= 2'd0;
            cmd_opcode <= 8'h00;
            cmd_param  <= 16'h0000;
            cmd_start  <= 1'b0;
            led        <= 4'b0000;
        end else begin
            cmd_start <= 1'b0;

            case (test_state)
                T_BOOT_WAIT: begin
                    if (delay_cnt >= BOOT_DELAY) begin
                        delay_cnt  <= 32'd0;
                        test_state <= T_SEND;
                    end else begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                T_SEND: begin
                    cmd_opcode <= 8'h13;
                    cmd_param  <= 16'h0000;
                    cmd_start  <= 1'b1;
                    test_state <= T_POLL;
                end

                T_POLL: begin
                    if (cmd_done) begin
                        led[0] <= 1'b1;
                        if (status == 8'd2) begin
                            led[1] <= 1'b1;
                            test_state <= T_DONE;
                        end else begin
                            if (retry_cnt < 2'd3) begin
                                retry_cnt  <= retry_cnt + 2'd1;
                                delay_cnt  <= 32'd0;
                                led[0]     <= 1'b0;
                                test_state <= T_RETRY_WAIT;
                            end else begin
                                led[3] <= 1'b1;
                                test_state <= T_DONE;
                            end
                        end
                    end
                end

                T_RETRY_WAIT: begin
                    if (delay_cnt >= RETRY_DELAY) begin
                        delay_cnt  <= 32'd0;
                        test_state <= T_SEND;
                    end else begin
                        delay_cnt <= delay_cnt + 32'd1;
                    end
                end

                T_DONE: begin
                    // Stay here
                end

                default: test_state <= T_BOOT_WAIT;
            endcase
        end
    end

endmodule
