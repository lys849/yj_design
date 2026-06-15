// Fingerprint Board Test — send VfyPwd on startup, show result on LED
// LED[0] = sensor responded, LED[1] = password OK
// LED[3] = timeout (no response)
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

    reg [1:0] test_state;
    reg [23:0] delay_cnt;

    localparam T_WAIT  = 2'd0;
    localparam T_SEND  = 2'd1;
    localparam T_POLL  = 2'd2;
    localparam T_DONE  = 2'd3;

    always @(posedge clk_100mhz or negedge rst_n) begin
        if (!rst_n) begin
            test_state <= T_WAIT;
            delay_cnt  <= 24'd0;
            cmd_opcode <= 8'h00;
            cmd_param  <= 16'h0000;
            cmd_start  <= 1'b0;
            led        <= 4'b0000;
        end else begin
            cmd_start <= 1'b0;

            case (test_state)
                T_WAIT: begin
                    if (delay_cnt == 24'd10_000_000) begin
                        test_state <= T_SEND;
                    end else begin
                        delay_cnt <= delay_cnt + 24'd1;
                    end
                end

                T_SEND: begin
                    cmd_opcode <= 8'h13; // VfyPwd
                    cmd_param  <= 16'h0000;
                    cmd_start  <= 1'b1;
                    test_state <= T_POLL;
                end

                T_POLL: begin
                    if (cmd_done) begin
                        led[0] <= 1'b1;
                        if (status == 8'd2)
                            led[1] <= 1'b1; // success
                        else
                            led[3] <= 1'b1; // error/timeout
                        test_state <= T_DONE;
                    end
                end

                T_DONE: begin
                    // stay here
                end
            endcase
        end
    end

endmodule
