//==============================================================================
// 文件名: tb_bmg.v
// 描述: BMG (分支度量生成器) 的测试平台
// 功能: 验证BMG模块的基本功能，包括：
//       1. 编码符号锁存功能
//       2. 分支度量计算功能
//       3. 输出波形生成
//==============================================================================

`include "params.v"
`include "rtl/bmg.v"
`timescale 1ns/1ps

module tb_bmg();

//==============================================================================
// 信号定义
//==============================================================================
// 时钟和复位信号
reg Reset;
reg Clock2;

// BMG输入信号
reg [`WD_FSM-1:0] ACSSegment;    // FSM段地址 (6位)
reg [`WD_CODE-1:0] Code;         // 编码符号 (2位)

// BMG输出信号
wire [`WD_DIST*2*`N_ACS-1:0] Distance; // 8个分支度量 (16位)

// 测试计数器
integer i;

//==============================================================================
// 被测模块实例化
//==============================================================================
BMG DUT (
    .Reset(Reset),
    .Clock2(Clock2),
    .ACSSegment(ACSSegment),
    .Code(Code),
    .Distance(Distance)
);

//==============================================================================
// 时钟生成
//==============================================================================
initial begin
    Clock2 = 1'b0;
    forever #(`HALF) Clock2 = ~Clock2;  // 时钟周期为200ns
end

//==============================================================================
// 测试序列
//==============================================================================
initial begin
    // 初始化信号
    Reset = 1'b0;
    ACSSegment = 6'h00;
    Code = 2'b00;
    
    // 等待几个时钟周期
    #(`FULL * 2);
    
    // 释放复位
    Reset = 1'b1;
    #(`FULL);
    
    $display("=== BMG模块测试开始 ===");
    $display("时间\t\tReset\tACSSegment\tCode\tDistance");
    $display("------------------------------------------------------------");
    
    // 测试1: 验证不同ACSSegment下的基本功能
    $display("\n--- 测试1: 基本分支度量计算 ---");
    
    // 设置编码符号为00，在ACSSegment=0x3F时锁存
    Code = 2'b00;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 改变ACSSegment，观察距离计算
    for (i = 0; i < 8; i = i + 1) begin
        ACSSegment = i;
        #(`FULL);
        $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    end
    
    // 测试2: 验证编码符号锁存功能
    $display("\n--- 测试2: 编码符号锁存功能 ---");
    
    // 测试不同的编码符号
    Code = 2'b01;
    ACSSegment = 6'h3F;  // 在这个值时才会锁存新符号
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 改变ACSSegment，验证符号已被锁存
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 改变Code但不在0x3F处，应该不会影响输出
    Code = 2'b11;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 测试3: 验证不同编码符号的度量计算
    $display("\n--- 测试3: 不同编码符号的度量计算 ---");
    
    // 测试编码符号 10
    Code = 2'b10;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 测试编码符号 11
    Code = 2'b11;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 测试4: 验证复位功能
    $display("\n--- 测试4: 复位功能验证 ---");
    
    Reset = 1'b0;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    Reset = 1'b1;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // 测试5: 完整的ACSSegment序列测试
    $display("\n--- 测试5: 完整ACSSegment序列测试 ---");
    
    Code = 2'b01;
    ACSSegment = 6'h3F;  // 先锁存符号
    #(`FULL);
    
    // 遍历所有可能的ACSSegment值
    for (i = 0; i < 64; i = i + 8) begin
        ACSSegment = i;
        #(`FULL);
        $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    end
    
    $display("\n=== BMG模块测试完成 ===");
    
    // 额外运行一些时钟周期以观察波形
    #(`FULL * 10);
    
    $finish;
end

//==============================================================================
// 波形输出
//==============================================================================
initial begin
    $dumpfile("tb_bmg.vcd");           // VCD文件名
    $dumpvars(0, tb_bmg);              // 转储所有层次的变量
    
    // 也可以选择性地转储特定信号
    // $dumpvars(1, Reset, Clock2, ACSSegment, Code, Distance);
end

//==============================================================================
// 监控器 - 实时显示关键信号变化
//==============================================================================
initial begin
    $monitor("时间=%0t: Reset=%b, Clock2=%b, ACSSegment=%h, Code=%b, Distance=%h", 
             $time, Reset, Clock2, ACSSegment, Code, Distance);
end

endmodule