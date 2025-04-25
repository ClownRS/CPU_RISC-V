`include "../src/cache.sv"
`include "../common/config.sv"

module cache_tb ();
  reg clk;
  reg rst_n;
  reg [1:0] byte_size;
  reg [`MAX_BIT_POS:0] wdata;
  reg [`CACHE_LINE_WIDTH - 1:0] ldata;
  reg write_enable;
  reg [`MAX_BIT_POS:0] addr;
  reg [`MAX_BIT_POS:0] rdata;
  reg [`CACHE_LINE_WIDTH - 1:0] write_back_data;
  reg read_enable;
  reg write_back_finished;
  reg load_finished;
  reg write_back_enable;
  reg op_finished;

  reg [`MAX_BIT_POS:0] read_out;

  //clock
  always #10 clk = ~clk;

  initial begin
    $dumpfile("../build/cache_tb.vcd");
    $dumpvar;
  end


  cache dut(
    .clk(clk),
    .rst_n(rst_n),
    .byte_size(byte_size),
    .wdata(wdata),
    .ldata(ldata),
    .write_enable(write_enable),
    .addr(addr),
    .rdata(rdata),
    .write_back_data(write_back_data),
    .read_enable(read_enable),
    .write_back_finished(write_back_finished),
    .load_finished(load_finished),
    .write_back_enable(write_back_enable),
    .op_finished(op_finished)
  );

    task read(
      input [`MAX_BIT_POS:0] addr_in
    );
      addr = addr_in;
      read_enable = 1'b1;
      wait(op_finished);
      $display("op: read, addr: %h, rdata: %h, op_finished: %b", addr, rdata, op_finished);
      read_enable = 1'b0;
    endtask

    task write(
      input [`MAX_BIT_POS:0] addr_in,
      input [`MAX_BIT_POS:0] wdata
    );
      addr = addr_in;
      write_enable = 1'b1;
      wait(op_finished);
      $display("op: write, addr: %h, op_finished: %b", addr, op_finished);
      write_enable = 1'b0;
    endtask

    task read_then_load(
      input [`MAX_BIT_POS:0] addr_in,
      input [`CACHE_LINE_WIDTH - 1:0] ldata_in
    );
      addr = addr_in;
      read_enable = 1'b1;
      ldata = ldata_in;
      wait(op_finished);
      $display("op: read, addr: %h, rdata: %h, op_finished: %b", addr, rdata, op_finished);
      read_enable = 1'b0;
    endtask
    
    initial begin
      clk = 1'b0;
      rst_n = 1'b1;
      byte_size = 2'b0;
      wdata = {`MAX_BIT_POS{1'b0}};
      ldata = {(`CACHE_LINE_WIDTH - 1){1'b0}};
      write_enable = 1'b0;
      addr = {`MAX_BIT_POS{1'b0}};
      read_enable = 1'b0;
      write_back_finished = 1'b0;
      load_finished = 1'b0;

      #20
      rst_n = 1'b0;
      #20

      // write data
      $display("\nwrite data");
      #21;
      write(32'h0000_0000,32'h0000_1234);
      #21;
      read(32'h0000_0000);

      // way 0
      $display("way 0");
      read_then_load(32'h0000_0000,128'h1010_0000_1C1C_0000_1414_0000_1111);
      #21;
      read(32'h0000_0000);
      #21;
      read(32'h0000_0004);
      #21;
      read(32'h0000_0008);
      #21;
      read(32'h0000_000C);

      // way 1
      $display("\nway 1");
      #21;
      read_then_load(32'hA000_0000,128'hAAAA);
      #21;
      read(32'hA000_0000);
      #21;
      read(32'h0000_0000);

      // diffent index
      $display("\ndiffent index");
      #21;
      read_then_load(32'h0000_0010,128'h1010);
      #21;
      read(32'h0000_0010);
      #21;
      read(32'hA000_0000);
      #21;
      read(32'h0000_0000);
      
      // replace
      $display("\nreplace");
      #21;
      read_then_load(32'hB000_0000,128'h1111_2222_3333_4444_5555_6666_7777_BBBB);
      #21;
      read(32'hB000_0000);
      #21;
      read(32'h0000_0010);
      #21;
      read(32'hA000_0000);
      #21;
      read(32'h0000_0000);

      // write back dirty data
      $display("\nwrite back dirty data");
      #21;
      read(32'hB000_0000);
      #21;
      read_then_load(32'hC000_0000,128'hCCCC);
      #21;
      read(32'h0000_0000);
      #21;
      read(32'hC000_0000);
      #21;
      read(32'hB000_0000);

      #21;

      #101;
      $finish;
  end

endmodule