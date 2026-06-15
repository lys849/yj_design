// PWM Buzzer Controller — 3 sound patterns
// Trigger inputs are edge-detected (rising edge → single play)
`timescale 1ns / 1ps

module buzzer_ctrl #(
    parameter CLK_FREQ = 100_000_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire beep_short,   // short click (50ms)
    input  wire beep_ok,      // success tone (200ms)
    input  wire beep_fail,    // double beep (100ms on, 100ms off, 100ms on)
    output reg  buzzer_out
);

    localparam HALF_1KHZ  = CLK_FREQ / 2000;
    localparam SHORT_MS   = 50;
    localparam OK_MS      = 200;
    localparam FAIL_ON_MS = 100;
    localparam FAIL_GAP_MS = 100;

    localparam TICKS_PER_MS = CLK_FREQ / 1000;

    localparam S_IDLE = 3'd0;
    localparam S_BEEP = 3'd1;
    localparam S_GAP  = 3'd2;

    reg [2:0]  state;
    reg [23:0] tone_cnt;
    reg [23:0] dur_cnt;
    reg [23:0] dur_target;
    reg [23:0] gap_target;
    reg        tone_out;
    reg [1:0]  beep_phase;
    reg [1:0]  total_phases;

    reg beep_short_d, beep_ok_d, beep_fail_d;
    wire short_rise = beep_short & ~beep_short_d;
    wire ok_rise    = beep_ok    & ~beep_ok_d;
    wire fail_rise  = beep_fail  & ~beep_fail_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beep_short_d <= 1'b0;
            beep_ok_d    <= 1'b0;
            beep_fail_d  <= 1'b0;
        end else begin
            beep_short_d <= beep_short;
            beep_ok_d    <= beep_ok;
            beep_fail_d  <= beep_fail;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tone_cnt <= 24'd0;
            tone_out <= 1'b0;
        end else begin
            if (tone_cnt == HALF_1KHZ - 1) begin
                tone_cnt <= 24'd0;
                tone_out <= ~tone_out;
            end else begin
                tone_cnt <= tone_cnt + 24'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            dur_cnt      <= 24'd0;
            dur_target   <= 24'd0;
            gap_target   <= 24'd0;
            beep_phase   <= 2'd0;
            total_phases <= 2'd0;
            buzzer_out   <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    buzzer_out <= 1'b0;
                    if (short_rise) begin
                        dur_target   <= SHORT_MS * TICKS_PER_MS;
                        gap_target   <= 24'd0;
                        total_phases <= 2'd1;
                        beep_phase   <= 2'd0;
                        dur_cnt      <= 24'd0;
                        state        <= S_BEEP;
                    end else if (ok_rise) begin
                        dur_target   <= OK_MS * TICKS_PER_MS;
                        gap_target   <= 24'd0;
                        total_phases <= 2'd1;
                        beep_phase   <= 2'd0;
                        dur_cnt      <= 24'd0;
                        state        <= S_BEEP;
                    end else if (fail_rise) begin
                        dur_target   <= FAIL_ON_MS * TICKS_PER_MS;
                        gap_target   <= FAIL_GAP_MS * TICKS_PER_MS;
                        total_phases <= 2'd2;
                        beep_phase   <= 2'd0;
                        dur_cnt      <= 24'd0;
                        state        <= S_BEEP;
                    end
                end

                S_BEEP: begin
                    buzzer_out <= tone_out;
                    if (dur_cnt >= dur_target) begin
                        dur_cnt    <= 24'd0;
                        beep_phase <= beep_phase + 2'd1;
                        if (beep_phase + 2'd1 >= total_phases) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_GAP;
                        end
                    end else begin
                        dur_cnt <= dur_cnt + 24'd1;
                    end
                end

                S_GAP: begin
                    buzzer_out <= 1'b0;
                    if (dur_cnt >= gap_target) begin
                        dur_cnt <= 24'd0;
                        state   <= S_BEEP;
                    end else begin
                        dur_cnt <= dur_cnt + 24'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
