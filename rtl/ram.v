//==============================================================================
// 文件名: ram.v
// 描述: Viterbi解码器的存储器模块 (Memory Modules)
//
// 模块功能和原理:
// 1. 包含两种主要存储器类型：
//    - RAM: 生存路径存储器，存储回溯所需的生存路径信息
//    - METRICMEMORY: 路径度量存储器，采用双缓冲结构存储路径度量
//
// 主要特性:
// - 参数化设计: RAM模块支持可配置的容量和数据位宽
// - 双缓冲结构: 度量存储器使用乒乓缓冲，避免读写冲突
// - 时钟边沿控制: 使用负边沿触发，确保正确的时序关系
//
// 存储器组织:
// - RAM: 2048×8位，用于存储生存路径数据
// - METRICMEMORY: 64×32位双缓冲，存储路径度量值
//
// 工作原理:
// 1. 生存路径存储: 按页面组织，支持并发读写操作
// 2. 度量存储: 乒乓缓冲切换，当前时刻写入一个缓冲区，同时从另一个缓冲区读取
// 3. 地址映射: 将逻辑地址映射到物理存储单元
//==============================================================================

`include "../params.v"

//==============================================================================
// 模块名: RAM
// 功能: 生存路径存储器顶层模块，实例化具体的RAM模块
// 输入:
//   - RAMEnable: RAM使能信号(低电平有效)
//   - AddressRAM: RAM地址总线
//   - RWSelect: 读写选择信号(0=写, 1=读)
//   - ReadClock, WriteClock: 读写时钟信号
// 双向:
//   - DataRAM: RAM数据总线
//==============================================================================
module RAM (RAMEnable, AddressRAM, DataRAM, 
            RWSelect, ReadClock, WriteClock);

// 端口定义
input RAMEnable, RWSelect, ReadClock, WriteClock; // 控制信号
input [`WD_RAM_ADDRESS-1:0] AddressRAM;          // 地址总线
inout [`WD_RAM_DATA-1:0] DataRAM;                // 数据总线

     // 实例化参数化RAM模块
     // 参数: 容量=2048, 数据位宽=8, 地址位宽=11
     RAMMODULE #(2048,8,11) ram (RAMEnable, DataRAM, AddressRAM, RWSelect, 
                                  ReadClock, WriteClock);
     
endmodule

//==============================================================================
// 模块名: RAMMODULE
// 功能: 参数化RAM模块，实现通用的随机访问存储器
// 参数:
//   - SIZE: 存储器容量(存储单元数量)
//   - DATABITS: 数据位宽
//   - ADDRESSBITS: 地址位宽
// 特性: 
//   - 低电平使能
//   - 负边沿触发的读写操作
//   - 三态数据总线控制
//==============================================================================
module RAMMODULE (_Enable, Data, Address, RWSelect, RClock, WClock);

// 参数定义
parameter SIZE = 2048;        // 存储器容量，默认2K
parameter DATABITS = 8;       // 数据位宽，默认8位
parameter ADDRESSBITS = 7;    // 地址位宽，默认7位

// 端口定义
inout  [DATABITS-1:0] Data;           // 双向数据总线
input  [ADDRESSBITS-1:0] Address;     // 地址输入

input RWSelect;                       // 读写选择: 0=写入, 1=读取
input RClock,WClock,_Enable;          // 读时钟、写时钟、使能信号

// 内部存储器和缓冲器
reg [DATABITS-1:0] Data_Regs [SIZE-1:0];  // 主存储器阵列
reg [DATABITS-1:0] DataBuff;               // 读数据缓冲器

   // 写操作逻辑
   // 在写时钟下降沿且使能有效时，将数据写入指定地址
   always @(negedge WClock)
   begin
      if (~_Enable) Data_Regs [Address] <= Data;
      // $display("RAM: Write Address=%d, Data=%h RWSelect %d", Address, Data, RWSelect);
   end

   // 读操作逻辑  
   // 在读时钟下降沿且使能有效时，从指定地址读取数据到缓冲器
   always @(negedge RClock)
   begin
      if (~_Enable) DataBuff <= Data_Regs [Address];
      // $display("RAM:READ Address=%d, Data=%h RWSelect %d", Address, DataBuff, RWSelect);
   end

   // 三态数据总线控制
   // 读操作时输出缓冲器数据，否则高阻态
   assign Data = (RWSelect) ? DataBuff:'bz;

endmodule

//==============================================================================
// 模块名: METRICMEMORY
// 功能: 路径度量存储器，采用双缓冲乒乓结构
// 原理: 使用两个独立的存储器块(A和B)，通过MMBlockSelect信号切换
//       当前时刻写入一个块，同时从另一个块读取上一时刻的数据
//       这样避免了读写冲突，提高了系统性能
//==============================================================================
module METRICMEMORY (Reset, Clock1, Active, MMReadAddress, 
                     MMWriteAddress, MMBlockSelect, MMMetric, MMPathMetric);

// 输入信号
input Reset, Clock1, Active, MMBlockSelect;          // 控制信号
input [`WD_METR*`N_ACS-1:0] MMMetric;               // 写入的度量数据
input [`WD_FSM-1:0] MMWriteAddress;                 // 写地址
input [`WD_FSM-2:0] MMReadAddress;                  // 读地址

// 输出信号
output [`WD_METR*2*`N_ACS-1:0] MMPathMetric;        // 读出的路径度量

// 内部存储器定义
// 双缓冲结构: A组和B组各64个存储单元
reg [`WD_METR*`N_ACS-1:0] M_REG_A [`N_ITER-1:0];   // 度量存储器A组
reg [`WD_METR*`N_ACS-1:0] M_REG_B [`N_ITER-1:0];   // 度量存储器B组

reg [`WD_METR*2*`N_ACS-1:0] MMPathMetric;           // 输出寄存器

  //============================================================================
  // 写操作逻辑
  // 在Clock1下降沿更新存储器内容
  //============================================================================
  always @(negedge Clock1 or negedge Reset)
  begin
    if (~Reset)
       begin
         // 复位时将所有存储单元清零
         // A组存储器初始化
         M_REG_A [63] <= 0;M_REG_A [62] <= 0;M_REG_A [61] <= 0;
         M_REG_A [60] <= 0;M_REG_A [59] <= 0;M_REG_A [58] <= 0;
         M_REG_A [57] <= 0;M_REG_A [56] <= 0;
         M_REG_A [55] <= 0;M_REG_A [54] <= 0;M_REG_A [53] <= 0;
         M_REG_A [52] <= 0;M_REG_A [51] <= 0;
         M_REG_A [50] <= 0;M_REG_A [49] <= 0;M_REG_A [48] <= 0;
         M_REG_A [47] <= 0;M_REG_A [46] <= 0;
         M_REG_A [45] <= 0;M_REG_A [44] <= 0;M_REG_A [43] <= 0;
         M_REG_A [42] <= 0;M_REG_A [41] <= 0;
         M_REG_A [40] <= 0;M_REG_A [39] <= 0;M_REG_A [38] <= 0;
         M_REG_A [37] <= 0;M_REG_A [36] <= 0;
         M_REG_A [35] <= 0;M_REG_A [34] <= 0;M_REG_A [33] <= 0;
         M_REG_A [32] <= 0;M_REG_A [31] <= 0;
         M_REG_A [30] <= 0;M_REG_A [29] <= 0;M_REG_A [28] <= 0;
         M_REG_A [27] <= 0;M_REG_A [26] <= 0;
         M_REG_A [25] <= 0;M_REG_A [24] <= 0;M_REG_A [23] <= 0;
         M_REG_A [22] <= 0;M_REG_A [21] <= 0;
         M_REG_A [20] <= 0;M_REG_A [19] <= 0;M_REG_A [18] <= 0;
         M_REG_A [17] <= 0;M_REG_A [16] <= 0;
         M_REG_A [15] <= 0;M_REG_A [14] <= 0;M_REG_A [13] <= 0;
         M_REG_A [12] <= 0;M_REG_A [11] <= 0;
         M_REG_A [10] <= 0;M_REG_A [9] <= 0;M_REG_A [8] <= 0;
         M_REG_A [7] <= 0;M_REG_A [6] <= 0;
         M_REG_A [5] <= 0;M_REG_A [4] <= 0;M_REG_A [3] <= 0;
         M_REG_A [2] <= 0;M_REG_A [1] <= 0;
         M_REG_A [0] <= 0;

         // B组存储器初始化
         M_REG_B [63] <= 0;M_REG_B [62] <= 0;M_REG_B [61] <= 0;
         M_REG_B [60] <= 0;M_REG_B [59] <= 0;M_REG_B [58] <= 0;
         M_REG_B [57] <= 0;M_REG_B [56] <= 0;
         M_REG_B [55] <= 0;M_REG_B [54] <= 0;M_REG_B [53] <= 0;
         M_REG_B [52] <= 0;M_REG_B [51] <= 0;
         M_REG_B [50] <= 0;M_REG_B [49] <= 0;M_REG_B [48] <= 0;
         M_REG_B [47] <= 0;M_REG_B [46] <= 0;
         M_REG_B [45] <= 0;M_REG_B [44] <= 0;M_REG_B [43] <= 0;
         M_REG_B [42] <= 0;M_REG_B [41] <= 0;
         M_REG_B [40] <= 0;M_REG_B [39] <= 0;M_REG_B [38] <= 0;
         M_REG_B [37] <= 0;M_REG_B [36] <= 0;
         M_REG_B [35] <= 0;M_REG_B [34] <= 0;M_REG_B [33] <= 0;
         M_REG_B [32] <= 0;M_REG_B [31] <= 0;
         M_REG_B [30] <= 0;M_REG_B [29] <= 0;M_REG_B [28] <= 0;
         M_REG_B [27] <= 0;M_REG_B [26] <= 0;
         M_REG_B [25] <= 0;M_REG_B [24] <= 0;M_REG_B [23] <= 0;
         M_REG_B [22] <= 0;M_REG_B [21] <= 0;
         M_REG_B [20] <= 0;M_REG_B [19] <= 0;M_REG_B [18] <= 0;
         M_REG_B [17] <= 0;M_REG_B [16] <= 0;
         M_REG_B [15] <= 0;M_REG_B [14] <= 0;M_REG_B [13] <= 0;
         M_REG_B [12] <= 0;M_REG_B [11] <= 0;
         M_REG_B [10] <= 0;M_REG_B [9] <= 0;M_REG_B [8] <= 0;
         M_REG_B [7] <= 0;M_REG_B [6] <= 0;
         M_REG_B [5] <= 0;M_REG_B [4] <= 0;M_REG_B [3] <= 0;
         M_REG_B [2] <= 0;M_REG_B [1] <= 0;
         M_REG_B [0] <= 0;
       end
    else
       begin
         // 正常工作时根据块选择信号写入相应存储器
         if (Active) 
            case (MMBlockSelect)
                0 : M_REG_A [MMWriteAddress] <= MMMetric;  // 写入A组
                1 : M_REG_B [MMWriteAddress] <= MMMetric;  // 写入B组
            endcase
       end
   end
  
  //============================================================================
  // 读操作逻辑
  // 组合逻辑，根据读地址和块选择信号输出相应数据
  // 注意: 读取时从非当前写入的块中读取(乒乓操作)
  //============================================================================
   always @(MMReadAddress or Reset)
   begin
    if (~Reset) MMPathMetric <=0;
     else begin
       case (MMBlockSelect)
         // 当前写入A组时，从B组读取
         0 : case (MMReadAddress)
               0 : MMPathMetric <= {M_REG_B [1],M_REG_B[0]};
               1 : MMPathMetric <= {M_REG_B [3],M_REG_B[2]};
               2 : MMPathMetric <= {M_REG_B [5],M_REG_B[4]};        
               3 : MMPathMetric <= {M_REG_B [7],M_REG_B[6]};
               4 : MMPathMetric <= {M_REG_B [9],M_REG_B[8]};
               5 : MMPathMetric <= {M_REG_B [11],M_REG_B[10]};   
               6 : MMPathMetric <= {M_REG_B [13],M_REG_B[12]};        
               7 : MMPathMetric <= {M_REG_B [15],M_REG_B[14]};
               
               8 : MMPathMetric <= {M_REG_B [17],M_REG_B[16]};
               9 : MMPathMetric <= {M_REG_B [19],M_REG_B[18]};
              10 : MMPathMetric <= {M_REG_B [21],M_REG_B[20]};
              11 : MMPathMetric <= {M_REG_B [23],M_REG_B[22]};
              12 : MMPathMetric <= {M_REG_B [25],M_REG_B[24]};
              13 : MMPathMetric <= {M_REG_B [27],M_REG_B[26]};
              14 : MMPathMetric <= {M_REG_B [29],M_REG_B[28]};
              15 : MMPathMetric <= {M_REG_B [31],M_REG_B[30]};
       
              16 : MMPathMetric <= {M_REG_B [33],M_REG_B[32]};
              17 : MMPathMetric <= {M_REG_B [35],M_REG_B[34]};
              18 : MMPathMetric <= {M_REG_B [37],M_REG_B[36]};        
              19 : MMPathMetric <= {M_REG_B [39],M_REG_B[38]};
              20 : MMPathMetric <= {M_REG_B [41],M_REG_B[40]};
              21 : MMPathMetric <= {M_REG_B [43],M_REG_B[42]};   
              22 : MMPathMetric <= {M_REG_B [45],M_REG_B[44]};        
              23 : MMPathMetric <= {M_REG_B [47],M_REG_B[46]};
       
              24 : MMPathMetric <= {M_REG_B [49],M_REG_B[48]};
              25 : MMPathMetric <= {M_REG_B [51],M_REG_B[50]};
              26 : MMPathMetric <= {M_REG_B [53],M_REG_B[52]};        
              27 : MMPathMetric <= {M_REG_B [55],M_REG_B[54]};
              28 : MMPathMetric <= {M_REG_B [57],M_REG_B[56]};
              29 : MMPathMetric <= {M_REG_B [59],M_REG_B[58]};   
              30 : MMPathMetric <= {M_REG_B [61],M_REG_B[60]};        
              31 : MMPathMetric <= {M_REG_B [63],M_REG_B[62]};
            endcase

         // 当前写入B组时，从A组读取
         1 : case (MMReadAddress)
               0 : MMPathMetric <= {M_REG_A [1],M_REG_A[0]};
               1 : MMPathMetric <= {M_REG_A [3],M_REG_A[2]};
               2 : MMPathMetric <= {M_REG_A [5],M_REG_A[4]};        
               3 : MMPathMetric <= {M_REG_A [7],M_REG_A[6]};
               4 : MMPathMetric <= {M_REG_A [9],M_REG_A[8]};
               5 : MMPathMetric <= {M_REG_A [11],M_REG_A[10]};   
               6 : MMPathMetric <= {M_REG_A [13],M_REG_A[12]};        
               7 : MMPathMetric <= {M_REG_A [15],M_REG_A[14]};
               
               8 : MMPathMetric <= {M_REG_A [17],M_REG_A[16]};
               9 : MMPathMetric <= {M_REG_A [19],M_REG_A[18]};
              10 : MMPathMetric <= {M_REG_A [21],M_REG_A[20]};
              11 : MMPathMetric <= {M_REG_A [23],M_REG_A[22]};
              12 : MMPathMetric <= {M_REG_A [25],M_REG_A[24]};
              13 : MMPathMetric <= {M_REG_A [27],M_REG_A[26]};
              14 : MMPathMetric <= {M_REG_A [29],M_REG_A[28]};
              15 : MMPathMetric <= {M_REG_A [31],M_REG_A[30]};
       
              16 : MMPathMetric <= {M_REG_A [33],M_REG_A[32]};
              17 : MMPathMetric <= {M_REG_A [35],M_REG_A[34]};
              18 : MMPathMetric <= {M_REG_A [37],M_REG_A[36]};        
              19 : MMPathMetric <= {M_REG_A [39],M_REG_A[38]};
              20 : MMPathMetric <= {M_REG_A [41],M_REG_A[40]};
              21 : MMPathMetric <= {M_REG_A [43],M_REG_A[42]};   
              22 : MMPathMetric <= {M_REG_A [45],M_REG_A[44]};        
              23 : MMPathMetric <= {M_REG_A [47],M_REG_A[46]};
       
              24 : MMPathMetric <= {M_REG_A [49],M_REG_A[48]};
              25 : MMPathMetric <= {M_REG_A [51],M_REG_A[50]};
              26 : MMPathMetric <= {M_REG_A [53],M_REG_A[52]};        
              27 : MMPathMetric <= {M_REG_A [55],M_REG_A[54]};
              28 : MMPathMetric <= {M_REG_A [57],M_REG_A[56]};
              29 : MMPathMetric <= {M_REG_A [59],M_REG_A[58]};   
              30 : MMPathMetric <= {M_REG_A [61],M_REG_A[60]};        
              31 : MMPathMetric <= {M_REG_A [63],M_REG_A[62]};
            endcase
     endcase
     end
   end
        
endmodule