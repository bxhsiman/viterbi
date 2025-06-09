`include "params.v"
`include "viterbi_encode9.v"
`include "decoder.v"

module VD_err;

   /*==============================================================
    * 1. 时钟 / 复位
    *==============================================================*/
   reg CLOCK = 0;
   always #(`HALF/2) CLOCK = ~CLOCK;

   reg Reset;
   initial begin
      Reset = 1;
      #200 Reset = 0;
      #300 Reset = 1;
   end

   /*==============================================================
    * 2. 原始数据信号 X：把想测的比特序列写在 pattern 里
    *==============================================================*/
   reg X = 0;

   localparam PAT_LEN = 18;
   reg [0:PAT_LEN-1] pattern = 18'b1_0101_1010_1_0101_1010;
   integer i;

   initial begin
      #475;                                      
      for (i = 0; i < PAT_LEN; i = i + 1) begin
         X = pattern[i];
         #`DPERIOD;
      end
      X = 0;                                     // 送完清零
   end

   /*==============================================================
    * 3. Viterbi(9) 编码器 —— 得到无误码字 EncCode
    *==============================================================*/
   reg  D_CLOCK = 0;
   always #(`DPERIOD/2) D_CLOCK <= ~D_CLOCK;

   reg  DRESET;
   initial begin
      DRESET = 1;
      #200 DRESET = 0;
      #300 DRESET = 1;
   end

   wire [`WD_CODE-1:0] EncCode;    // 编码器输出（正确码字）

   viterbi_encode9 enc(X,EncCode,D_CLOCK,DRESET);

   /*==============================================================
    * 4. 参考码字 CorrectCode：直接同步保存 EncCode
    *==============================================================*/
   reg [`WD_CODE-1:0] CorrectCode = 0;
   always @(posedge D_CLOCK or negedge Reset)
      if (!Reset) CorrectCode <= 0;
      else        CorrectCode <= EncCode;

   /*==============================================================
    * 5. 信道：随机翻转 ERR_NUM 次比特，生成带错码字 Code
    *==============================================================*/
   parameter ERR_NUM = 10;            // N处反转
   integer   err_cnt = 0;

   reg [`WD_CODE-1:0] Code = 0;

   always @(posedge D_CLOCK or negedge Reset) begin
      if (!Reset) begin
         Code    <= 0;
         err_cnt <= 0;
      end else begin
         Code <= EncCode;             // 默认无误码直通

         if (err_cnt < ERR_NUM) begin
               Code    <= EncCode ^ (1'b1 << ($random % `WD_CODE));  
               err_cnt <= err_cnt + 1;
         end
      end
   end

   /*==============================================================
    * 6. Active 信号（沿用原逻辑）
    *==============================================================*/
   reg Active;
   always @(*) begin
      if (!Reset)      Active = 0;
      else if (Code!=0) Active = 1;
   end

   /*==============================================================
    * 7. Viterbi 解码器
    *==============================================================*/
   wire DecodeOut;

   VITERBIDECODER vd (Reset, CLOCK, Active, Code, DecodeOut);

   /*==============================================================
    * 8. 波形与结果检查
    *==============================================================*/
   initial begin
      $dumpfile("vd_err.vcd");
      $dumpvars(0, VD_err);
      $display("=== Viterbi Decoder Random-Error Test ===");

    #100000;  

   end

endmodule
