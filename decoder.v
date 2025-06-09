//==============================================================================
// 文件名: decoder.v
// 描述: Viterbi解码器顶层模块 (Viterbi Decoder Top Module)
//
// 模块功能和原理:
// 1. VITERBIDECODER是整个Viterbi解码器的顶层模块，集成所有子模块
// 2. 实现完整的Viterbi解码算法，包括分支度量计算、ACS运算和回溯
// 3. 采用流水线架构，能够连续处理输入的编码数据
//
// 主要子模块:
// - CONTROL: 控制单元，生成时钟和控制信号
// - BMG: 分支度量生成器，计算分支度量
// - ACSUNIT: ACS单元，执行加法-比较-选择运算
// - MMU: 存储器管理单元，管理生存路径存储
// - TBU: 回溯单元，执行回溯算法输出解码结果
// - METRICMEMORY: 路径度量存储器
// - RAM: 生存路径存储器
//
// 运行流程:
// 1. 接收编码符号Code，通过BMG计算分支度量
// 2. ACS单元根据分支度量和路径度量计算新的路径度量和生存路径
// 3. MMU管理生存路径的存储和读取
// 4. TBU在积累足够深度后进行回溯，输出解码结果
// 5. 整个过程由CONTROL单元协调，确保正确的时序
//
// 数据流:
// Code → BMG → Distance → ACS → Survivors → MMU → RAM
//                     ↓
// DecodeOut ← TBU ← LowestState ← ACS
//
// 存储器架构:
// - 路径度量存储器(METRICMEMORY): 双缓冲结构，存储当前和上一时刻的路径度量
// - 生存路径存储器(RAM): 存储所有时刻的生存路径信息，供回溯使用
//==============================================================================

`include "params.v"
`include "rtl/acs.v"
`include "rtl/bmg.v"
`include "rtl/control.v"
`include "rtl/mmu.v"
`include "rtl/tbu.v"
`include "rtl/dff.v"
`include "rtl/ram.v"

//==============================================================================
// 模块名: VITERBIDECODER
// 功能: Viterbi解码器顶层模块，集成所有功能单元
// 输入:
//   - Reset: 全局复位信号
//   - CLOCK: 主时钟信号
//   - Active: 解码器使能信号
//   - Code: 输入的编码符号(2位)
// 输出:
//   - DecodeOut: 解码输出(1位原始数据)
//==============================================================================
module VITERBIDECODER (Reset, CLOCK, Active, Code, DecodeOut);

// 输入端口定义               
input Reset, CLOCK, Active;               // 控制信号
input [`WD_CODE-1:0] Code;                // 输入编码符号(2位)

// 输出端口定义
output DecodeOut;                         // 解码输出(1位)

//==============================================================================
// 内部连接信号定义
//==============================================================================

// 分支度量生成器输出
wire [`WD_DIST*2*`N_ACS-1:0] Distance;   // 8个分支度量

// 控制单元输出信号
wire [`WD_FSM-1:0] ACSSegment;           // FSM段地址(0-63)
wire [`WD_DEPTH-1:0] ACSPage;            // 页面地址
wire CompareStart, Hold, Init;            // 控制信号
wire Clock1, Clock2;                      // 双相时钟
wire TB_EN;                              // 回溯使能

// ACS单元输出信号
wire [`N_ACS-1:0] Survivors;             // 生存路径选择位(4位)
wire [`WD_STATE-1:0] LowestState;        // 最小度量状态

// 存储器管理单元接口信号
wire RAMEnable;                          // RAM使能信号
wire ReadClock, WriteClock, RWSelect;    // RAM控制信号

// RAM接口信号
wire [`WD_RAM_ADDRESS-1:0] AddressRAM;   // RAM地址总线
wire [`WD_RAM_DATA-1:0] DataRAM;         // RAM数据总线

// 回溯单元接口信号
wire [`WD_RAM_DATA-1:0] DataTB;          // 回溯数据
wire [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB; // 回溯地址

// 路径度量存储器接口信号
wire [`WD_METR*2*`N_ACS-1:0] MMPathMetric; // 读取的路径度量
wire [`WD_METR*`N_ACS-1:0] MMMetric;        // 写入的路径度量
wire [`WD_FSM-2:0] MMReadAddress;           // 度量存储器读地址
wire [`WD_FSM-1:0] MMWriteAddress;          // 度量存储器写地址
wire MMBlockSelect;                         // 度量存储器块选择

//==============================================================================
// 子模块实例化
//==============================================================================

   // 控制单元: 生成时钟和控制信号
   CONTROL ctl (Reset, CLOCK, Clock1, Clock2, ACSPage, ACSSegment, 
                Active, CompareStart, Hold, Init, TB_EN);

   // 分支度量生成器: 计算输入符号与期望输出的汉明距离
   BMG bmg (Reset, Clock2, ACSSegment, Code, Distance);
   
   // ACS单元: 执行加法-比较-选择运算，计算生存路径和路径度量
   ACSUNIT acs (Reset, Clock1, Clock2, Active, Init, Hold, CompareStart, 
                ACSSegment, Distance, Survivors,  LowestState,
                MMReadAddress, MMWriteAddress, MMBlockSelect, MMMetric, 
                MMPathMetric);

   // 存储器管理单元: 管理生存路径的存储和访问
   MMU mmu (CLOCK, Clock1, Clock2, Reset, Active, Hold, Init, ACSPage, 
            ACSSegment [`WD_FSM-1:1], Survivors, 
            DataTB, AddressTB,                    // 来自TBU的访问请求
            RWSelect, ReadClock, WriteClock,      // RAM控制信号
            RAMEnable, AddressRAM, DataRAM);      // RAM接口

   // 回溯单元: 从最小度量状态开始回溯，输出解码结果
   TBU tbu (Reset, Clock1, Clock2, TB_EN, Init, Hold, LowestState, 
            DecodeOut, DataTB, AddressTB);

   // 路径度量存储器: 双缓冲结构，存储当前和上一时刻的路径度量
   METRICMEMORY mm (Reset, Clock1, Active, MMReadAddress, MMWriteAddress, 
                    MMBlockSelect, MMMetric, MMPathMetric);

   // 生存路径存储器: 存储所有时刻的生存路径信息
   RAM ram (RAMEnable, AddressRAM, DataRAM, RWSelect, ReadClock, WriteClock);

endmodule