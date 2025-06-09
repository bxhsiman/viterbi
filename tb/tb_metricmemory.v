//================ tb_METRICMEMORY_syncclk_fix.v =====================
`timescale 1ns/1ps
`include "../params.v"

module tb_METRICMEMORY;

  /*--------- DUT 端口 ---------*/
  reg  Reset, Clock1, Active;
  reg  MMBlockSelect;                            // 0=A写B读, 1=B写A读
  reg  [5:0] MMWriteAddress;
  reg  [4:0] MMReadAddress;
  reg  [`WD_METR*`N_ACS-1:0] MMMetric;
  wire [`WD_METR*2*`N_ACS-1:0] MMPathMetric;

  METRICMEMORY dut (
    .Reset         (Reset),
    .Clock1        (Clock1),
    .Active        (Active),
    .MMReadAddress (MMReadAddress),
    .MMWriteAddress(MMWriteAddress),
    .MMBlockSelect (MMBlockSelect),
    .MMMetric      (MMMetric),
    .MMPathMetric  (MMPathMetric)
  );

  /*--------- 50 MHz 时钟 --------*/
  initial begin Clock1 = 0; forever #10 Clock1 = ~Clock1; end

  /*--------- 波形 --------*/
  initial begin
    $dumpfile("metricmemory_tb.vcd");
    $dumpvars(0, tb_METRICMEMORY);
  end

  /*--------- task : 写 32-bit --------*/
  task write_word;
    input blkSel;             // 0=A 1=B
    input [5:0] addr;
    input [31:0] data;
  begin
    @(posedge Clock1);
    MMBlockSelect  = blkSel;
    MMWriteAddress = addr;
    MMMetric       = data;
    @(negedge Clock1);        // 负沿进入 DUT 写触发
  end
  endtask

  /*--------- task : 期望读 64-bit ------*/
  task expect_read;
    input  [4:0]  raddr;
    input  [63:0] expected;
    output        pass;
  begin
    pass = 0;

    /* 先跳到一个临时地址 → 再跳回目标地址，确保触发组合逻辑 */
    @(posedge Clock1);
      MMReadAddress = raddr ^ 5'b1;       // 临时不同地址
    @(posedge Clock1);
      MMReadAddress = raddr;              // 目标地址
    @(negedge Clock1);                    // 负沿后数据已更新

    if (MMPathMetric === expected)
      pass = 1;
    else
      $display("ERROR: addr=%0d  exp=%h  got=%h",
               raddr, expected, MMPathMetric);
  end
  endtask

  /*--------- 主测试流程 -------------*/
  reg ok;
  initial begin
    /* 1) 复位 */
    Reset=0; Active=0;
    MMBlockSelect=0; MMMetric=0;
    MMWriteAddress=0; MMReadAddress=0;
    #35 Reset=1; Active=1;

    /* 2) 写 B 块（sel=1） */
    write_word(1, 6'd0, 32'hDEADBEEF);    // B[0]
    write_word(1, 6'd1, 32'hCAFEBABE);    // B[1]

    /* 3) sel=0 → 读 B */
    @(posedge Clock1) MMBlockSelect = 0;  // 切块
    expect_read(0, {32'hCAFEBABE,32'hDEADBEEF}, ok);
    if (!ok) $fatal(1, "Ping-pong read B failed!");

    /* 4) 写 A 块（sel=0） */
    write_word(0, 6'd2, 32'h11112222);    // A[2]
    write_word(0, 6'd3, 32'h33334444);    // A[3]

    /* 5) sel=1 → 读 A */
    @(posedge Clock1) MMBlockSelect = 1;
    expect_read(1, {32'h33334444,32'h11112222}, ok);
    if (!ok) $fatal(1, "Ping-pong read A failed!");

    $display("\n*** METRICMEMORY 单元测试 PASS ✔ ***\n");
    #20 $finish;
  end

endmodule
//====================================================================
