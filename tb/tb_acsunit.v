`timescale 1ns/1ps
`include "params.v"          // 必须已包含 WD_* 和 N_ACS 等宏
`include "rtl/acs.v"     // 包含ACSUNIT模块定义
// 若还没写，可临时加：
// `define WD_DIST 2
// `define WD_METR 8
// `define WD_FSM  6
// `define WD_STATE 8
// `define N_ACS  4

module tb_ACSUNIT;

  /*----------------------------------------------------------
   *  1. 端口声明
   *---------------------------------------------------------*/
  reg  Clock1, Clock2, Reset;
  reg  Active, Init, Hold, CompareStart;
  reg  [`WD_FSM-1:0]                    ACSSegment;
  reg  [`WD_DIST*2*`N_ACS-1:0]          Distance;
  reg  [`WD_METR*2*`N_ACS-1:0]          MMPathMetric;

  wire [`N_ACS-1:0]                     Survivors;
  wire [`WD_STATE-1:0]                  LowestState;
  wire [`WD_FSM-2:0]                    MMReadAddress;
  wire [`WD_FSM-1:0]                    MMWriteAddress;
  wire                                  MMBlockSelect;
  wire [`WD_METR*`N_ACS-1:0]            MMMetric;

  /*----------------------------------------------------------
   *  2. DUT 实例
   *---------------------------------------------------------*/
  ACSUNIT dut (
    .Reset         (Reset),
    .Clock1        (Clock1),
    .Clock2        (Clock2),
    .Active        (Active),
    .Init          (Init),
    .Hold          (Hold),
    .CompareStart  (CompareStart),
    .ACSSegment    (ACSSegment),
    .Distance      (Distance),
    .Survivors     (Survivors),
    .LowestState   (LowestState),
    .MMReadAddress (MMReadAddress),
    .MMWriteAddress(MMWriteAddress),
    .MMBlockSelect (MMBlockSelect),
    .MMMetric      (MMMetric),
    .MMPathMetric  (MMPathMetric)
  );

  /*----------------------------------------------------------
   *  3. 双时钟：100 MHz，同周期间隔 180°
   *---------------------------------------------------------*/
  initial begin Clock1 = 0; forever #5 Clock1 = ~Clock1; end
  initial begin Clock2 = 1; forever #5 Clock2 = ~Clock2; end

  /*----------------------------------------------------------
   *  4. 波形输出
   *---------------------------------------------------------*/
  initial begin
    $dumpfile("acsunit_tb.vcd");
    $dumpvars(0, tb_ACSUNIT);
  end

  /*----------------------------------------------------------
   *  5. 激励序列
   *---------------------------------------------------------*/
  initial begin
    /* ---- 上电复位 ---- */
    Reset = 0; Active = 0; Init = 0; Hold = 0; CompareStart = 0;
    ACSSegment = 6'd0;
    Distance   = 0;
    MMPathMetric = 0;
    #20 Reset = 1;               // 20 ns 解除复位

    /* ---- 单段数据 ---- */
    Active = 1;
    Init   = 1;                  // 码字开始
    CompareStart = 1;

    /* 8 个分支度量（2 bit × 8）*/
    // {D7,D6,D5,D4,D3,D2,D1,D0}
    Distance = {
      2'd3, 2'd2, 2'd3, 2'd1,   // 高 4 个
      2'd3, 2'd1, 2'd2, 2'd1    // 低 4 个
    };

    /* 8 个路径度量（8 bit × 8）*/
    // {P7,P6,P5,P4,P3,P2,P1,P0}
    MMPathMetric = {
      8'd35, 8'd40, 8'd25, 8'd30,
      8'd20, 8'd1, 8'd15, 8'd10
    };

    /* ---- Init 保持 1 个 Clock2 的负沿 ---- */
    #12 Init = 0;                // 让 LOWESTPICK 完成第一次初始化

    /* ---- 给一点时间跑流水线，然后 Hold 锁存结果 ---- */
    #20 Hold = 1;                // 在 Clock1 的负沿采样
    #10 Hold = 0;

    /* ---- 打印关键结果 (手动期望值见注释) ---- */
    #1;
    $display("==================================================");
    $display("  Survivors   = %b (期望 1110)", Survivors);
    $display("  MMMetric(0) = %0d (期望 11)",  MMMetric[ 7: 0]);
    $display("  MMMetric(1) = %0d (期望 20)",  MMMetric[15: 8]);
    $display("  MMMetric(2) = %0d (期望 28)",  MMMetric[23:16]);
    $display("  MMMetric(3) = %0d (期望 35)",  MMMetric[31:24]);
    $display("  LowestState = 0x%02h (期望 00)", LowestState);
    $display("==================================================");

    #20 $finish;
  end

endmodule
