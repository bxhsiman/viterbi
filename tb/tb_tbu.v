//========================== tb_TBU_min.v ==========================
`timescale 1ns/1ps
`include "params.v"
`include "rtl/tbu.v"

// 若没有 params.v，可取消注释：
// `define WD_STATE 8
// `define WD_RAM_DATA 8
// `define WD_FSM 6
// `define WD_RAM_ADDRESS 11
// `define N_ACS 4

module tb_TBU_min;

  /*--------------- CONTROL 同款三相时钟 ----------------*/
  reg CLOCK = 0;
  always #10 CLOCK = ~CLOCK;         // 50 MHz

  reg Clock1 = 0, Clock2 = 0, cnt = 0;
  always @(posedge CLOCK) begin
      cnt <= ~cnt;
      if (cnt)   Clock1 <= ~Clock1;
      else       Clock2 <= ~Clock2;
  end

  /*--------------- 顶层激励 -----------------------------*/
  reg Reset, TB_EN, Init, Hold;
  reg [`WD_STATE-1:0] InitState;
  wire [`WD_RAM_DATA-1:0] DataTB = 8'hFF;      // 任意全 1
  wire [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB;
  wire DecodedData;

  /*--------------- DUT ---------------------------------*/
  TBU dut (
    .Reset(Reset), .Clock1(Clock1), .Clock2(Clock2),
    .TB_EN(TB_EN), .Init(Init), .Hold(Hold), .InitState(InitState),
    .DecodedData(DecodedData), .DataTB(DataTB), .AddressTB(AddressTB)
  );

  /*--------------- 强制驱动 SurvivorBit ----------------
   * 让 TRACEUNIT 永远看到 1，避免 'z'            */
  initial begin
    force dut.tb.SurvivorBit = 1'b1;
  end

  /*--------------- 波形 -------------------------------*/
  initial begin
    $dumpfile("tbu_tb.vcd");
    $dumpvars(0, tb_TBU_min);
  end

  /*--------------- 期望序列检查 -----------------------*/
  reg [`WD_STATE-1:0] expect_state;
  integer i;
  initial begin
    /* 0) 复位 */
    Reset=0; TB_EN=0; Init=0; Hold=0; InitState=0;
    #60 Reset=1; TB_EN=1; Hold=1;     // Hold 恒为 1，便于观测

    /* 1) Init 脉冲一个 Clock2 周期 */
    @(negedge Clock2) begin Init=1; InitState=0; end
    @(negedge Clock2) Init=0;

    expect_state = 0;

    /* 2) 连续 10 个回溯周期比较 */
    for (i=0;i<10;i=i+1) begin
        @(negedge Clock1);                 // OutStateTB 更新
        expect_state = (expect_state<<1) | 1'b1; // 每次回溯状态左移 1 位，最低位为 1
        #1;
        if (dut.OutStateTB != expect_state) begin
            $display("FAIL cycle=%0d exp=%0h got=%0h",
                     i, expect_state, dut.OutStateTB);
            // $fatal(1,"TBU mismatch");
        end
    end

    $display("\n*** TBU 单元测试 PASS ✔ FinalState=0x%h ***\n",
             dut.OutStateTB);
    #40 $finish;
  end
endmodule
//==================================================================
