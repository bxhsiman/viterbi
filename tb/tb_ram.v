//============================ tb_RAM_separate_clk.v ===========================
`timescale 1ns/1ps
`include "params.v"
`include "rtl/ram.v"

module tb_RAM;

  /*-------------------- 接口信号 --------------------*/
  reg                       RAMEnable_n;          // 低有效
  reg                       RWSelect;             // 0=写 1=读
  reg  [`WD_RAM_ADDRESS-1:0] AddressRAM;
  reg                       WCLK, RCLK;           // 写、读两个独立时钟
  reg  [7:0]                data_out;             // 驱动数据
  wire [7:0]                DataRAM;              // RAM 双向总线
  wire [7:0]                read_data = DataRAM;  // 读回采样

  /*-------------------- 总线驱动 --------------------*/
  assign DataRAM = RWSelect ? 'bz : data_out;

  /*-------------------- DUT ------------------------*/
  RAM dut (
    .RAMEnable  (RAMEnable_n),
    .AddressRAM (AddressRAM),
    .DataRAM    (DataRAM),
    .RWSelect   (RWSelect),
    .ReadClock  (RCLK),
    .WriteClock (WCLK)
  );

  /*-------------------- 时钟生成 --------------------*/
  initial begin WCLK = 0;  forever #10 WCLK = ~WCLK; end
  initial begin RCLK = 1;  forever #10 RCLK = ~RCLK; end

  /*-------------------- 波形 ------------------------*/
  initial begin
    $dumpfile("ram_tb.vcd");
    $dumpvars(0, tb_RAM);
  end

  /*-------------------- 测试流程 --------------------*/
  initial begin
    /* ===== 上电初始化 ===== */
    RAMEnable_n = 0;          // 使能 RAM
    RWSelect    = 0;          // 先写
    AddressRAM  = 0;
    data_out    = 0;

    /* ===== 写两字节 ===== */
    repeat (2) begin
      @(posedge WCLK);        // 写在 WCLK 负沿
      data_out   = (AddressRAM==0) ? 8'hA5 : 8'h3C;
      @(negedge WCLK);        // 等到上升沿更新数据
      AddressRAM = AddressRAM + 1;
    end

    /* ===== 读回 ===== */
    RWSelect   = 1;           // 切到读
    AddressRAM = 0;
    @(negedge RCLK);          // 读在 RCLK 负沿
    $display("Read0 = 0x%02h (期望 A5)", read_data);
    if (read_data!==8'hA5) $fatal(1, "RAM mismatch @addr0");
    
    @(negedge RCLK);          // 等待下一个时钟
    AddressRAM = 1;
    $display("Read1 = 0x%02h (期望 3C)", read_data);
    if (read_data!==8'h3C) $fatal(1, "RAM mismatch @addr1");

    $display("*** RAMMODULE测试 PASS ✔");
    #20 $finish;
  end
endmodule
//==============================================================================
