`timescale 1ns/1ps
`include "../params.v"          // 确保已定义 WD_DIST=2, WD_METR=8 等宏
// 若暂时没有 params.v，也可以手动写：
// `define WD_DIST 2
// `define WD_METR 8

module tb_ACS;

  /*-------------------------------------
   * 信号声明
   *------------------------------------*/
  reg                         CompareEnable;
  reg  [`WD_DIST-1:0]         Distance1, Distance0;
  reg  [`WD_METR-1:0]         PathMetric1, PathMetric0;
  wire                        Survivor;
  wire [`WD_METR-1:0]         Metric;

  /*-------------------------------------
   * DUT 实例
   *------------------------------------*/
  ACS dut (
    .CompareEnable (CompareEnable),
    .Distance1     (Distance1),
    .Distance0     (Distance0),
    .PathMetric1   (PathMetric1),
    .PathMetric0   (PathMetric0),
    .Survivor      (Survivor),
    .Metric        (Metric)
  );

  /*-------------------------------------
   * 产生波形
   *------------------------------------*/
  initial begin
    $dumpfile("acs_tb.vcd");   // 输出文件名
    $dumpvars(0, tb_ACS);      // 记录整个 testbench 层级
  end

  /*-------------------------------------
   * 测试向量
   *------------------------------------*/
  initial begin
    /* -------- Case-1 : ADD0 更小 ---------- */
    CompareEnable = 1'b1;
    Distance0     = 2'd1;      // ADD0 = 1 + 10 = 11
    PathMetric0   = 8'd10;
    Distance1     = 2'd2;      // ADD1 = 2 + 15 = 17
    PathMetric1   = 8'd15;
    #10;
    $display("Case-1 -> Survivor=%0d (期望0), Metric=%0d (期望11)", 
              Survivor, Metric);

    /* -------- Case-2 : ADD1 更小 ---------- */
    Distance0     = 2'd3;      // ADD0 = 3 + 20 = 23
    PathMetric0   = 8'd20;
    Distance1     = 2'd0;      // ADD1 = 0 + 18 = 18
    PathMetric1   = 8'd18;
    #10;
    $display("Case-2 -> Survivor=%0d (期望1), Metric=%0d (期望18)", 
              Survivor, Metric);

    /* -------- Case-3 : 关闭比较 ---------- */
    CompareEnable = 1'b0;      // 按规格输出 ADD0
    Distance0     = 2'd3;      // ADD0 = 3 + 5 = 8
    PathMetric0   = 8'd5;
    Distance1     = 2'd3;      // ADD1 = 3 + 0 = 3 (更小但被忽略)
    PathMetric1   = 8'd0;
    #10;
    $display("Case-3 -> Survivor=%0d (无关), Metric=%0d (期望8)", 
              Survivor, Metric);

    #10 $finish;
  end

endmodule
