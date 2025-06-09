`timescale 1ns/1ps
`include "params.v"
`include "rtl/bmg.v" 

module tb_BMG;

  /*---------- 1. 端口 ----------*/
  reg  Clock2, Reset;
  reg  [`WD_FSM-1:0]   ACSSegment;
  reg  [`WD_CODE-1:0]  Code;

  wire [`WD_DIST*2*`N_ACS-1:0] Distance;

  /*---------- 2. 实例 ----------*/
  BMG dut (
    .Reset      (Reset),
    .Clock2     (Clock2),
    .ACSSegment (ACSSegment),
    .Code       (Code),
    .Distance   (Distance)
  );

  /*---------- 3. 时钟 ----------*/
  initial begin
    Clock2 = 0;
    forever #5 Clock2 = ~Clock2;     // 100 MHz
  end

  /*---------- 4. 波形 ----------*/
  initial begin
    $dumpfile("bmg_tb.vcd");
    $dumpvars(0, tb_BMG);
  end

  /*---------- 5. 激励 ----------*/
  initial begin
    /* 上电复位 */
    Reset = 0;  ACSSegment = 0; Code = 0;
    #15 Reset = 1;                          // 15 ns 解除复位

    /* 第 1 个时隙：把 Code=00 写入 CodeRegister */
    ACSSegment = 6'h3F;   // 63 —> 触发寄存器锁存
    Code       = 2'b00;
    #10;                  // 等待当前 Clock2 上升沿

    /* 第 2 个时隙：切回段 0，读取距离 */
    ACSSegment = 6'd0;    // BranchID = 000000xxx
    Code       = 2'b11;   // 随意，不影响此次计算
    #1;                   // 给组合路径时间收敛

    /* 检查结果 */
    if (Distance === 16'h5258)
      $display("*** BMG 单元测试 PASS ✔  Distance = 0x%h ***", Distance);
    else begin
      $display("*** BMG 单元测试 FAIL ✘  Distance = 0x%h (期望 0x5258) ***",
                Distance);
      $stop;
    end

    #10 $finish;
  end

endmodule
