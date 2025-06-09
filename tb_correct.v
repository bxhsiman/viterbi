`include "params.v"	
`include "decoder.v"
`include "viterbi_encode9.v"

module VD();


   reg CLOCK;
   initial CLOCK = 0;
   always #(`HALF/2) CLOCK = ~CLOCK;
   
   reg Reset;
   reg DRESET;

   initial begin 
      DRESET = 1; 
      Reset = 1; 
      #200 Reset = 0;DRESET=0;
      #300 Reset = 1; 
      DRESET = 1; 
   end

   reg X;
   wire [`WD_CODE-1:0] Code;
   initial X = 0;
   // 比特序列：这里演示 10101_1100_1110_0011（可自行修改）
   reg [0:15] pattern = 16'b1_0_1_0_1_0_1_0_0_1_1_1_0_1_0_1;
   integer k;

   initial begin
      X = 0;          // 上电默认 0
      #475;           
      for (k = 0; k < $bits(pattern); k = k + 1) begin
         X = pattern[k];
         #`DPERIOD;
      end
   end

   reg D_CLOCK;
   initial D_CLOCK = 0; 
      
   always #(`DPERIOD/2) D_CLOCK <= ~D_CLOCK; 
    
      
   viterbi_encode9 enc(X,Code,D_CLOCK,DRESET);

   reg Active;
   always @(Code or Reset) 				
     if (~Reset) Active <= 0; 				
     else if (Code!=0) Active <= 1;			

   wire DecodeOut;

   VITERBIDECODER vd (Reset, CLOCK, Active, Code, DecodeOut);

   initial begin
      $dumpfile("tb_correct.vcd");
      $dumpvars(0, VD);
      $display("=== Viterbi Decoder Test ===");
      
      // 等待一段时间以观察波形
      #1000;
   end

endmodule