// Buzzer Board Test — 3 buttons trigger 3 sound patterns
// BTNC → short beep, BTNU → success tone, BTND → fail double-beep
`timescale 1ns / 1ps

module buzzer_test_top (
    input  wire clk_100mhz,
    input  wire rst_n,
    input  wire btnc,
    input  wire btnu,
    input  wire btnd,
    output wire buzzer,
    output wire [3:0] led
);

    buzzer_ctrl #(.CLK_FREQ(100_000_000)) u_buz (
        .clk(clk_100mhz), .rst_n(rst_n),
        .beep_short(btnc), .beep_ok(btnu), .beep_fail(btnd),
        .buzzer_out(buzzer)
    );

    assign led = {1'b0, btnd, btnu, btnc};

endmodule
