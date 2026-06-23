// 指纹支付系统 AXI-Lite 外设 — 包装全部 5 个模块
// 寄存器映射:
//   0x00 FP_CMD   [W]  {start[31], 7'b0, opcode[23:16], param[15:0]}
//   0x04 FP_RESP  [R]  {status[31:24], 8'h00, response[15:0]}
//   0x08 KB_DATA  [R]  {27'b0, valid[4], key_code[3:0]}  读后清 valid
//   0x0C BUZZER   [W]  {29'b0, fail[2], ok[1], short[0]} 写后自动清零
//   0x10 VGA_CHAR [W]  {we[31], 8'b0, addr[22:12], 4'b0, data[7:0]}
//   0x14 LED      [W]  {28'b0, led[3:0]}
//   0x18 FP_DBG   [R]  {4'b0, rx_seen, state[2:0], tx_idx[4:0], rx_cnt[5:0], pkt_len[4:0], last_rx[7:0]}
//                       state: 0=idle, 1=boot_wait, 2=wake/guard, 3=build,
//                              4=send/tx_gap, 5=wait_resp, 6=read/parse, 7=done
//   0x1C BTN_DATA [R]  {30'b0, clear_valid[1], confirm_valid[0]}  读后清 valid
`timescale 1ns / 1ps

module fp_payment_periph #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 5
) (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET S_AXI_ARESETN, FREQ_HZ 100000000" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S_AXI_ACLK CLK" *)
    input  wire        S_AXI_ACLK,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 S_AXI_ARESETN RST" *)
    input  wire        S_AXI_ARESETN,

    (* X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 5" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_AWADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input  wire [2:0]  S_AXI_AWPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire        S_AXI_AWVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output reg         S_AXI_AWREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_WDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire        S_AXI_WVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output reg         S_AXI_WREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output reg  [1:0]  S_AXI_BRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output reg         S_AXI_BVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire        S_AXI_BREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     S_AXI_ARADDR,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input  wire [2:0]  S_AXI_ARPROT,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire        S_AXI_ARVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output reg         S_AXI_ARREADY,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     S_AXI_RDATA,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output reg  [1:0]  S_AXI_RRESP,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output reg         S_AXI_RVALID,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire        S_AXI_RREADY,

    output wire [3:0]  kb_row,
    input  wire [3:0]  kb_col,
    input  wire        btnc,
    input  wire        btnd,
    output wire        fp_sensor_tx,
    input  wire        fp_sensor_rx,
    output wire        buzzer,
    output reg  [3:0]  led,
    output reg  [10:0] vga_char_addr,
    output reg  [7:0]  vga_char_data,
    output reg         vga_char_we_toggle
);

    wire clk   = S_AXI_ACLK;
    wire rst_n = S_AXI_ARESETN;
    wire axi_read_accept = S_AXI_ARVALID && !S_AXI_ARREADY;

    // ---- 模块例化 ----

    // 键盘
    wire [3:0] key_code;
    wire       key_valid;
    keyboard_scan #(.CLK_FREQ(100_000_000)) u_kb (
        .clk(clk), .rst_n(rst_n),
        .row(kb_row), .col(kb_col),
        .key_code(key_code), .key_valid(key_valid)
    );

    // 指纹
    reg  [7:0]  fp_opcode;
    reg  [15:0] fp_param;
    reg         fp_start_pulse;
    wire [15:0] fp_response;
    wire [7:0]  fp_status;
    wire        fp_done;
    wire [31:0] fp_debug;
    fingerprint_ctrl #(.CLK_FREQ(100_000_000)) u_fp (
        .clk(clk), .rst_n(rst_n),
        .sensor_tx(fp_sensor_tx), .sensor_rx(fp_sensor_rx),
        .cmd_opcode(fp_opcode), .cmd_param(fp_param),
        .cmd_start(fp_start_pulse), .response(fp_response),
        .status(fp_status), .cmd_done(fp_done), .debug_info(fp_debug)
    );

    // 蜂鸣器
    reg beep_short, beep_ok, beep_fail;
    buzzer_ctrl #(.CLK_FREQ(100_000_000)) u_buz (
        .clk(clk), .rst_n(rst_n),
        .beep_short(beep_short), .beep_ok(beep_ok), .beep_fail(beep_fail),
        .buzzer_out(buzzer)
    );

    // ---- 内部寄存器 ----
    reg [3:0]  kb_latched_code;
    reg        kb_latched_valid;
    reg        btn_confirm_valid;
    reg        btn_clear_valid;

    localparam BTN_DEBOUNCE_CNT = 22'd2_000_000; // 20ms @ 100MHz
    reg        btnc_meta, btnc_sync;
    reg        btnd_meta, btnd_sync;
    reg        btnc_stable, btnd_stable;
    reg [21:0] btnc_cnt, btnd_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btnc_meta <= 1'b0;
            btnc_sync <= 1'b0;
            btnd_meta <= 1'b0;
            btnd_sync <= 1'b0;
        end else begin
            btnc_meta <= btnc;
            btnc_sync <= btnc_meta;
            btnd_meta <= btnd;
            btnd_sync <= btnd_meta;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btnc_stable       <= 1'b0;
            btnd_stable       <= 1'b0;
            btnc_cnt          <= 22'd0;
            btnd_cnt          <= 22'd0;
            btn_confirm_valid <= 1'b0;
            btn_clear_valid   <= 1'b0;
        end else begin
            if (btnc_sync == btnc_stable) begin
                btnc_cnt <= 22'd0;
            end else if (btnc_cnt >= BTN_DEBOUNCE_CNT) begin
                btnc_cnt <= 22'd0;
                btnc_stable <= btnc_sync;
                if (btnc_sync)
                    btn_confirm_valid <= 1'b1;
            end else begin
                btnc_cnt <= btnc_cnt + 22'd1;
            end

            if (btnd_sync == btnd_stable) begin
                btnd_cnt <= 22'd0;
            end else if (btnd_cnt >= BTN_DEBOUNCE_CNT) begin
                btnd_cnt <= 22'd0;
                btnd_stable <= btnd_sync;
                if (btnd_sync)
                    btn_clear_valid <= 1'b1;
            end else begin
                btnd_cnt <= btnd_cnt + 22'd1;
            end

            if (axi_read_accept && S_AXI_ARADDR[4:2] == 3'd7) begin
                btn_confirm_valid <= 1'b0;
                btn_clear_valid   <= 1'b0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kb_latched_code  <= 4'd0;
            kb_latched_valid <= 1'b0;
        end else begin
            if (key_valid) begin
                kb_latched_code  <= key_code;
                kb_latched_valid <= 1'b1;
            end
            if (axi_read_accept && S_AXI_ARADDR[4:2] == 3'd2)
                kb_latched_valid <= 1'b0;
        end
    end

    // ---- AXI Write ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
            fp_opcode     <= 8'd0;
            fp_param      <= 16'd0;
            fp_start_pulse <= 1'b0;
            led           <= 4'd0;
            vga_char_addr <= 11'd0;
            vga_char_data <= 8'd0;
            vga_char_we_toggle <= 1'b0;
            beep_short    <= 1'b0;
            beep_ok       <= 1'b0;
            beep_fail     <= 1'b0;
        end else begin
            if (beep_short) beep_short <= 1'b0;
            if (beep_ok)    beep_ok    <= 1'b0;
            if (beep_fail)  beep_fail  <= 1'b0;
            fp_start_pulse <= 1'b0;

            if (S_AXI_AWVALID && S_AXI_WVALID && !S_AXI_BVALID) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;

                case (S_AXI_AWADDR[4:2])
                    3'd0: begin // FP_CMD
                        fp_start_pulse <= S_AXI_WDATA[31];
                        fp_opcode <= S_AXI_WDATA[23:16];
                        fp_param  <= S_AXI_WDATA[15:0];
                    end
                    3'd3: begin // BUZZER
                        beep_short <= S_AXI_WDATA[0];
                        beep_ok    <= S_AXI_WDATA[1];
                        beep_fail  <= S_AXI_WDATA[2];
                    end
                    3'd4: begin // VGA_CHAR
                        vga_char_addr <= S_AXI_WDATA[22:12];
                        vga_char_data <= S_AXI_WDATA[7:0];
                        if (S_AXI_WDATA[31])
                            vga_char_we_toggle <= ~vga_char_we_toggle;
                    end
                    3'd5: begin // LED
                        led <= S_AXI_WDATA[3:0];
                    end
                endcase
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;
            end else begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
                if (S_AXI_BVALID && S_AXI_BREADY)
                    S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // ---- AXI Read ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= 32'd0;
            S_AXI_RRESP   <= 2'b00;
        end else begin
            if (S_AXI_ARVALID && !S_AXI_ARREADY) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RVALID  <= 1'b1;
                case (S_AXI_ARADDR[4:2])
                    3'd0: S_AXI_RDATA <= {fp_start_pulse, 7'd0, fp_opcode, fp_param};
                    3'd1: S_AXI_RDATA <= {fp_status, 8'd0, fp_response};
                    3'd2: S_AXI_RDATA <= {27'd0, kb_latched_valid, kb_latched_code};
                    3'd5: S_AXI_RDATA <= {28'd0, led};
                    3'd6: S_AXI_RDATA <= fp_debug;
                    3'd7: S_AXI_RDATA <= {30'd0, btn_clear_valid, btn_confirm_valid};
                    default: S_AXI_RDATA <= 32'd0;
                endcase
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end
            if (S_AXI_RVALID && S_AXI_RREADY)
                S_AXI_RVALID <= 1'b0;
        end
    end

endmodule
