`timescale 1ns/1ps
`include "../params.v"          // ȷ���Ѷ��� WD_DIST=2, WD_METR=8 �Ⱥ�
// ����ʱû�� params.v��Ҳ�����ֶ�д��
// `define WD_DIST 2
// `define WD_METR 8

module tb_ACS;

  /*-------------------------------------
   * �ź�����
   *------------------------------------*/
  reg                         CompareEnable;
  reg  [`WD_DIST-1:0]         Distance1, Distance0;
  reg  [`WD_METR-1:0]         PathMetric1, PathMetric0;
  wire                        Survivor;
  wire [`WD_METR-1:0]         Metric;

  /*-------------------------------------
   * DUT ʵ��
   *------------------------------------*/
  ACS dut (
    .CompareEnable (CompareEnable),
    .Distance1     (Distance1),
    .Distance0     (Distance0),
    .PathMetric1   (PathMetric1),
    .PathMetric0   (PathMetric0),
    .Survivor      (Survivor),
    .Metric        (Metric)
  );

  /*-------------------------------------
   * ��������
   *------------------------------------*/
  initial begin
    $dumpfile("acs_tb.vcd");   // ����ļ���
    $dumpvars(0, tb_ACS);      // ��¼���� testbench �㼶
  end

  /*-------------------------------------
   * ��������
   *------------------------------------*/
  initial begin
    /* -------- Case-1 : ADD0 ��С ---------- */
    CompareEnable = 1'b1;
    Distance0     = 2'd1;      // ADD0 = 1 + 10 = 11
    PathMetric0   = 8'd10;
    Distance1     = 2'd2;      // ADD1 = 2 + 15 = 17
    PathMetric1   = 8'd15;
    #10;
    $display("Case-1 -> Survivor=%0d (����0), Metric=%0d (����11)", 
              Survivor, Metric);

    /* -------- Case-2 : ADD1 ��С ---------- */
    Distance0     = 2'd3;      // ADD0 = 3 + 20 = 23
    PathMetric0   = 8'd20;
    Distance1     = 2'd0;      // ADD1 = 0 + 18 = 18
    PathMetric1   = 8'd18;
    #10;
    $display("Case-2 -> Survivor=%0d (����1), Metric=%0d (����18)", 
              Survivor, Metric);

    /* -------- Case-3 : �رձȽ� ---------- */
    CompareEnable = 1'b0;      // �������� ADD0
    Distance0     = 2'd3;      // ADD0 = 3 + 5 = 8
    PathMetric0   = 8'd5;
    Distance1     = 2'd3;      // ADD1 = 3 + 0 = 3 (��С��������)
    PathMetric1   = 8'd0;
    #10;
    $display("Case-3 -> Survivor=%0d (�޹�), Metric=%0d (����8)", 
              Survivor, Metric);

    #10 $finish;
  end

endmodule
