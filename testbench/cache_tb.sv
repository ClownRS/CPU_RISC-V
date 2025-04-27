`include "../src/cache.sv"
`include "../common/config.sv"
`timescale 1ns/1ns

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
  reg write_back_enable;
  reg op_finished;
  reg hit;
  reg dirty;

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
    .write_back_enable(write_back_enable),
    .op_finished(op_finished),
    .hit(hit),
    .dirty(dirty)
  );

    task read(
      input [`MAX_BIT_POS:0] addr_in,
      input [1:0] byte_size_in
    );
      addr = addr_in;
      read_enable = 1'b1;
      byte_size = byte_size_in;
      #10;
      wait(op_finished);
      $display("op: read, addr: 0x%h, rdata: 0x%h, op_finished: %b", addr, rdata, op_finished);
      read_enable = 1'b0;
    endtask

    task write(
      input [`MAX_BIT_POS:0] addr_in,
      input [`MAX_BIT_POS:0] wdata_in,
      input [1:0] byte_size_in
    );
      addr = addr_in;
      write_enable = 1'b1;
      wdata = wdata_in;
      byte_size = byte_size_in;
      #10;
      wait(op_finished);
      $display("op: write, addr: 0x%h, op_finished: %b", addr, op_finished);
      write_enable = 1'b0;
    endtask

    task read_then_load(
      input [`MAX_BIT_POS:0] addr_in,
      input [`CACHE_LINE_WIDTH - 1:0] ldata_in,
      input [1:0] byte_size_in
    );
      addr = addr_in;
      read_enable = 1'b1;
      byte_size = byte_size_in;
      #10;

      if (dirty) begin
        wait(write_back_enable);
        write_back_finished = 1'b0;
        #10;
        $display("write_back_data: 0x%h", write_back_data);
        write_back_finished = 1'b1;
      end
      else begin
      end

      ldata = ldata_in;
      wait(op_finished);
      $display("op: read, addr: 0x%h, rdata: 0x%h, op_finished: %b", addr, rdata, op_finished);
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
      write_back_finished = 1'b1;

      #20
      rst_n = 1'b0;
      #20

      // write data
      $display("\nwrite data");
      #21;
      write(32'h0000_0000,32'h0000_1234, 2'b10);
      #21;
      read(32'h0000_0000, 2'b10);
      #21;
      write(32'h1000_0000, 32'h0001_2345, 2'b10);
      #21;
      read(32'h1000_0000, 2'b10);
      #21;
      write(32'h2000_0000, 32'h0012_3456, 2'b10);
      #21;
      read(32'h2000_0000, 2'b10);
      #21;
      write(32'h3000_0000, 32'h0123_4567, 2'b10);
      #21;
      read(32'h3000_0000, 2'b10);

      // way 0
      #21;
      $display("way 0");
      read_then_load(32'h4000_0000,128'h1010_0000_1C1C_0000_1414_0000_1111, 2'b10);
      #21;
      read(32'h4000_0000, 2'b10);
      #21;
      read(32'h4000_0004, 2'b10);
      #21;
      read(32'h4000_0008, 2'b10);
      #21;
      read(32'h4000_000C, 2'b10);

      // way 1
      $display("\nway 1");
      #21;
      read_then_load(32'hA000_0000,128'hAAAA, 2'b10);
      #21;
      read(32'hA000_0000, 2'b10);
      #21;
      read(32'h0000_0000, 2'b10);

      // diffent index
      #21;
      $display("\ndiffent index");
      #21;
      read_then_load(32'h0000_0010,128'h1010, 2'b10);
      #21;
      read(32'h0000_0010, 2'b10);
      #21;
      read(32'hA000_0000, 2'b10);
      #21;
      read(32'h0000_0000, 2'b10);
      
      // replace
      #21;
      $display("\nreplace");
      #21;
      read_then_load(32'hB000_0000,128'h1111_2222_3333_4444_5555_6666_7777_BBBB, 2'b10);
      #21;
      read(32'hB000_0000, 2'b10);
      #21;
      read(32'h0000_0010, 2'b10);
      #21;
      read(32'hA000_0000, 2'b10);
      #21;
      read(32'h0000_0000, 2'b10);

      #21;

      #101;
      $finish;
  end

endmodule