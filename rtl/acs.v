//==============================================================================
// 文件名: acs.v
// 描述: Viterbi解码器中的加比选单元 (Add-Compare-Select Unit)
//
// 模块功能和原理:
// 1. ACS单元是Viterbi解码器的核心计算模块，实现路径度量的更新
// 2. 主要包含以下子模块：
//    - ACSUNIT: 顶层协调模块，管理4个并行ACS处理器
//    - RAMINTERFACE: RAM接口模块，负责度量存储器的读写控制
//    - ACS: 基本ACS处理器，执行加-比-选运算
//    - COMPARATOR: 二进制补码比较器，实现有符号数比较
//    - LOWESTPICK: 最小路径选择器，找出全局最优路径
//    - LOWEST_OF_FOUR: 四路比较器，从4个候选中选出最优
//
// 工作流程:
// 1. 接收来自BMG的8个分支度量和来自存储器的8个路径度量
// 2. 通过4个并行ACS处理器计算4个状态的幸存路径
// 3. 使用LOWESTPICK模块跟踪全局最小度量状态
// 4. 通过RAMINTERFACE管理度量存储器的乒乓缓冲
// 5. 输出幸存路径信息供路径存储器使用
//
// 关键特性:
// - 并行处理: 4个ACS同时处理不同状态
// - 乒乓缓冲: 双RAM块交替读写避免冲突
// - 全局优化: 实时跟踪256个状态中的最优路径
// - 流水线设计: 使用双时钟实现时序控制
//==============================================================================

`include "../params.v"

//==============================================================================
// 模块名: ACSUNIT
// 功能: ACS单元顶层模块，协调4个并行ACS处理器完成路径度量更新
// 
// 工作原理:
// 1. 将8个分支度量和8个路径度量分配给4个ACS处理器
// 2. 每个ACS处理器负责一个状态的两个分支比较
// 3. 通过RAM接口管理度量存储器的读写操作
// 4. 使用LOWESTPICK模块跟踪全局最小度量状态
// 
// 输入输出:
// - 控制信号: Reset, Clock1, Clock2, Active, Init, Hold, CompareStart
// - 数据输入: ACSSegment(当前处理段), Distance(8个分支度量)
// - 存储器接口: MMPathMetric(输入路径度量), MMMetric(输出路径度量)
// - 输出: Survivors(4个幸存路径), LowestState(最优状态)
//==============================================================================
module ACSUNIT (Reset, Clock1, Clock2, Active, Init, Hold, CompareStart, ACSSegment, Distance,
        Survivors, LowestState, MMReadAddress, MMWriteAddress, MMBlockSelect, MMMetric,
        MMPathMetric); 

// 控制信号输入
input Reset, Clock1, Clock2;           // 复位和双时钟信号
input Active, Init, Hold;              // 工作使能、码字开始、码字结束信号  
input CompareStart;                    // 比较开始信号，来自控制单元
input [`WD_FSM-1:0] ACSSegment;       // 当前处理的FSM段(0-63)，指示处理进度

// 数据输入
input [`WD_DIST*2*`N_ACS-1:0] Distance;     // 来自BMG的8个分支度量(16位)
input [`WD_METR*2*`N_ACS-1:0] MMPathMetric; // 来自存储器的8个路径度量(64位)

// 幸存路径输出(连接幸存路径存储器)
output [`N_ACS-1:0] Survivors;              // 4个幸存路径选择位(4位)

// 回溯单元接口
output [`WD_STATE-1:0] LowestState;         // 全局最小度量对应的状态(8位)

// 度量存储器接口
output [`WD_FSM-2:0] MMReadAddress;         // 读地址(5位)，一次读8个状态
output [`WD_FSM-1:0] MMWriteAddress;        // 写地址(6位)，一次写4个状态  
output MMBlockSelect;                       // 块选择信号，控制乒乓缓冲
output [`WD_METR*`N_ACS-1:0] MMMetric;     // 输出的4个路径度量(32位)

// 内部信号定义
wire [`WD_DIST-1:0] Distance7,Distance6,Distance5,Distance4,    // 8个分支度量分解
                    Distance3,Distance2,Distance1,Distance0;
wire [`WD_METR-1:0] Metric0, Metric1, Metric2, Metric3;        // 4个输出路径度量(各8位)
wire [`WD_METR*`N_ACS-1:0] Metric;                             // 4个路径度量的拼接(32位)

wire [`WD_METR*2*`N_ACS-1:0] PathMetric;                       // 内部路径度量信号(64位)
wire [`WD_METR-1:0] PathMetric7,PathMetric6,PathMetric5,PathMetric4,  // 8个输入路径度量分解
                    PathMetric3,PathMetric2,PathMetric1,PathMetric0;

wire [`WD_METR-1:0] LowestMetric;                              // 全局最小度量值
wire ACSData0, ACSData1, ACSData2, ACSData3;                   // 4个ACS的幸存路径输出

   //===========================================================================
   // 信号分解: 将宽总线信号分解为独立信号便于处理
   //===========================================================================
   assign {Distance7,Distance6,Distance5,Distance4,              // 高4个分支度量
           Distance3,Distance2,Distance1,Distance0} = Distance;  // 低4个分支度量
   
   assign {PathMetric7,PathMetric6,PathMetric5,PathMetric4,       // 高4个路径度量  
           PathMetric3,PathMetric2,PathMetric1,PathMetric0} = PathMetric; // 低4个路径度量

   //===========================================================================
   // 4个并行ACS处理器实例化
   // 每个ACS处理一个状态的两个分支，选择幸存路径
   // ACS输入: 使能信号 + 2个分支度量 + 2个路径度量
   // ACS输出: 幸存路径选择位 + 更新后的路径度量
   //===========================================================================
   ACS acs0 (CompareStart, Distance1,Distance0, PathMetric1,PathMetric0,  
             ACSData0, Metric0);        // 处理状态0: 分支(0,1) → 幸存路径0
   ACS acs1 (CompareStart, Distance3,Distance2, PathMetric3,PathMetric2,  
             ACSData1, Metric1);        // 处理状态1: 分支(2,3) → 幸存路径1
   ACS acs2 (CompareStart, Distance5,Distance4, PathMetric5,PathMetric4,  
             ACSData2, Metric2);        // 处理状态2: 分支(4,5) → 幸存路径2
   ACS acs3 (CompareStart, Distance7,Distance6, PathMetric7,PathMetric6,  
             ACSData3, Metric3);        // 处理状态3: 分支(6,7) → 幸存路径3

   //===========================================================================
   // RAM接口模块实例化
   // 负责管理度量存储器的读写操作和乒乓缓冲控制
   //===========================================================================
   RAMINTERFACE ri (Reset, Clock2, Hold, ACSSegment, Metric, PathMetric, 
                    MMReadAddress, MMWriteAddress, MMBlockSelect, MMMetric,  
                    MMPathMetric);

   //===========================================================================
   // 最小路径选择模块实例化  
   // 从256个状态中找出路径度量最小的状态，用于回溯起始点
   //===========================================================================
   LOWESTPICK lp (Reset, Active, Hold, Init, Clock1, Clock2, ACSSegment,  
                  Metric3, Metric2, Metric1, Metric0,  
                  LowestMetric, LowestState);

   //===========================================================================
   // 输出信号拼接
   //===========================================================================
   assign Metric = {Metric3, Metric2, Metric1, Metric0};           // 4个度量拼接为32位
   assign Survivors = {ACSData3,ACSData2,ACSData1,ACSData0};       // 4个幸存路径拼接为4位

endmodule

//==============================================================================
// 模块名: RAMINTERFACE  
// 功能: RAM接口模块，提供ACS单元与度量存储器之间的接口
//
// 工作原理:
// 1. 管理度量存储器的读写地址生成
// 2. 实现乒乓缓冲机制，避免读写冲突
// 3. 在Hold信号有效时切换存储块
// 4. 提供透明的数据通路连接
//
// 乒乓缓冲机制:
// - 使用两个RAM块(BlockA和BlockB)
// - MMBlockSelect=0: A块写入，B块读取  
// - MMBlockSelect=1: B块写入，A块读取
// - 每个码字结束后(Hold信号)切换块选择
//==============================================================================
module RAMINTERFACE (Reset, Clock2, Hold, ACSSegment, Metric, PathMetric, 
                     MMReadAddress, MMWriteAddress, MMBlockSelect,  
                     MMMetric, MMPathMetric); 

// ACS单元接口
input Reset, Clock2, Hold;                      // 控制信号: 复位、时钟2、码字结束
input [`WD_FSM-1:0] ACSSegment;                // 当前FSM段地址(6位: 0-63)
input [`WD_METR*`N_ACS-1:0] Metric;           // 来自ACS的路径度量(32位)
output [`WD_METR*2*`N_ACS-1:0] PathMetric;    // 输出给ACS的路径度量(64位)

// 存储器接口
input [`WD_METR*2*`N_ACS-1:0] MMPathMetric;   // 从存储器读取的路径度量(64位)
output [`WD_METR*`N_ACS-1:0] MMMetric;        // 写入存储器的路径度量(32位)
output [`WD_FSM-2:0] MMReadAddress;           // 读地址(5位)，一次读8个状态
output [`WD_FSM-1:0] MMWriteAddress;          // 写地址(6位)，一次写4个状态
output MMBlockSelect;                         // 块选择信号，控制乒乓操作

// 内部寄存器
reg [`WD_FSM-2:0] MMReadAddress;              // 读地址寄存器
reg MMBlockSelect;                            // 块选择寄存器

  //============================================================================
  // 读地址生成逻辑
  // 读地址是ACSSegment的低5位，范围0-31
  // 每次读取操作获取8个连续状态的路径度量
  //============================================================================
  always @(ACSSegment or Reset)  
    if (~Reset) MMReadAddress <= 0;                          // 复位时地址清零
    else MMReadAddress <= ACSSegment [`WD_FSM-2:0];         // 取ACSSegment低5位

  //============================================================================
  // 乒乓缓冲控制逻辑
  // 在每个码字处理结束后(Hold信号)切换读写块
  // 确保读写操作不会访问同一个存储块，避免数据竞争
  //============================================================================
  always @(posedge Clock2 or negedge Reset) 
  begin 
    if (~Reset) MMBlockSelect <= 0;                          // 复位时选择块A
    else if (Hold) MMBlockSelect <= ~MMBlockSelect;          // 码字结束后切换块选择
  end 

  //============================================================================
  // 数据通路连接
  // 提供ACS单元与存储器之间的透明数据传输
  //============================================================================
  assign PathMetric = MMPathMetric;            // 存储器读取数据直接传给ACS
  assign MMMetric = Metric;                    // ACS输出数据直接传给存储器
  assign MMWriteAddress = ACSSegment;          // 写地址直接使用ACSSegment(6位)
   
endmodule

//==============================================================================
// 模块名: ACS
// 功能: 基本ACS处理器，实现单个状态的加-比-选运算
//
// 工作原理:
// 1. 加法(Add): 将分支度量与对应的路径度量相加
// 2. 比较(Compare): 比较两个候选路径的总度量
// 3. 选择(Select): 选择度量较小的路径作为幸存路径
//
// 输入: 一个状态的两个候选分支度量和对应的路径度量
// 输出: 幸存路径选择位(0=上分支, 1=下分支)和更新后的路径度量
//==============================================================================
module ACS (CompareEnable, Distance1, Distance0, PathMetric1,  
            PathMetric0, Survivor, Metric); 

// 输入信号
input [`WD_DIST-1:0] Distance1,Distance0;     // 两个分支的汉明距离(各2位)
input [`WD_METR-1:0] PathMetric1,PathMetric0; // 两个前继状态的路径度量(各8位)
input CompareEnable;                          // 比较使能信号

// 输出信号  
output Survivor;                              // 幸存路径选择(1位): 0=上分支, 1=下分支
output [`WD_METR-1:0] Metric;                // 幸存路径的更新度量(8位)

// 内部信号
wire [`WD_METR-1:0] ADD0, ADD1;              // 两个分支的累积度量
wire Survivor;                               // 幸存路径选择位
wire [`WD_METR-1:0] Temp_Metric, Metric;     // 临时度量和输出度量

   //===========================================================================
   // 加法运算: 分支度量 + 路径度量 = 候选路径的总度量
   //===========================================================================
   assign ADD0 = Distance0 + PathMetric0;     // 上分支: 分支度量0 + 路径度量0
   assign ADD1 = Distance1 + PathMetric1;     // 下分支: 分支度量1 + 路径度量1

   //===========================================================================
   // 比较运算: 使用专用比较器选择度量较小的分支
   // 输出Survivor: 1表示ADD1(下分支)较小, 0表示ADD0(上分支)较小
   //===========================================================================
   COMPARATOR C1(CompareEnable, ADD1, ADD0, Survivor);

   //===========================================================================
   // 选择运算: 根据比较结果选择幸存路径的度量值
   //===========================================================================
   assign Temp_Metric = (Survivor) ? ADD1 : ADD0;           // 选择较小的度量值
   assign Metric = (CompareEnable) ? Temp_Metric : ADD0;    // 使能时输出选择结果，否则默认上分支

endmodule

//==============================================================================
// 模块名: COMPARATOR
// 功能: 二进制补码比较器，实现有符号数的大小比较
//
// 工作原理:
// 1. 分别提取两个数的符号位(最高位)
// 2. 比较符号位: 如果符号不同，负数更小
// 3. 如果符号相同，比较绝对值部分
// 4. 使用异或逻辑综合符号比较和数值比较的结果
//
// 比较逻辑:
// - 符号不同: 负数(msb=1)较小
// - 符号相同: 比较绝对值大小
// - 输出: 1表示Metric1较小, 0表示Metric0较小
//==============================================================================
module COMPARATOR (CompareEnable, Metric1, Metric0, Survivor); 

// 输入信号
input [`WD_METR-1:0] Metric1,Metric0;        // 两个待比较的度量值(8位有符号数)
input CompareEnable;                         // 比较使能信号

// 输出信号
output Survivor;                             // 比较结果: 1=Metric1较小, 0=Metric0较小

// 内部信号
wire M1msb, M0msb;                           // 两个数的符号位(最高位)
wire [`WD_METR-1:0] M1unsigned, M0unsigned;  // 两个数的绝对值部分
wire M1msb_xor_M0msb, M1unsignedcompM0;      // 符号异或和绝对值比较结果

   //===========================================================================
   // 符号位提取
   //===========================================================================
   assign M1msb = Metric1 [`WD_METR-1];              // Metric1的符号位
   assign M0msb = Metric0 [`WD_METR-1];              // Metric0的符号位
   
   //===========================================================================
   // 绝对值部分提取(忽略符号位)
   //===========================================================================
   assign M1unsigned = {1'b0, Metric1 [`WD_METR-2:0]}; // Metric1绝对值(高位补0)
   assign M0unsigned = {1'b0, Metric0 [`WD_METR-2:0]}; // Metric0绝对值(高位补0)

   //===========================================================================
   // 比较逻辑
   //===========================================================================
   assign M1msb_xor_M0msb = M1msb ^ M0msb;           // 符号位异或: 0=同号, 1=异号
   assign M1unsignedcompM0 = (M1unsigned > M0unsigned) ? 0 : 1; // 绝对值比较: 1=M1≤M0

   //===========================================================================
   // 综合比较结果
   // 逻辑: 符号异或 XOR 绝对值比较
   // - 同号时: 直接使用绝对值比较结果
   // - 异号时: 符号位为1的(负数)更小
   //===========================================================================
   assign Survivor = (CompareEnable) ?  
                     M1msb_xor_M0msb ^ M1unsignedcompM0 : 1'b0;

endmodule

//==============================================================================
// 模块名: LOWESTPICK
// 功能: 全局最小路径度量跟踪器，从256个状态中找出度量最小的状态
//
// 工作原理:
// 1. 使用两级寄存器结构: Reg_*用于中间存储, Lowest*用于最终输出
// 2. 在Clock2下降沿更新中间寄存器，跟踪当前最小值
// 3. 在Clock1下降沿且Hold有效时，将结果输出到最终寄存器
// 4. 使用Init信号在每个码字开始时重新初始化
//
// 应用:
// - 为路径回溯提供起始状态(度量最小的状态)
// - 调试ACS单元工作状态(无错误时最小度量应为0)
// - 监控解码器收敛性能
//==============================================================================
module LOWESTPICK (Reset, Active, Hold, Init, Clock1, Clock2, ACSSegment,  
                   Metric3, Metric2, Metric1, Metric0,  
                   LowestMetric, LowestState); 

// 控制信号
input Reset, Active, Clock1, Clock2;         // 复位、使能、双时钟信号
input Hold, Init;                            // 码字结束、码字开始信号
input [`WD_FSM-1:0] ACSSegment;             // 当前FSM段地址

// 输入度量
input [`WD_METR-1:0] Metric3, Metric2, Metric1, Metric0; // 当前4个状态的度量

// 输出结果
output [`WD_METR-1:0] LowestMetric;         // 全局最小度量值
output [`WD_STATE-1:0] LowestState;         // 全局最小度量对应的状态

// 内部寄存器
reg [`WD_METR-1:0] LowestMetric, Reg_Metric;   // 输出寄存器和中间寄存器
reg [`WD_STATE-1:0] LowestState, Reg_State;    // 输出寄存器和中间寄存器

// 比较结果信号
wire [`WD_METR-1:0] MetricCompareResult;       // 度量比较结果
wire [`WD_STATE-1:0] StateCompareResult;       // 状态比较结果
wire [`WD_METR-1:0] Lowest_Metric4;            // 当前4个中的最小度量
wire [`WD_STATE-1:0] Lowest_State4;            // 当前4个中的最小状态
wire CompareBit;                               // 比较器输出

   //===========================================================================
   // 当前4个状态的最小值查找
   // 使用LOWEST_OF_FOUR模块从当前4个度量中选出最小值
   //===========================================================================
   LOWEST_OF_FOUR lof (Active, ACSSegment, Metric3, Metric2,  
                       Metric1, Metric0,  
                       Lowest_State4, Lowest_Metric4);

   //===========================================================================
   // 全局比较: 当前最小值 vs 历史最小值
   //===========================================================================
   COMPARATOR comp (Active, Reg_Metric, Lowest_Metric4, CompareBit);

   //===========================================================================
   // 比较结果选择
   // CompareBit=1: Reg_Metric较小，保持历史值
   // CompareBit=0: Lowest_Metric4较小，更新为当前值
   //===========================================================================
   assign MetricCompareResult = (CompareBit) ? Reg_Metric : Lowest_Metric4;
   assign StateCompareResult = (CompareBit) ? Reg_State : Lowest_State4;

   //===========================================================================
   // 中间寄存器更新逻辑 (Clock2下降沿)
   // 在每个处理周期更新当前已知的最小值
   //===========================================================================
   always @(negedge Clock2 or negedge Reset) 
   begin 
     if (~Reset)                              // 复位时清零
       begin 
         Reg_Metric <= 0;
         Reg_State <= 0; 
       end 
     else if (Active)                         // 工作状态下
       begin 
         if (Init)                            // 码字开始: 初始化为当前4个的最小值
            begin  
              Reg_Metric <= Lowest_Metric4;   
              Reg_State <= Lowest_State4;  
            end 
         else                                 // 正常处理: 更新全局最小值
            begin  
              Reg_Metric <= MetricCompareResult;
              Reg_State <= StateCompareResult;  
            end 
       end 
   end 

   //===========================================================================
   // 输出寄存器更新逻辑 (Clock1下降沿)
   // 只在码字结束时(Hold信号)更新最终输出
   //===========================================================================
   always @(negedge Clock1 or negedge Reset) 
   begin  
     if (~Reset)                              // 复位时清零
       begin 
         LowestMetric <= 0;
         LowestState <= 0; 
       end 
     else if (Active) 
        begin 
          if (Hold)                           // 码字结束: 输出最终结果
            begin 
              LowestMetric <= Reg_Metric;     // 输出全局最小度量
              LowestState <= Reg_State;       // 输出全局最小状态
            end 
        end 
   end 
    
endmodule

//==============================================================================
// 模块名: LOWEST_OF_FOUR
// 功能: 四路度量比较器，从4个候选度量中选出最小值及对应状态
//
// 工作原理:
// 1. 第一级: 并行比较(Metric1,Metric0)和(Metric3,Metric2)
// 2. 第二级: 比较第一级的两个获胜者
// 3. 状态编码: 使用ACSSegment和比较结果构造完整的8位状态地址
//
// 状态编码规则:
// - 状态地址 = {ACSSegment[5:0], Surv3, Bit_One}
// - Surv3: 第二级比较结果(0=选择MetricX, 1=选择MetricY)  
// - Bit_One: 对应的第一级比较结果
// - 最终映射: 00→Metric0, 01→Metric1, 10→Metric2, 11→Metric3
//==============================================================================
module LOWEST_OF_FOUR (Active, ACSSegment, Metric3, Metric2, Metric1,  
                       Metric0, Lowest_State4, Lowest_Metric4); 

// 输入信号
input Active;                                // 使能信号
input [`WD_FSM-1:0] ACSSegment;             // FSM段地址(6位)
input [`WD_METR-1:0] Metric3, Metric2, Metric1, Metric0; // 4个候选度量

// 输出信号
output [`WD_STATE-1:0] Lowest_State4;       // 最小度量对应的状态地址(8位)
output [`WD_METR-1:0] Lowest_Metric4;       // 最小度量值

// 内部信号
wire Surv1, Surv2, Surv3, Bit_One;          // 各级比较结果
wire [`WD_METR-1:0] MetricX, MetricY;       // 第一级比较的获胜者

  //============================================================================
  // 第一级比较: 两两比较得到初步获胜者
  //============================================================================
  COMPARATOR comp1 (Active, Metric1, Metric0, Surv1);  // 比较Metric1和Metric0
  COMPARATOR comp2 (Active, Metric3, Metric2, Surv2);  // 比较Metric3和Metric2

  //============================================================================
  // 第一级获胜者选择
  //============================================================================
  assign MetricX = (Surv1) ? Metric1 : Metric0;        // Surv1=1选Metric1, =0选Metric0
  assign MetricY = (Surv2) ? Metric3 : Metric2;        // Surv2=1选Metric3, =0选Metric2

  //============================================================================
  // 第二级比较: 决出最终获胜者
  //============================================================================
  COMPARATOR comp3 (Active, MetricY, MetricX, Surv3);

  //============================================================================
  // 状态地址构造
  // 根据比较结果构造完整的8位状态地址
  // 地址格式: {ACSSegment[5:0], Surv3, Bit_One}
  //============================================================================
  assign Bit_One = (Surv3) ? Surv2 : Surv1;            // 选择对应的第一级结果
  assign Lowest_State4 = {ACSSegment, Surv3, Bit_One}; 

  // 状态编码对应关系:
  // Surv3=0, Bit_One=0: 00 → Metric0
  // Surv3=0, Bit_One=1: 01 → Metric1  
  // Surv3=1, Bit_One=0: 10 → Metric2
  // Surv3=1, Bit_One=1: 11 → Metric3

  //============================================================================
  // 最小度量值选择
  //============================================================================
  assign Lowest_Metric4 = (Surv3) ? MetricY : MetricX;

endmodule