//==============================================================================
// �ļ���: tb_bmg.v
// ����: BMG (��֧����������) �Ĳ���ƽ̨
// ����: ��֤BMGģ��Ļ������ܣ�������
//       1. ����������湦��
//       2. ��֧�������㹦��
//       3. �����������
//==============================================================================

`include "params.v"
`include "rtl/bmg.v"
`timescale 1ns/1ps

module tb_bmg();

//==============================================================================
// �źŶ���
//==============================================================================
// ʱ�Ӻ͸�λ�ź�
reg Reset;
reg Clock2;

// BMG�����ź�
reg [`WD_FSM-1:0] ACSSegment;    // FSM�ε�ַ (6λ)
reg [`WD_CODE-1:0] Code;         // ������� (2λ)

// BMG����ź�
wire [`WD_DIST*2*`N_ACS-1:0] Distance; // 8����֧���� (16λ)

// ���Լ�����
integer i;

//==============================================================================
// ����ģ��ʵ����
//==============================================================================
BMG DUT (
    .Reset(Reset),
    .Clock2(Clock2),
    .ACSSegment(ACSSegment),
    .Code(Code),
    .Distance(Distance)
);

//==============================================================================
// ʱ������
//==============================================================================
initial begin
    Clock2 = 1'b0;
    forever #(`HALF) Clock2 = ~Clock2;  // ʱ������Ϊ200ns
end

//==============================================================================
// ��������
//==============================================================================
initial begin
    // ��ʼ���ź�
    Reset = 1'b0;
    ACSSegment = 6'h00;
    Code = 2'b00;
    
    // �ȴ�����ʱ������
    #(`FULL * 2);
    
    // �ͷŸ�λ
    Reset = 1'b1;
    #(`FULL);
    
    $display("=== BMGģ����Կ�ʼ ===");
    $display("ʱ��\t\tReset\tACSSegment\tCode\tDistance");
    $display("------------------------------------------------------------");
    
    // ����1: ��֤��ͬACSSegment�µĻ�������
    $display("\n--- ����1: ������֧�������� ---");
    
    // ���ñ������Ϊ00����ACSSegment=0x3Fʱ����
    Code = 2'b00;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // �ı�ACSSegment���۲�������
    for (i = 0; i < 8; i = i + 1) begin
        ACSSegment = i;
        #(`FULL);
        $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    end
    
    // ����2: ��֤����������湦��
    $display("\n--- ����2: ����������湦�� ---");
    
    // ���Բ�ͬ�ı������
    Code = 2'b01;
    ACSSegment = 6'h3F;  // �����ֵʱ�Ż������·���
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // �ı�ACSSegment����֤�����ѱ�����
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // �ı�Code������0x3F����Ӧ�ò���Ӱ�����
    Code = 2'b11;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // ����3: ��֤��ͬ������ŵĶ�������
    $display("\n--- ����3: ��ͬ������ŵĶ������� ---");
    
    // ���Ա������ 10
    Code = 2'b10;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // ���Ա������ 11
    Code = 2'b11;
    ACSSegment = 6'h3F;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    ACSSegment = 6'h00;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // ����4: ��֤��λ����
    $display("\n--- ����4: ��λ������֤ ---");
    
    Reset = 1'b0;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    Reset = 1'b1;
    #(`FULL);
    $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    
    // ����5: ������ACSSegment���в���
    $display("\n--- ����5: ����ACSSegment���в��� ---");
    
    Code = 2'b01;
    ACSSegment = 6'h3F;  // ���������
    #(`FULL);
    
    // �������п��ܵ�ACSSegmentֵ
    for (i = 0; i < 64; i = i + 8) begin
        ACSSegment = i;
        #(`FULL);
        $display("%0t\t%b\t%h\t\t%b\t%h", $time, Reset, ACSSegment, Code, Distance);
    end
    
    $display("\n=== BMGģ�������� ===");
    
    // ��������һЩʱ�������Թ۲첨��
    #(`FULL * 10);
    
    $finish;
end

//==============================================================================
// �������
//==============================================================================
initial begin
    $dumpfile("tb_bmg.vcd");           // VCD�ļ���
    $dumpvars(0, tb_bmg);              // ת�����в�εı���
    
    // Ҳ����ѡ���Ե�ת���ض��ź�
    // $dumpvars(1, Reset, Clock2, ACSSegment, Code, Distance);
end

//==============================================================================
// ����� - ʵʱ��ʾ�ؼ��źű仯
//==============================================================================
initial begin
    $monitor("ʱ��=%0t: Reset=%b, Clock2=%b, ACSSegment=%h, Code=%b, Distance=%h", 
             $time, Reset, Clock2, ACSSegment, Code, Distance);
end

endmodule