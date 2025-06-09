//==============================================================================
// File   : mmu_tb.v
// Purpose: Verification TB – MMU + real RAM
//==============================================================================

`timescale 1ns/1ps
`include "../params.v"

//-------------------------------------------------------------- TB 顶层 ------
module mmu_tb;

   //--------------------------- 时钟 / 复位 -------------------------------
   reg Clock1 = 0;  always #5  Clock1 = ~Clock1;   // 100 MHz
   reg Clock2 = 0;  always #10 Clock2 = ~Clock2;   // 50 MHz
   wire CLOCK = Clock2;                            // MMU 中 AddressRAM 用

   reg Reset  = 0;
   reg Active = 0;
   reg Hold   = 0;
   reg Init   = 0;

   //--------------------------- 其它激励 ----------------------------------
   reg [`WD_DEPTH-1:0]            ACSPage             = 0;
   reg [`WD_FSM-2:0]              ACSSegment_minusLSB = 0;
   reg [`N_ACS-1:0]               Survivors           = 0;

   reg [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB        = 0;
   reg                               tb_start         = 0; // 开始回溯标志

   //--------------------------- 互连总线 -----------------------------------
   wire [`WD_RAM_DATA-1:0] DataBus;     // 三态公共总线
   wire [`WD_RAM_DATA-1:0] DataTB;
   wire RWSelect, ReadClock, WriteClock, RAMEnable;
   wire [`WD_RAM_ADDRESS-1:0] AddressRAM;

   //--------------------------- 参考模型 -----------------------------------
   localparam RAMDEPTH = (1 << `WD_RAM_ADDRESS);
   reg [`WD_RAM_DATA-1:0] mem_ref [0:RAMDEPTH-1];
   integer i;
   initial for (i = 0; i < RAMDEPTH; i = i + 1) mem_ref[i] = 0;

   //--------------------------- DUT & RAM ---------------------------------
   MMU dut (
      .CLOCK                   (CLOCK),
      .Clock1                  (Clock1),
      .Clock2                  (Clock2),
      .Reset                   (Reset),
      .Active                  (Active),
      .Hold                    (Hold),
      .Init                    (Init),
      .ACSPage                 (ACSPage),
      .ACSSegment_minusLSB     (ACSSegment_minusLSB),
      .Survivors               (Survivors),
      .DataTB                  (DataTB),
      .AddressTB               (AddressTB),
      .RWSelect                (RWSelect),
      .ReadClock               (ReadClock),
      .WriteClock              (WriteClock),
      .RAMEnable               (RAMEnable),
      .AddressRAM              (AddressRAM),
      .DataRAM                 (DataBus)
   );

   // 真正的 三态 RAM
   RAM sram (
      .RAMEnable  (RAMEnable),
      .AddressRAM (AddressRAM),
      .DataRAM    (DataBus),
      .RWSelect   (RWSelect),
      .ReadClock  (ReadClock),
      .WriteClock (WriteClock)
   );

   //--------------------------- 复位 / 激励 -------------------------------
   initial begin
      $dumpfile("mmu_tb.vcd");
      $dumpvars(0, mmu_tb);

      Reset  = 0; Active = 0; Init = 0;
      #25  Reset  = 1;
      #10  Active = 1;  Init = 1;
      #20  Init   = 0;                      // 复位、初始化完毕
   end

   // 写侧激励（Survivors、Segment、Page 计数器）
   always @(negedge Clock2)
     if (Active) begin
        Survivors <= Survivors + 1;
        if (ACSSegment_minusLSB == ((1<<(`WD_FSM-1))-1)) begin
            ACSSegment_minusLSB <= 0;
            ACSPage             <= ACSPage + 1;
        end else
            ACSSegment_minusLSB <= ACSSegment_minusLSB + 1;
     end

   // -------- 等写满一页再开始回溯 ----------
   initial begin
      @(negedge Init);                               // 等 INIT 结束
      repeat( (1<<`WD_FSM) ) @(posedge Clock2);      // 写满 1 页
      tb_start = 1;
   end

   always @(posedge Clock2) if (Active && tb_start)
      AddressTB <= AddressTB + 1;

   //-------------------- 在写周期更新参考模型 ------------------------------
   always @(negedge WriteClock)
     if (Active && !RWSelect && ~RAMEnable)
        mem_ref[AddressRAM] <= DataBus;

   //-------------------- 在读周期比较 --------------------------------------
   integer errors = 0;
   always @(negedge ReadClock)
     if (Active && tb_start && RWSelect && ~RAMEnable) begin
        if ((DataTB !== mem_ref[AddressRAM])) begin
           $display("[ERROR] @%0t ns  Addr=%0d  Exp=%02h  Got=%02h",
                     $time, AddressRAM, mem_ref[AddressRAM], DataTB);
           errors = errors + 1;
        end
     end

   //-------------------- 结束 ---------------------------------------------
   initial begin
      #4000;                                         // 仿真 4 µs
      $display("================================================");
      if (errors == 0)
         $display("MMU + RAM TB PASSED.");
      else
         $display("MMU + RAM TB FAILED: %0d mismatches.", errors);
      $display("================================================");
      $finish;
   end

endmodule
