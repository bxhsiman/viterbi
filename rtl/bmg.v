//==============================================================================
// 文件名: bmg.v
// 描述: Viterbi解码器中的分支度量生成器 (Branch Metric Generator)
//
// 模块功能和原理:
// 1. BMG单元负责计算Viterbi解码中的分支度量(Branch Metric)
// 2. 根据接收到的编码符号和各分支对应的期望输出，计算汉明距离
// 3. 主要包含以下几个子模块：
//    - BMG: 顶层模块，协调分支度量计算流程
//    - ENC: 卷积编码器，根据生成多项式计算期望输出
//    - HARD_DIST_CALC: 硬判决距离计算器，计算汉明距离
//
// 运行流程:
// 1. 接收编码符号Code和当前处理的FSM段ACSSegment
// 2. 根据ACSSegment生成8个分支标识符(B0-B7)
// 3. 使用ENC模块计算每个分支的期望编码输出(G0-G7)
// 4. 通过HARD_DIST_CALC计算接收符号与期望输出的汉明距离
// 5. 输出8个分支度量Distance供ACS单元使用
//
// 编码参数:
// - 生成多项式A: 110101111 (八进制657)
// - 生成多项式B: 100011101 (八进制435)
// - 约束长度: 9位
// - 编码率: 1/2
//==============================================================================

`include "../params.v"

//==============================================================================
// 模块名: BMG
// 功能: 分支度量生成器顶层模块，计算所有分支的度量值
// 输入:
//   - Reset: 复位信号
//   - Clock2: 时钟信号，用于符号寄存器更新
//   - ACSSegment: 当前处理的FSM段地址
//   - Code: 接收到的编码符号
// 输出:
//   - Distance: 8个分支度量值的组合
//==============================================================================
module BMG (Reset, Clock2, ACSSegment, Code, Distance);

// 输入端口定义
input Reset, Clock2;                      // 控制信号
input [`WD_FSM-1:0] ACSSegment;          // FSM段地址(6位)
input [`WD_CODE-1:0] Code;               // 接收的编码符号(2位)

// 输出端口定义
output [`WD_DIST*2*`N_ACS-1:0] Distance; // 8个分支度量的组合输出

// 生成多项式定义
wire  [`WD_STATE:0] PolyA, PolyB;        // 卷积码生成多项式
wire [`WD_STATE:0] wA, wB;               // 临时计算信号

// 卷积码生成多项式 (约束长度9, 编码率1/2)
assign   PolyA = 9'b110_101_111;         // 生成多项式A (八进制657)
assign   PolyB = 9'b100_011_101;         // 生成多项式B (八进制435)

// 分支标识符信号 (注意宽度为WD_STATE+1)
wire [`WD_STATE:0] B0,B1,B2,B3,B4,B5,B6,B7;  

// 编码器输出信号
wire [`WD_CODE-1:0] G0,G1,G2,G3,G4,G5,G6,G7; // 各分支的期望编码输出

// 距离计算输出信号
wire [`WD_DIST-1:0] D0,D1,D2,D3,D4,D5,D6,D7; // 各分支的汉明距离

// 符号寄存器
reg [`WD_CODE-1:0] CodeRegister;         // 编码符号寄存器

   // 符号寄存器更新逻辑
   // 在ACSSegment为最大值(0x3F)时锁存新的编码符号
   always @(posedge Clock2 or negedge Reset)
   begin
     if (~Reset) CodeRegister <= 0;
     else if (ACSSegment == 6'h3F) CodeRegister <= Code;
   end

   // 分支标识符生成
   // 根据ACSSegment和3位分支编号构成完整的9位分支标识
   assign B0 = {ACSSegment,3'b000};      // 分支0: ACSSegment + 000
   assign B1 = {ACSSegment,3'b001};      // 分支1: ACSSegment + 001
   assign B2 = {ACSSegment,3'b010};      // 分支2: ACSSegment + 010
   assign B3 = {ACSSegment,3'b011};      // 分支3: ACSSegment + 011
   assign B4 = {ACSSegment,3'b100};      // 分支4: ACSSegment + 100
   assign B5 = {ACSSegment,3'b101};      // 分支5: ACSSegment + 101
   assign B6 = {ACSSegment,3'b110};      // 分支6: ACSSegment + 110
   assign B7 = {ACSSegment,3'b111};      // 分支7: ACSSegment + 111

   // 编码器实例化 - 计算期望的编码输出
   // 只需要4个编码器，因为相邻分支的输出互为反码
   ENC EN0(PolyA,PolyB,B0,G0); assign G1 = ~G0; // G1是G0的反码
   ENC EN2(PolyA,PolyB,B2,G2); assign G3 = ~G2; // G3是G2的反码
   ENC EN4(PolyA,PolyB,B4,G4); assign G5 = ~G4; // G5是G4的反码
   ENC EN6(PolyA,PolyB,B6,G6); assign G7 = ~G6; // G7是G6的反码
      
   // 汉明距离计算器实例化
   // 计算接收符号与各分支期望输出之间的汉明距离
   HARD_DIST_CALC HD0(CodeRegister,G0,D0); // 分支0的汉明距离
   HARD_DIST_CALC HD1(CodeRegister,G1,D1); // 分支1的汉明距离
   HARD_DIST_CALC HD2(CodeRegister,G2,D2); // 分支2的汉明距离
   HARD_DIST_CALC HD3(CodeRegister,G3,D3); // 分支3的汉明距离
   HARD_DIST_CALC HD4(CodeRegister,G4,D4); // 分支4的汉明距离
   HARD_DIST_CALC HD5(CodeRegister,G5,D5); // 分支5的汉明距离
   HARD_DIST_CALC HD6(CodeRegister,G6,D6); // 分支6的汉明距离
   HARD_DIST_CALC HD7(CodeRegister,G7,D7); // 分支7的汉明距离
   
   // 输出距离总线组合
   assign Distance = {D7,D6,D5,D4,D3,D2,D1,D0}; // 8个分支度量的组合
   
endmodule

//==============================================================================
// 模块名: HARD_DIST_CALC
// 功能: 硬判决距离计算器，计算两个2位符号之间的汉明距离
// 原理: 对应位进行异或操作，统计不同位的数量
//==============================================================================
module HARD_DIST_CALC (InputSymbol, BranchOutput, OutputDistance);

// 输入信号
input [`WD_CODE-1:0] InputSymbol, BranchOutput; // 输入符号和分支输出(均为2位)

// 输出信号
output [`WD_DIST-1:0] OutputDistance;           // 汉明距离(2位)
reg [`WD_DIST-1:0] OutputDistance;

// 内部信号
wire MS, LS;                                     // 最高位和最低位的异或结果

   // 计算各位的异或结果
   assign MS = (InputSymbol[1] ^ BranchOutput[1]); // 最高位异或
   assign LS = (InputSymbol[0] ^ BranchOutput[0]); // 最低位异或

   // 汉明距离计算逻辑
   always @(MS or LS)
   begin
      // 汉明距离 = 不同位的数量
      // 如果两位都不同: MS=1, LS=1 → Distance=10 (十进制2)
      // 如果一位不同:   MS^LS=1   → Distance=01 (十进制1)  
      // 如果全部相同:   MS=0, LS=0 → Distance=00 (十进制0)
      OutputDistance[1] <= MS & LS;  // 高位: 当两位都不同时为1
      OutputDistance[0] <= MS ^ LS;  // 低位: 当恰好一位不同时为1
   end

endmodule

//==============================================================================
// 模块名: ENC
// 功能: 卷积编码器，根据生成多项式计算分支的期望编码输出
// 原理: 使用两个生成多项式对输入分支标识进行卷积运算
//==============================================================================
module ENC (PolyA, PolyB, BranchID, EncOut);

// 输入信号
input [`WD_STATE:0] PolyA,PolyB;   // 两个生成多项式(9位)
input [`WD_STATE:0] BranchID;      // 分支标识符(9位状态)

// 输出信号
output [`WD_CODE-1:0] EncOut;      // 编码输出(2位)

// 内部信号
wire [`WD_STATE:0] wA, wB;         // 多项式与分支ID的按位与结果
reg [`WD_CODE-1:0] EncOut;

   // 计算生成多项式与分支ID的按位与
   assign wA = PolyA & BranchID;   // 多项式A与分支ID按位与
   assign wB = PolyB & BranchID;   // 多项式B与分支ID按位与

   // 卷积编码计算
   always @(wA or wB)
   begin
        // 编码输出高位: 对wA所有位进行异或运算
        EncOut[1] = (((wA[0]^wA[1]) ^ (wA[2]^wA[3]))^((wA[4]^wA[5]) ^ 
                    (wA[6]^wA[7]))^wA[8]);
        
        // 编码输出低位: 对wB所有位进行异或运算            
        EncOut[0] = (((wB[0]^wB[1]) ^ (wB[2]^wB[3]))^((wB[4]^wB[5]) ^ 
                    (wB[6]^wB[7]))^wB[8]);
   end

endmodule