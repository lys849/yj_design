// Keyboard AXI-Lite Peripheral — Step 3 最小自定义 IP
// AXI4-Lite Slave + keyboard_scan 例化
// 寄存器: 0x00 = KB_DATA [R] {27'b0, key_valid, key_code[3:0]}
//         读取后 key_valid 自动清零
`timescale 1ns / 1ps

module kb_periph #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 4
) (
    // AXI-Lite Slave Interface
    input  wire                                S_AXI_ACLK,
    input  wire                                S_AXI_ARESETN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_AWADDR,
    input  wire                                S_AXI_AWVALID,
    output reg                                 S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]   S_AXI_WSTRB,
    input  wire                                S_AXI_WVALID,
    output reg                                 S_AXI_WREADY,
    output reg  [1:0]                          S_AXI_BRESP,
    output reg                                 S_AXI_BVALID,
    input  wire                                S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]       S_AXI_ARADDR,
    input  wire                                S_AXI_ARVALID,
    output reg                                 S_AXI_ARREADY,
    output reg  [C_S_AXI_DATA_WIDTH-1:0]       S_AXI_RDATA,
    output reg  [1:0]                          S_AXI_RRESP,
    output reg                                 S_AXI_RVALID,
    input  wire                                S_AXI_RREADY,
    // Keyboard IO
    output wire [3:0] kb_row,
    input  wire [3:0] kb_col
);

    wire       clk = S_AXI_ACLK;
    wire       rst_n = S_AXI_ARESETN;

    // ---- Keyboard module ----
    wire [3:0] key_code;
    wire       key_valid;

    keyboard_scan #(.CLK_FREQ(100_000_000)) u_kb (
        .clk(clk), .rst_n(rst_n),
        .row(kb_row), .col(kb_col),
        .key_code(key_code), .key_valid(key_valid)
    );

    // ---- Key latch (valid 读后自动清零) ----
    reg [3:0] latched_code;
    reg       latched_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latched_code  <= 4'd0;
            latched_valid <= 1'b0;
        end else begin
            if (key_valid) begin
                latched_code  <= key_code;
                latched_valid <= 1'b1;
            end
            // 读操作时清除 valid
            if (S_AXI_ARVALID && S_AXI_ARREADY)
                latched_valid <= 1'b0;
        end
    end

    // ---- AXI-Lite Write (接受但忽略，键盘是只读外设) ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_AXI_AWREADY <= 1'b0;
            S_AXI_WREADY  <= 1'b0;
            S_AXI_BVALID  <= 1'b0;
            S_AXI_BRESP   <= 2'b00;
        end else begin
            if (S_AXI_AWVALID && S_AXI_WVALID && !S_AXI_AWREADY) begin
                S_AXI_AWREADY <= 1'b1;
                S_AXI_WREADY  <= 1'b1;
            end else begin
                S_AXI_AWREADY <= 1'b0;
                S_AXI_WREADY  <= 1'b0;
            end

            if (S_AXI_AWREADY && S_AXI_WREADY) begin
                S_AXI_BVALID <= 1'b1;
                S_AXI_BRESP  <= 2'b00;
            end else if (S_AXI_BVALID && S_AXI_BREADY) begin
                S_AXI_BVALID <= 1'b0;
            end
        end
    end

    // ---- AXI-Lite Read ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            S_AXI_ARREADY <= 1'b0;
            S_AXI_RVALID  <= 1'b0;
            S_AXI_RDATA   <= 32'd0;
            S_AXI_RRESP   <= 2'b00;
        end else begin
            if (S_AXI_ARVALID && !S_AXI_ARREADY) begin
                S_AXI_ARREADY <= 1'b1;
                S_AXI_RDATA   <= {27'd0, latched_valid, latched_code};
                S_AXI_RVALID  <= 1'b1;
            end else begin
                S_AXI_ARREADY <= 1'b0;
            end

            if (S_AXI_RVALID && S_AXI_RREADY) begin
                S_AXI_RVALID <= 1'b0;
            end
        end
    end

endmodule
