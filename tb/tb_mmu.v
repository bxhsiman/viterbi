//==============================================================================
// Testbench : mmu_tb.v  (pure Verilog‑2001 version)
// Purpose    : Basic functional verification of the MMU (Memory Management Unit)
//              – no SystemVerilog syntax, suitable for Icarus Verilog, ModelSim
//                or任何纯 Verilog‑2001 仿真器。
//------------------------------------------------------------------------------
// Usage
//   iverilog -g2001 -o mmu_tb.vvp mmu_tb.v rtl/mmu.v rtl/ram.v params.v
//   vvp mmu_tb.vvp
//==============================================================================

`timescale 1ns/1ps
`include "params.v"
`include "rtl/mmu.v"
`include "rtl/ram.v"

module tb_mmu;
   // -------------------------------------------------------------------------
   //  Clock generation (100 MHz → 10 ns half‑period)
   // -------------------------------------------------------------------------
   reg Clock1;   // 主时钟
   reg Clock2;   // 相位差 90°
   wire CLOCK = Clock1; // 别名，保持与 RTL 一致

   initial begin
      Clock1 = 1'b0;
      forever #10 Clock1 = ~Clock1;
   end

   initial begin
      Clock2 = 1'b1;           // 起始为高实现 90° 相移
      forever #10 Clock2 = ~Clock2;
   end

   // -------------------------------------------------------------------------
   //  控制/激励寄存器
   // -------------------------------------------------------------------------
   reg Reset, Active, Hold, Init;
   reg [`WD_DEPTH-1:0]      ACSPage;
   reg [`WD_FSM-2:0]        ACSSegment_minusLSB;
   reg [`N_ACS-1:0]         Survivors;
   reg [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB;

   // -------------------------------------------------------------------------
   //  互连线
   // -------------------------------------------------------------------------
   wire [`WD_RAM_DATA-1:0]   DataTB;
   wire [`WD_RAM_DATA-1:0]   DataRAM;
   wire [`WD_RAM_ADDRESS-1:0] AddressRAM;
   wire RWSelect, ReadClock, WriteClock, RAMEnable;

   // -------------------------------------------------------------------------
   //  DUT + 行为级 RAM
   // -------------------------------------------------------------------------
   MMU dut (
      /*SYSTEM*/   CLOCK, Clock1, Clock2,
      Reset, Active, Hold, Init,
      /*WRITE */   ACSPage, ACSSegment_minusLSB, Survivors,
      /*READ  */   DataTB, AddressTB,
      /*RAM   */   RWSelect, ReadClock, WriteClock,
                   RAMEnable, AddressRAM, DataRAM);

   RAM ram_i (RAMEnable, AddressRAM, DataRAM,
              RWSelect, ReadClock, WriteClock);

   // -------------------------------------------------------------------------
   //  VCD 波形
   // -------------------------------------------------------------------------
   initial begin
      $dumpfile("mmu_tb.vcd");
      $dumpvars(0, tb_mmu);
   end

   // -------------------------------------------------------------------------
   //  主激励序列
   // -------------------------------------------------------------------------
   initial begin : STIMULUS
      //--------------------------------------------------------------
      // 上电默认
      //--------------------------------------------------------------
      Reset   = 1'b0;  // 低有效复位保持
      Active  = 1'b0;
      Hold    = 1'b0;
      Init    = 1'b0;
      ACSPage = 0;
      ACSSegment_minusLSB = 0;
      Survivors = 0;
      AddressTB = 0;

      //--------------------------------------------------------------
      // STEP‑0 : 等待时钟稳定 (8 个 Clock1 上升沿 ≈ 80 ns)
      //--------------------------------------------------------------
      repeat (8) @(posedge Clock1);

      //--------------------------------------------------------------
      // STEP‑1 : 同步释放复位并激活核心
      //--------------------------------------------------------------
      @(posedge Clock1);
      Reset  <= 1'b1;  // 解除复位
      Active <= 1'b1;

      //--------------------------------------------------------------
      // STEP‑2 : 写入两段生存路径 0xA、0xB → 期望 8'hBA
      //--------------------------------------------------------------
      ACSPage             <= 2;  // 测试页 2
      ACSSegment_minusLSB <= 0;

      Survivors <= 4'hA;          // 低半字节
      repeat(2)@(posedge Clock1); // 等待读取
      Survivors <= 4'hB;          // 高半字节
      repeat(2)@(posedge Clock1); // 等待读取
      
      if (DataTB === 8'hBA)
         $display("\n*** 测试通过 *** – DataTB = 0x%h @ %0t ns", DataTB, $time);
      else
         $display("\n*** 测试失败 *** – 期望0xBA, 实际0x%h @ %0t ns", DataTB, $time);

      //--------------------------------------------------------------
      // STEP‑6 : 结束仿真
      //--------------------------------------------------------------
      #50;
      $finish;
   end
endmodule
