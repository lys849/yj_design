// Buzzer/PWM Audio Controller
// Generates different audio patterns for system feedback
`timescale 1ns / 1ps

module buzzer_ctrl #(
    parameter CLK_FREQ = 50_000_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       beep_short,    // short beep (key press)
    input  wire       beep_ok,       // success beep (single long)
    input  wire       beep_fail,     // failure beep (double)
    output reg        buzzer_out
);

    localparam FREQ_1KHZ   = CLK_FREQ / 2000;  // 1kHz tone (divide by 2x)
    localparam SHORT_MS    = 50;                // 50ms short beep
    localparam LONG_MS     = 200;               // 200ms long beep
    localparam INTERVAL_MS = 100;               // interval between beeps
    localparam SHORT_CNT   = (CLK_FREQ / 1000) * SHORT_MS;
    localparam LONG_CNT    = (CLK_FREQ / 1000) * LONG_MS;
    localparam INTERVAL_CNT = (CLK_FREQ / 1000) * INTERVAL_MS;

    reg [31:0] tone_cnt;
    reg [31:0] duration_cnt;
    reg [3:0]  beep_count;   // for multi-beep patterns

    localparam S_IDLE     = 2'd0;
    localparam S_BEEP_ON  = 2'd1;
    localparam S_BEEP_OFF = 2'd2;

    reg [1:0] state;
    reg [1:0] beep_type;    // 0=short, 1=ok, 2=fail
    reg       running;

    wire beep_trigger = beep_short | beep_ok | beep_fail;

    // Determine pattern: number of beeps and length
    wire [1:0] trigger_type = beep_ok    ? 2'd1 :
                              beep_fail  ? 2'd2 : 2'd0;

    wire [31:0] on_time  = (beep_type == 2'd1 || beep_type == 2'd2) ? LONG_CNT  : SHORT_CNT;
    wire [31:0] off_time = (beep_type == 2'd1)                      ? 32'd0     : INTERVAL_CNT;
    wire [3:0]  total_beeps = (beep_type == 2'd2) ? 4'd2 : 4'd1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            tone_cnt     <= 32'd0;
            duration_cnt <= 32'd0;
            beep_count   <= 4'd0;
            beep_type    <= 2'd0;
            buzzer_out   <= 1'b0;
            running      <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    buzzer_out   <= 1'b0;
                    tone_cnt     <= 32'd0;
                    duration_cnt <= 32'd0;
                    beep_count   <= 4'd0;
                    if (beep_trigger) begin
                        beep_type <= trigger_type;
                        running   <= 1'b1;
                        state     <= S_BEEP_ON;
                    end
                end

                S_BEEP_ON: begin
                    // PWM tone generation
                    if (tone_cnt < FREQ_1KHZ) begin
                        buzzer_out <= 1'b1;
                    end else begin
                        buzzer_out <= 1'b0;
                    end
                    tone_cnt <= tone_cnt + 32'd1;
                    if (tone_cnt == FREQ_1KHZ * 2 - 1) begin
                        tone_cnt <= 32'd0;
                    end

                    // Duration control
                    if (duration_cnt == on_time - 1) begin
                        duration_cnt <= 32'd0;
                        beep_count <= beep_count + 4'd1;
                        if (beep_count + 1 == total_beeps && off_time == 0) begin
                            state   <= S_IDLE;
                            running <= 1'b0;
                        end else if (beep_count + 1 == total_beeps) begin
                            state <= S_IDLE;
                            running <= 1'b0;
                        end else begin
                            state <= S_BEEP_OFF;
                        end
                    end else begin
                        duration_cnt <= duration_cnt + 32'd1;
                    end
                end

                S_BEEP_OFF: begin
                    buzzer_out <= 1'b0;
                    if (duration_cnt == off_time - 1) begin
                        duration_cnt <= 32'd0;
                        state <= S_BEEP_ON;
                    end else begin
                        duration_cnt <= duration_cnt + 32'd1;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
