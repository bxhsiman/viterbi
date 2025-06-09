//==============================================================================
// 文件名: tbu.v
// 描述: Viterbi解码器的回溯单元 (Traceback Unit)
//
// 模块功能和原理:
// 1. TBU是Viterbi解码器的回溯单元，负责从生存路径中恢复原始数据
// 2. 从具有最小路径度量的状态开始，向后回溯生存路径
// 3. 通过分析生存路径的选择位，重构原始的输入数据序列
//
// 主要功能:
// - 状态回溯: 从初始状态开始，按照生存路径向前推进状态
// - 地址生成: 根据当前状态生成RAM读取地址
// - 数据解码: 从生存路径信息中提取原始数据位
// - 时序控制: 协调状态更新和数据输出的时序
//
// 运行流程:
// 1. 初始化: 设置初始状态为最小度量状态
// 2. 状态转移: 根据生存路径信息计算下一状态
// 3. 地址生成: 从当前状态的高位生成RAM访问地址
// 4. 数据提取: 从RAM读取的生存路径中提取对应的选择位
// 5. 输出解码: 将状态的最高位作为解码后的原始数据
//
// 状态机制:
// - CurrentState: 当前回溯状态，用于生成访问地址
// - NextState: 下一个状态，通过移位和添加生存位计算
// - OutState: 输出状态，在Hold信号有效时更新
//==============================================================================

`include "params.v"

//==============================================================================
// 模块名: TBU
// 功能: 回溯单元顶层模块，实例化具体的回溯逻辑
// 输入:
//   - Reset: 全局复位信号
//   - Clock1, Clock2: 双相时钟信号
//   - TB_EN: 回溯使能信号
//   - Init, Hold: 控制信号
//   - InitState: 初始状态(通常是最小度量状态)
//   - DataTB: 从RAM读取的生存路径数据
// 输出:
//   - DecodedData: 解码后的原始数据位
//   - AddressTB: RAM访问地址
//==============================================================================
module TBU (Reset, Clock1, Clock2, TB_EN, Init, Hold, InitState, 
            DecodedData, DataTB, AddressTB);

// 输入端口定义
input Reset, Clock1, Clock2, Init, Hold;     // 控制信号
input [`WD_STATE-1:0] InitState;             // 初始状态(最小度量状态)
input TB_EN;                                 // 回溯使能信号

// 与存储器管理单元的接口
input [`WD_RAM_DATA-1:0] DataTB;             // 从RAM读取的生存路径数据
output [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB; // RAM访问地址

// 输出端口定义
output DecodedData;                          // 解码后的原始数据位

// 内部连接信号
wire [`WD_STATE-1:0] OutStateTB;             // 回溯单元输出状态

   // 实例化回溯核心单元
   TRACEUNIT tb (Reset, Clock1, Clock2, TB_EN, InitState, Init, Hold, 
                 DataTB, AddressTB, OutStateTB);
   
   // 解码数据提取: 取状态的最高位作为解码结果
   assign DecodedData = OutStateTB [`WD_STATE-1];

endmodule

//==============================================================================
// 模块名: TRACEUNIT
// 功能: 回溯单元核心逻辑，实现状态回溯和数据解码
// 原理: 维护当前状态，根据生存路径信息计算下一状态，
//       并在适当时机输出解码数据
//==============================================================================
module TRACEUNIT (Reset, Clock1, Clock2, Enable, InitState, Init, Hold, 
                  Survivor, AddressTB, OutState);

// 输入信号定义
input Reset, Clock1, Clock2, Enable;         // 基本控制信号
input [`WD_STATE-1:0] InitState;             // 初始化状态
input Init, Hold;                            // 状态控制信号
input [`WD_RAM_DATA-1:0] Survivor;           // 生存路径数据

// 输出信号定义
output [`WD_STATE-1:0] OutState;             // 输出状态
output [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB; // RAM访问地址

// 内部状态寄存器
reg [`WD_STATE-1:0] CurrentState;            // 当前回溯状态
reg [`WD_STATE-1:0] NextState;               // 下一个状态
reg [`WD_STATE-1:0] OutState;                // 输出状态寄存器

// 内部信号
wire SurvivorBit;                            // 当前状态对应的生存位

    //==========================================================================
    // 状态更新逻辑 (Clock1控制)
    //==========================================================================
    always @(negedge Clock1 or negedge Reset)
    begin
       if (~Reset) begin
          CurrentState <=0;                   // 复位时状态清零
          OutState <=0;                       // 输出状态清零
       end
       else if (Enable)                       // 回溯使能时
         begin 
            if (Init)                         // 初始化时
               CurrentState <= InitState;     // 设置为初始状态
            else 
               CurrentState <= NextState;     // 正常运行时更新为下一状态
          
            if (Hold)                         // Hold信号有效时
               OutState <= NextState;         // 更新输出状态
         end
    end

    //==========================================================================
    // 地址生成逻辑
    // 取当前状态的高位作为RAM访问地址
    //==========================================================================
    assign AddressTB = CurrentState [`WD_STATE-1:`WD_STATE-5];

    //==========================================================================
    // 下一状态计算逻辑 (Clock2控制)
    //==========================================================================
    always @(negedge Clock2 or negedge Reset)
    begin
      if (~Reset) NextState <= 0;            // 复位时下一状态清零
       else 
         if (Enable)                          // 使能时计算下一状态
            // 下一状态 = {当前状态左移1位, 生存位}
            NextState <= {CurrentState [`WD_STATE-2:0],SurvivorBit};
    end

    //==========================================================================
    // 生存位提取逻辑
    // 根据当前状态的低3位从8位生存路径数据中选择对应位
    //==========================================================================
    assign SurvivorBit = 
          (Clock1 && Clock2 && ~Init) ? Survivor [CurrentState [2:0]]:'bz;
   
endmodule