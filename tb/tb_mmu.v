//===================== tb_MMU_min.v =================================
`timescale 1ns/1ps
`include "params.v"
`include "rtl/ram.v"
`include "rtl/mmu.v"


module tb_MMU_min;

  /*---------------------------------------------------------
   * 生成 CONTROL 同款 3 相时钟
   * CLOCK   : 20 ns 周期 (50 MHz)
   * Clock1/2: CLOCK 4 分频，交替翻转，无重叠
   *--------------------------------------------------------*/
  reg CLOCK = 0;
  always #10 CLOCK = ~CLOCK;             // 50 MHz

  reg count = 0;
  reg Clock1 = 0, Clock2 = 0;
  always @(posedge CLOCK) begin
      count <= ~count;
      if (count)   Clock1 <= ~Clock1;    // 当 count=1 翻转 Clock1
      else         Clock2 <= ~Clock2;    // 当 count=0 翻转 Clock2
  end

  /*---------------------------------------------------------
   * 测试激励信号
   *--------------------------------------------------------*/
  reg Reset, Active, Hold, Init;
  reg [`WD_DEPTH-1:0]     ACSPage;
  reg [`WD_FSM-2:0]       ACSSeg_mLSB;
  reg [`N_ACS-1:0]        Survivors;
  reg [`WD_TB_ADDRESS-1:0]AddressTB;

  /*---------------------------------------------------------
   * MMU ↔ RAM 互连
   *--------------------------------------------------------*/
  wire RWSelect, ReadClock, WriteClock, RAMEnable;
  wire [`WD_RAM_ADDRESS-1:0] AddressRAM;
  wire [`WD_RAM_DATA-1:0]    DataRAM, DataTB;

  MMU mmu (
    .CLOCK   (CLOCK), .Clock1(Clock1), .Clock2(Clock2),
    .Reset   (Reset), .Active(Active), .Hold(Hold), .Init(Init),
    .ACSPage (ACSPage),
    .ACSSegment_minusLSB(ACSSeg_mLSB),
    .Survivors(Survivors),
    .DataTB  (DataTB), .AddressTB(AddressTB),
    .RWSelect(RWSelect), .ReadClock(ReadClock),
    .WriteClock(WriteClock), .RAMEnable(RAMEnable),
    .AddressRAM(AddressRAM), .DataRAM(DataRAM)
  );

  RAM ram_i (RAMEnable, AddressRAM, DataRAM, RWSelect,
             ReadClock, WriteClock);

  /*---------------------------------------------------------
   *  波形
   *--------------------------------------------------------*/
  initial begin
    $dumpfile("mmu_tb.vcd");
    $dumpvars(0, tb_MMU_min);
  end

  /*---------------------------------------------------------
   * task : 写 1 字节
   *--------------------------------------------------------*/
  task write_byte;
    input [5:0] page; input [4:0] seg; input [7:0] data;
  begin
    ACSPage     = page;
    ACSSeg_mLSB = seg;
    @(posedge Clock1) Survivors = data[3:0];
    @(posedge Clock1) Survivors = data[7:4];
    repeat(3) @(posedge CLOCK);        // 给写入足够时间
  end
  endtask

  /*---------------------------------------------------------
   * task : 读 1 字节并校验
   *--------------------------------------------------------*/
  task read_check;
    input  [5:0] page; input [4:0] seg; input [7:0] exp;
    output ok;
  begin
    ok = 0;

    /* ① 触发 Init → TBPage = page */
    @(negedge Clock2);
       Init    = 1;
       ACSPage = page + 1;
    @(negedge Clock2) Init = 0;

    /* ② 提供 AddressTB, 必须在 Clock2=0 区间 */
    @(negedge Clock2) AddressTB = seg;

    /* ③ 连续等待 2 个 Clock2 高电平窗口后取数 */
    repeat(2) @(posedge Clock2);
    #2;
    if (DataTB === exp) ok = 1;
    else
      $display("FAIL: exp=%h got=%h (page=%0d seg=%0d)",
               exp, DataTB, page, seg);
  end
  endtask

  /*---------------------------------------------------------
   * 主流程
   *--------------------------------------------------------*/
  integer pass;
  initial begin
    /* 0) reset */
    Reset=0; Active=0; Hold=0; Init=0;
    ACSPage=0; ACSSeg_mLSB=0; Survivors=0; AddressTB=0;
    #75 Reset=1; Active=1;

    /* 1) 写 page=2 seg=0 -> 0xBA */
    write_byte(6'd2, 5'd0, 8'hBA);

    /* 2) 读回并校验 */
    read_check(6'd2, 5'd0, 8'hBA, pass);

    if (pass)
      $display("\n*** MMU 单元测试 PASS ✔ DataTB=0x%h ***\n", DataTB);
    else
      $fatal(1,"MMU readback failed");

    #40 $finish;
  end
endmodule
//===================================================================
