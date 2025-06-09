`timescale 1ns/1ps
`include "../params.v"          // 确保已定义 N_ACS, WD_RAM_DATA 等宏


module buff_tb;
  reg                  Reset, Clock1, Active, SurvRDY;
  reg  [`N_ACS-1:0]    Survivors;
  wire [`WD_RAM_DATA-1:0] WrittenSurvivors;

  // 实例化待测模块
  ACSSURVIVORBUFFER uut (
    .Reset(Reset),
    .Clock1(Clock1),
    .Active(Active),
    .SurvRDY(SurvRDY),
    .Survivors(Survivors),
    .WrittenSurvivors(WrittenSurvivors)
  );

  // 产生 Clock1
  initial Clock1 = 0;
  always #5 Clock1 = ~Clock1;  // 100 MHz

  initial begin
    // 打开波形输出
    $dumpfile("buff_tb.vcd");
    $dumpvars(0, buff_tb);

    // 初始信号
    Reset     = 0;
    Active    = 0;
    SurvRDY   = 0;
    Survivors = 0;

    #12;
    Reset  = 1;
    Active = 1;

    // --- 第一次上升沿： latch 第一个 Survivors ---
    Survivors = 4'b1010;
    SurvRDY   = 0;    // 不输出
    @(posedge Clock1); // 等待上升沿
    #1;
    // --- 第二次上升沿： latch 第二个 Survivors 并输出拼接结果 ---
    Survivors = 4'b0101;
    SurvRDY   = 1;    // 此时输出 {当前, 上一次}
    @(posedge Clock1); // 等待上升沿
    // 预期输出：{4'b0101, 4'b1010} = 8'b0101_1010 = 0x5A
    if (WrittenSurvivors !== 8'h5A)
      $display("** TEST FAILED **  Expected=0x5A,  Got=0x%0h", WrittenSurvivors);
    else
      $display("** TEST PASSED **  WrittenSurvivors = 0x%0h", WrittenSurvivors);

    #20;
    $finish;
  end

endmodule
