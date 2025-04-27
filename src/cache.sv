`include "../common/config.sv"
`timescale 1ns/1ns

module way(
    input wire clk,
    input wire rst_n,
    input wire [`MAX_BIT_POS:0] addr,
    input wire [`MAX_BIT_POS:0] wdata,
    input wire [(`CACHE_LINE_SIZE * 8) - 1:0] ldata,
    input wire write_enable,
    input wire load_enable,
    input wire read_enable,
    input wire write_back_enable,
    input wire cs,
    input wire [1:0] byte_size, //00: 8bytes; 01: 16bytes; 10: 32bytes
    output wire [`MAX_BIT_POS:0] rdata,
    output wire [(`CACHE_LINE_SIZE * 8) - 1:0] write_back_data,
    output wire hit_way,
    output wire dirty_way,
    output wire valid_way
);
    reg [`CACHE_LINE_WIDTH - 1:0] cache_data [`CACHE_LINES - 1:0];
    reg hits [`CACHE_LINES - 1:0];
    reg [21:0] tags [`CACHE_LINES - 1:0];
    reg dirties [`CACHE_LINES - 1:0];
    reg valids [`CACHE_LINES - 1:0];
    wire [21:0] tag_in;
    wire [6:0] index;
    wire [3:0] offset;

    assign tag_in = addr[31:10];
    assign index = addr[9:4];
    assign offset = addr[3:0];
    
    assign hit_way = hits[index];
    assign dirty_way = dirties[index];
    assign valid_way = valids[index];

    //initialize
    integer i;
    always @(negedge rst_n) begin
      if (!rst_n) begin
        for (i = 0; i < `CACHE_LINES; i = i + 1) begin
          valids[i] <= 1'b0;
          dirties[i] <= 1'b0;
          hits[i] <= 1'b0;
          tags[i] <= 21'b0;
          cache_data[i] <= {`CACHE_LINE_WIDTH{1'b0}};
        end
      end
    end

    integer j;
    //处理write和load操作
    always @(posedge clk) begin
      if (write_enable || (read_enable && !load_enable)) begin
        //每次访问缓存，处理hit
        for (j = 0; j < `CACHE_LINES; j = j + 1) begin
          //hit
          hits[j] = (valids[j] && (tag_in == tags[j])) ? 1'b1 : 1'b0;
        end
      end
      else begin
      end
      //由Set控制片选信号
      if (cs) begin
        //write
        if (write_enable) begin
          case (byte_size)
            2'b00: cache_data[index][(offset * 8) +: 8] <= wdata[7:0];
            2'b01: cache_data[index][(offset * 8) +: 16] <= wdata[15:0];
            2'b10: cache_data[index][(offset * 8) +: 32] <= wdata;
          endcase

          //set dirty to 1
          dirties[index] <= 1'b1;
          //set valid to 1
          valids[index] <= 1'b1;
          //set tag
          tags[index] <= tag_in;

          //$display("valid: %b, tag: %b, dirty: %b, data: 0x%h", valids[index], tags[index], dirties[index], cache_data[index]);
        end
        //load
        else if (load_enable) begin
          cache_data[index] <= ldata;

          //set dirty to 0
          dirties[index] <= 1'b0;
          //set valid to 1
          valids[index] <= 1'b1;
          //set tag
          tags[index] <= tag_in;

          //$display("valid: %b, tag: %b, dirty: %b, data: 0x%h", valids[index], tags[index], dirties[index], cache_data[index]);
        end
        else begin
          //do nothing
        end
      end
      else begin
        //do nothing
      end
    end
    
    //处理read和write back操作
    assign rdata = (cs && read_enable && !load_enable) ? (byte_size == 2'b00 ? {24'b0, cache_data[index][(offset * 8) +: 8]} : 
    (byte_size == 2'b01 ? {16'b0, cache_data[index][(offset * 8) +: 16]} : cache_data[index][(offset * 8) +: 32])) : 
    {`XLEN{1'bz}};
    assign write_back_data = (write_back_enable && cs) ? cache_data[index] : {`CACHE_LINE_WIDTH{1'bz}};

endmodule

`define S_IDLE 2'b00
`define S_ADDR 2'b01
`define S_CS 2'b10
`define S_MEM 2'b11     

class LRUQueue;
  int size;
  int head;
  int last;
  reg [`CACHE_WAYS - 1:0] data [`CACHE_WAYS - 1:0];

  function new();
    size = 0;    
    head = 0;
    last = -1;
  endfunction

  function void move_front(
    input int index_in
  );
    integer i;
    reg [`CACHE_WAYS - 1:0] temp;
    temp = data[index_in];
    for (i = index_in - 1; i >= 0; i = i - 1) begin
      data[i + 1] = data[i];
    end
    data[head] = temp;

    $display("queue:\n");
    for (i = 0; i < size; i = i + 1) begin
      $display("%b\n", data[i]);
    end
  endfunction

  function void push(
    reg [`CACHE_WAYS - 1:0] cs_way
  );
    integer i;
    if (size == `CACHE_WAYS) begin
      $display("The queue is full! Push failed!");
      return;
    end

    for (i = size - 1; i >= 0; i = i - 1) begin
      data[i + 1] = data[i];
    end

    size = size + 1;
    last = last + 1;

    data[head] = cs_way;

    $display("queue:\n");
    for (i = 0; i < size; i = i + 1) begin
      $display("%b\n", data[i]);
    end
  endfunction

  function [`CACHE_WAYS - 1:0] get_last();
    return data[last];
  endfunction

  function [`CACHE_WAYS - 1:0] get_head();
    return data[head];
  endfunction

  function [`CACHE_WAYS - 1:0] pop_last();
    reg [`CACHE_WAYS - 1:0] temp;
    temp = data[last];
    last = last - 1;
    return temp;
  endfunction

  /*if exists, return index, else return -1.*/
  function int get_index(
    input [`CACHE_WAYS - 1:0] cs_way
  );
    integer i;
    for (i = 0; i < size; i = i + 1) begin
      if (data[i] == cs_way) begin
        return i;
      end
    end

    return -1;
  endfunction
endclass
module set (
    input wire clk,
    input wire [`MAX_BIT_POS:0] addr,
    input wire rst_n,
    input wire [`MAX_BIT_POS:0] wdata,
    input wire [`CACHE_LINE_WIDTH - 1:0] ldata,
    input wire [1:0] byte_size,
    input wire [`CACHE_WAYS - 1:0] hit_status,
    input wire [`CACHE_WAYS - 1:0] dirty_status,
    input wire [`CACHE_WAYS - 1:0] valid_status,
    input wire write_enable,
    input wire read_enable,
    input wire write_back_finished,
    output reg load_enable,
    output wire [`MAX_BIT_POS:0] rdata,
    output wire [`CACHE_LINE_WIDTH - 1:0] write_back_data,
    output reg op_finished,
    output reg [`CACHE_WAYS - 1:0] cs,
    output reg write_back_enable,
    output wire hit,
    output reg dirty
);

    LRUQueue queues [`CACHE_LINES - 1:0];
    LRUQueue queue;
    wire [5:0] index;
    reg [1:0] state;
    reg [1:0] next_state;
    reg [`CACHE_WAYS - 1:0] choosen_way;

    assign index = addr[9:4];
    assign hit = |hit_status;

    function [`CACHE_WAYS - 1:0] LRU(
      input [`CACHE_WAYS - 1:0] valid_status,
      input [`CACHE_WAYS - 1:0] hit_status,
      input [5:0] index
    );
      reg selected;
      reg [`CACHE_WAYS - 1:0] cs_way;
      integer k;
      int cs_way_index;
      
      cs_way = {`CACHE_WAYS{1'b0}};
      selected = 1'b0;

      //if hit
      if (|hit_status) begin
        cs_way = hit_status;
        selected = 1'b1;
        cs_way_index = queue.get_index(cs_way);
        if (cs_way_index != -1) begin
          queue.move_front(cs_way_index);
        end
        else begin
          queue.push(cs_way);
        end
        return cs_way;
      end
      else begin
      end
      
      //if valid
      for (k = 0; k < `CACHE_WAYS; k = k + 1) begin
        if (!valid_status[k]) begin
          cs_way[k] = 1'b1;
          selected = 1'b1;
          cs_way_index = queue.get_index(cs_way);
          if (cs_way_index != -1) begin
            queue.move_front(cs_way_index);
          end
          else begin
            queue.push(cs_way);
          end
          return cs_way;
        end
        else begin
        end
      end 

      if (!selected) begin
        if (queue.size == `CACHE_WAYS) begin
          cs_way = queue.get_last();
          $display("%b\n", cs_way);
          cs_way_index = queue.get_index(cs_way);
          queue.move_front(cs_way_index);
          return cs_way;
        end
        else begin
        end
      end
    endfunction

    function int validOf(
      input [`CACHE_WAYS - 1:0] cs_way
    );
      int i;
      for (i = 0; i < `CACHE_WAYS; i = i + 1) begin
        if (cs_way[i] == 1'b1) begin
          return i;
        end
      end

      return -1;
    endfunction

    //initialize
    integer i;
    always @(negedge rst_n) begin
      if (!rst_n) begin
        for (i = 0; i < `CACHE_LINES; i = i + 1) begin
          queues[i] = new();
          cs[i] = 1'b0;
        end
        load_enable <= 1'b0;
        write_back_enable <= 1'b0;
        state <= `S_IDLE;
        load_enable <= 1'b0;
      end
      else begin
      end
    end

    always @(posedge clk) begin
      state <= next_state;
    end 
    
    always @(addr or posedge write_enable or posedge read_enable) begin
      queue = queues[index];
      cs = {`CACHE_WAYS{1'b0}};
      op_finished = 1'b0;
      dirty = 1'b0;
      choosen_way = {`CACHE_WAYS{1'b0}};
    end

    always @(*) begin
      case (state)
        `S_IDLE: begin
          if ((!op_finished && (write_enable || read_enable)) 
                || load_enable) begin
            next_state = `S_ADDR;
          end
          else begin
            next_state = state;
          end
        end
        `S_ADDR: begin
          if (read_enable && !load_enable && !(|hit_status)) begin
            load_enable = 1'b1;
            choosen_way = LRU(valid_status, hit_status, index);
            dirty = dirty_status[validOf(choosen_way)];
            next_state = `S_IDLE;
          end
          else begin
            next_state = `S_CS;
          end
        end
        `S_CS: begin
          if (load_enable) begin
            next_state = `S_MEM;
          end
          else begin
            cs = LRU(valid_status, hit_status, index);
            @(posedge clk);
            next_state = `S_IDLE;
            op_finished = 1'b1;
          end
        end
        `S_MEM: begin
          if (load_enable) begin
            if (write_back_finished) begin
              if (!write_back_enable && dirty_status[validOf(choosen_way)]) begin
                write_back_enable = 1'b1;  
                cs = choosen_way; //set输出write_back_data由cs决定，write_back_enable是向外传递给组件的信号
                #10;
              end
              else begin
                write_back_enable = 1'b0;  
                cs = choosen_way;

                //写入需要一个周期
                @(posedge clk);
                load_enable = 1'b0;
                $display("load_finished.");

                @(posedge clk);
                op_finished = 1'b1; //一旦load_enable置零，马上就能触发rdata的assign语句，直接在此处结束操作即可。
                next_state = `S_IDLE;
              end
            end
            else begin
              next_state = state;
            end
          end
          else begin
            next_state = `S_IDLE;
          end
        end
        default: begin
          next_state = `S_IDLE;
        end
      endcase
    end

    genvar k;
    generate
      for (k = 0; k < `CACHE_WAYS; k = k + 1) begin
        way way (
          .clk(clk),
          .rst_n(rst_n),
          .wdata(wdata),
          .ldata(ldata),
          .write_enable(write_enable),
          .addr(addr),
          .rdata(rdata),
          .byte_size(byte_size),
          .write_back_data(write_back_data),
          .read_enable(read_enable),
          .write_back_enable(write_back_enable),
          .cs(cs[k]),
          .load_enable(load_enable),
          .hit_way(hit_status[k]),
          .dirty_way(dirty_status[k]),
          .valid_way(valid_status[k])
        );
      end
    endgenerate
endmodule

module cache (
  input clk,
  input rst_n,
  input [1:0] byte_size,
  input [`MAX_BIT_POS:0] wdata,
  input [`MAX_BIT_POS:0] addr,
  input [`CACHE_LINE_WIDTH - 1:0] ldata,
  input write_enable,
  input read_enable,
  input write_back_finished,
  output [`MAX_BIT_POS:0] rdata,
  output [`CACHE_LINE_WIDTH - 1:0] write_back_data,
  output write_back_enable,
  output op_finished,
  output hit,
  output dirty
);

  set set(
    .clk(clk),
    .rst_n(rst_n),
    .addr(addr),
    .byte_size(byte_size),
    .wdata(wdata),
    .ldata(ldata),
    .rdata(rdata),
    .write_back_data(write_back_data),
    .write_enable(write_enable),
    .read_enable(read_enable),
    .write_back_finished(write_back_finished),
    .write_back_enable(write_back_enable),
    .op_finished(op_finished),
    .hit(hit),
    .dirty(dirty)
  );
endmodule