//==============================================================================
// 文件名: mmu.v
// 描述: Viterbi解码器的存储器管理单元 (Memory Management Unit)
//
// 模块功能和原理:
// 1. MMU单元负责管理生存路径存储器的访问和控制
// 2. 协调ACS单元的写操作和TBU单元的读操作
// 3. 处理数据位宽不匹配问题(ACS输出4位，RAM数据总线8位)
//
// 主要功能:
// - 地址管理: 根据操作类型生成RAM地址
// - 时钟控制: 生成读写时钟信号
// - 数据缓冲: 将4位生存路径数据缓冲成8位写入RAM
// - 访问仲裁: 协调写操作(来自ACS)和读操作(来自TBU)
//
// 运行流程:
// 1. 写操作: ACS单元产生4位Survivors → 缓冲成8位 → 写入RAM
// 2. 读操作: TBU请求特定地址 → MMU生成地址 → 从RAM读取数据
// 3. 地址生成: 写地址基于当前页面，读地址基于回溯页面
// 4. 时序控制: 使用双时钟确保读写操作的正确时序
//
// 存储器架构:
// - RAM组织: 按页面组织，每页包含64个地址
// - 数据宽度: 8位(包含两个4位生存路径数据)
// - 地址空间: 由页面地址和段地址组合而成
//==============================================================================

`include "params.v"

//==============================================================================
// 模块名: MMU
// 功能: 存储器管理单元，协调生存路径存储器的读写访问
// 输入:
//   - CLOCK, Clock1, Clock2: 时钟信号
//   - Reset, Active, Hold, Init: 控制信号
//   - ACSPage: 当前ACS处理页面
//   - ACSSegment_minusLSB: ACS段地址(去掉最低位)
//   - Survivors: 来自ACS的4位生存路径数据
//   - AddressTB: 来自TBU的读地址请求
// 输出:
//   - DataTB: 向TBU提供的读数据
//   - RWSelect, ReadClock, WriteClock, RAMEnable: RAM控制信号
//   - AddressRAM: RAM地址总线
// 双向:
//   - DataRAM: RAM数据总线
//==============================================================================
module MMU (CLOCK, Clock1, Clock2, Reset, Active, Hold, Init, ACSPage, 
            ACSSegment_minusLSB, Survivors, 
            DataTB, AddressTB,
            RWSelect, ReadClock, WriteClock, 
            RAMEnable, AddressRAM, DataRAM);

// 来自控制单元的连接
input CLOCK, Clock1, Clock2, Reset, Active, Hold, Init;
input [`WD_DEPTH-1:0] ACSPage;              // 当前ACS页面
input [`WD_FSM-2:0] ACSSegment_minusLSB;    // ACS段地址(去掉LSB)

// 来自ACS单元的连接
input [`N_ACS-1:0] Survivors;               // 4位生存路径数据

// 与TBU单元的连接
output [`WD_RAM_DATA-1:0] DataTB;           // 向TBU提供的数据
input [`WD_RAM_ADDRESS-`WD_FSM-1:0] AddressTB; // 来自TBU的地址请求

// 与RAM的连接
output RWSelect, ReadClock, WriteClock, RAMEnable; // RAM控制信号
output [`WD_RAM_ADDRESS-1:0] AddressRAM;           // RAM地址总线
inout [`WD_RAM_DATA-1:0] DataRAM;                  // RAM数据总线

// 内部信号定义
wire [`WD_RAM_DATA-1:0] WrittenSurvivors;   // 缓冲后的8位生存路径数据

reg dummy, SurvRDY;                          // 写时钟控制和缓冲就绪标志
reg [`WD_RAM_ADDRESS-1:0] AddressRAM;       // 地址寄存器
reg [`WD_DEPTH-1:0] TBPage;                 // 回溯页面计数器

wire [`WD_DEPTH-1:0] TBPage_;               // 回溯页面递减信号
wire [`WD_DEPTH-1:0] ACSPage;               // ACS页面信号
wire [`WD_TB_ADDRESS-1:0] AddressTB;        // 回溯地址信号

//==============================================================================
// 读写时钟生成逻辑
//==============================================================================

   // 写时钟控制: dummy变量用于控制写时钟每2个Clock2周期发生一次
   always @(posedge Clock2 or negedge Reset) 
      if (~Reset) dummy <= 0;
      else if (Active) dummy <= ~dummy;

   // 写时钟: 只在Active且dummy为0时生成
   assign WriteClock = (Active && ~dummy) ? Clock1:0;
   
   // 读时钟: 在Active且非Hold状态时生成(Clock1的反相)
   assign ReadClock = (Active && ~Hold) ? ~Clock1:0;

//==============================================================================
// 生存路径缓冲逻辑
// 由于RAM数据总线宽度为8位，而ACS输出只有4位，需要缓冲
//==============================================================================

   // 缓冲就绪标志: 每个Clock1周期翻转，指示缓冲状态
   always @(posedge Clock1 or negedge Reset) 
     if (~Reset) SurvRDY <= 1; 
     else if (Active) SurvRDY <= ~SurvRDY;

   // 生存路径缓冲器实例化
   ACSSURVIVORBUFFER buff (Reset, Clock1, Active, SurvRDY, Survivors, 
                           WrittenSurvivors);

//==============================================================================
// 回溯操作的页面管理
//==============================================================================

   // 回溯页面控制逻辑
   // 每个Clock2下降沿: TBPage递减1，或在Init时设置为ACSPage-1
   always @(negedge Clock2 or negedge Reset)
   begin
     if (~Reset) begin
        TBPage <= 0;                      // 复位时清零
     end
     else if (Init) TBPage <= ACSPage-1;  // 初始化时设置为当前页面-1
          else TBPage <= TBPage_;         // 正常运行时递减
   end

   assign TBPage_ = TBPage - 1;           // 页面递减信号

//==============================================================================
// RAM接口控制
//==============================================================================

    // RAM控制信号
    assign RAMEnable = 0;                           // RAM始终使能(低电平有效)
    assign RWSelect = (Clock2) ? 1:0;               // Clock2高电平时读，低电平时写
    assign DataRAM = (~Clock2) ? WrittenSurvivors:'bz; // 写时驱动数据总线
    assign DataTB = (Clock2) ? DataRAM:'bz;         // 读时向TBU提供数据

    // RAM地址生成逻辑
    // 每当Clock2变化时，设置地址和使能信号，为Clock1边沿的读写操作做准备
    always @(posedge CLOCK or negedge Reset)
    begin
      if (~Reset) AddressRAM <= 0;
      else
      if (Active) begin
        if (Clock2 == 0)                    // Clock2为0时进行写操作
           begin
              // 写地址: 当前页面 + ACS段地址
              AddressRAM <= {ACSPage, ACSSegment_minusLSB};
           end
        else                                // Clock2为1时进行读操作
           begin
              // 读地址: 回溯页面 + TBU提供的地址
              AddressRAM <= {TBPage [`WD_DEPTH-1:0],AddressTB};
           end
       end
    end

endmodule

//==============================================================================
// 模块名: ACSSURVIVORBUFFER
// 功能: ACS生存路径缓冲器，将4位数据缓冲成8位数据
// 原理: 为了适应8位宽的RAM数据总线，需要将连续的两个4位生存路径
//       数据组合成一个8位数据写入RAM
//==============================================================================
module ACSSURVIVORBUFFER (Reset, Clock1, Active, SurvRDY, Survivors, 
                          WrittenSurvivors);

// 输入信号
input Reset, Clock1, Active, SurvRDY;      // 控制信号
input [`N_ACS-1:0] Survivors;              // 当前4位生存路径数据

// 输出信号
output [`WD_RAM_DATA-1:0] WrittenSurvivors; // 8位缓冲后的数据

// 内部信号
wire  [`WD_RAM_DATA-1:0] WrittenSurvivors;
reg [`N_ACS-1:0] WrittenSurvivors_;        // 上一个4位数据的寄存器

  // 数据缓冲逻辑: 在Clock1上升沿锁存当前生存路径数据
  always @(posedge Clock1 or negedge Reset)
    begin
     if (~Reset) WrittenSurvivors_ = 0;     // 复位时清零
        else if (Active)                    // 活动时锁存数据
         WrittenSurvivors_ = Survivors;
     end

  // 输出组合逻辑: 当SurvRDY有效时，组合当前和上一个4位数据成8位输出
  assign WrittenSurvivors = (SurvRDY) ? {Survivors, WrittenSurvivors_}:8'bz;

endmodule