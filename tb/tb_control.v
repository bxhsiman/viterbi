`timescale 1ns/1ps
`include "../params.v"

module tb_CONTROL;

  /*-------------------------------------------------------------
   * 1. 端口
   *------------------------------------------------------------*/
  reg  Reset, CLOCK, Active;
  wire Clock1, Clock2;
  wire [`WD_FSM-1:0]   ACSSegment;
  wire [`WD_DEPTH-1:0] ACSPage;
  wire Hold, Init, CompareStart, TB_EN;

  /*-------------------------------------------------------------
   * 2. DUT
   *------------------------------------------------------------*/
  CONTROL dut (
    .Reset        (Reset),
    .CLOCK        (CLOCK),
    .Clock1       (Clock1),
    .Clock2       (Clock2),
    .ACSPage      (ACSPage),
    .ACSSegment   (ACSSegment),
    .Active       (Active),
    .CompareStart (CompareStart),
    .Hold         (Hold),
    .Init         (Init),
    .TB_EN        (TB_EN)
  );

  /*-------------------------------------------------------------
   * 3. 主时钟 50 MHz（20 ns 周期）
   *------------------------------------------------------------*/
  initial begin
    CLOCK = 0;
    forever #10 CLOCK = ~CLOCK;
  end

  /*-------------------------------------------------------------
   * 4. 波形
   *------------------------------------------------------------*/
  initial begin
    $dumpfile("control_tb.vcd");
    $dumpvars(0, tb_CONTROL);
  end

  /*-------------------------------------------------------------
   * 5. 复位 & Active
   *------------------------------------------------------------*/
  initial begin
    Reset  = 0; Active = 0;
    #55  Reset  = 1;         // 55 ns 解除复位（非同步低电平）
        Active = 1;          // 一直工作
  end

  /*-------------------------------------------------------------
   * 6. 自动检查逻辑
   *------------------------------------------------------------*/
  integer cycle  = 0;
  reg ok_hold    = 0;
  reg ok_init    = 0;
  reg ok_cmp     = 0;
  reg ok_tb      = 0;

  /* 只在 Clock1 上升沿做判定，简化时序 */
  always @(posedge Clock1 or negedge Reset) begin
    if (~Reset) begin
      cycle <= 0;
      ok_hold = 0; ok_init = 0; ok_cmp = 0; ok_tb  = 0;
    end
    else begin
      cycle <= cycle + 1;

      /* ---------- Hold / Init 检查 ---------- */
      if (ACSSegment == 6'h3F && Hold)  ok_hold = 1;
      if (ACSSegment == 6'h00 && Init)  ok_init = 1;

      /* ---------- CompareStart 检查 ---------- */
      if (CompareStart) ok_cmp = 1;

      /* ---------- TB_EN 检查 ---------- */
      if (TB_EN) ok_tb = 1;

      /* ---------- 全部满足即 PASS ---------- */
      if (ok_hold & ok_init & ok_cmp & ok_tb) begin
        $display("\n***************************************");
        $display("*** CONTROL 单元测试 PASS ✔      ****");
        $display("***************************************\n");
        $finish;
      end

      /* ---------- 超时保护：400 µs 还没 PASS 就 FAIL ---------- */
      if (cycle > 60000) begin
        $display("\n***************************************");
        $display("*** CONTROL 单元测试 FAIL ✘        ***");
        $display("    ok_hold=%0d ok_init=%0d ok_cmp=%0d ok_tb=%0d",
                 ok_hold,  ok_init,  ok_cmp,  ok_tb);
        $display("***************************************\n");
        $finish;
      end
    end
  end

endmodule
