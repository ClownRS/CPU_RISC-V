`timescale 1ns/1ns

//宏定义清零操作，默认情况下所有指令输出均为0
`define CLEAR_ALL_OUTPINTS  \
    machine_op = 8'b0;  \
    csr_op = 6'b0;  \
    jmp_op = 9'b0;  \
    alu_op = 19'b0; \
    mem_op = 9'b0;  \
    cust_op = 1'b0; \
    Invalid_Instruction = 32'bz;    \

module InsDecoder(
    input [31:0] Instruction_Code,
    input PC_EN,
    output reg [31:0] Invalid_Instruction,
    output [4:0] rd,
    output [4:0] rs1,
    output [4:0] rs2,
    output wire [6:0] imm_7,
    output wire [19:0] imm_20,
    output wire [11:0] imm_12,
    output reg [7:0] machine_op,
    output reg [5:0] csr_op,
    output reg [8:0] jmp_op,
    output reg [18:0] alu_op,
    output reg [8:0] mem_op,
    output reg cust_op
);
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign opcode = Instruction_Code[6:0];
    assign funct3 = Instruction_Code[14:12];
    assign funct7 = Instruction_Code[31:25];
    assign rd = Instruction_Code[11:7];
    assign rs1 = Instruction_Code[19:15];
    assign rs2 = Instruction_Code[24:20];
    assign imm_7 = Instruction_Code[31:25];
    assign imm_12 = Instruction_Code[31:20];
    assign imm_20 = Instruction_Code[31:12];

    function [18:0] get_alu_op_i(input [2:0] funct3, input [6:0] funct7);
        case (funct3) 
            3'b000: get_alu_op_i = 19'b0000000000000000001; //addi
            3'b010: get_alu_op_i = 19'b0000000000000000010; //slti
            3'b011: get_alu_op_i = 19'b0000000000000000100; //sltiu
            3'b100: get_alu_op_i = 19'b0000000000000001000; //xori
            3'b110: get_alu_op_i = 19'b0000000000000010000; //ori
            3'b111: get_alu_op_i = 19'b0000000000000100000; //andi
            //funct7
            3'b001: begin
              if (funct7 == 7'b0) get_alu_op_i = 19'b0000000000001000000;   //slli
            end
            3'b101: begin
              case (funct7)
                7'b0: get_alu_op_i = 19'b0000000000010000000;   //srli
                7'b0100000: get_alu_op_i = 19'b0000000000100000000; //srai
              endcase
            end
            default: begin
                Invalid_Instruction = 32'd2;
                get_alu_op_i = 19'b0;
            end
        endcase
    endfunction

    function [18:0] get_alu_op_r(input [2:0] funct3, input [6:0] funct7);
        case (funct3)
            3'b000: begin
                case (funct7)
                    7'b0: get_alu_op_r = 19'b0000000001000000000;   //add
                    7'b0100000: get_alu_op_r = 19'b0000000010000000000; //sub
                endcase
            end
            3'b001: if (funct7 == 7'b0) get_alu_op_r = 19'b0000000100000000000; //sll
            3'b010: if (funct7 == 7'b0) get_alu_op_r = 19'b0000001000000000000; //slt
            3'b011: if (funct7 == 7'b0) get_alu_op_r = 19'b0000010000000000000; //sltu
            3'b100: if (funct7 == 7'b0) get_alu_op_r = 19'b0000100000000000000; //xor
            3'b101: begin
                case (funct7) 
                    7'b0: get_alu_op_r = 19'b0001000000000000000;   //srl
                    7'b0100000: get_alu_op_r = 19'b0010000000000000000; //sra
                endcase
            end
            3'b110: if (funct7 == 7'b0) get_alu_op_r = 19'b0100000000000000000; //or
            3'b111: if (funct7 == 7'b0) get_alu_op_r = 19'b1000000000000000000; //and
            default: begin
                Invalid_Instruction = 32'd2;
                get_alu_op_r = 19'b0;
            end
        endcase
    endfunction

    function [5:0] get_csr_op(input [2:0] funct3);
        case (funct3)
            3'b001: get_csr_op = 6'b000001; //csrrw
            3'b010: get_csr_op = 6'b000010; //csrrs
            3'b011: get_csr_op = 6'b000100; //csrrc
            3'b101: get_csr_op = 6'b001000; //csrrwi
            3'b110: get_csr_op = 6'b010000; //cssrrsi
            3'b111: get_csr_op = 6'b100000; //csrrci
            default: begin
                Invalid_Instruction = 32'd2;
                get_csr_op = 6'b0;
            end
        endcase
    endfunction

    function [8:0] get_jmp_op(input [2:0] funct3);
        case (funct3)
            3'b000: get_jmp_op = 9'b000000100;  //beq
            3'b001: get_jmp_op = 9'b000001000;  //bne
            3'b100: get_jmp_op = 9'b000010000;  //blt
            3'b101: get_jmp_op = 9'b000100000;  //bge
            3'b110: get_jmp_op = 9'b001000000;  //bltu
            3'b111: get_jmp_op = 9'b010000000;  //bgeu
            default: begin
                get_jmp_op = 9'b0;
                Invalid_Instruction = 32'd2;
            end 
        endcase
    endfunction

    function [8:0] get_mem_load_op(input [2:0] funct3);
        case (funct3)
            3'b000: get_mem_load_op = 9'b000000010;  //lb
            3'b001: get_mem_load_op = 9'b000000100;  //lh
            3'b010: get_mem_load_op = 9'b000001000;  //lw
            3'b100: get_mem_load_op = 9'b000010000;  //lbu
            3'b111: get_mem_load_op = 9'b000100000;  //lhu
            default: begin
                get_mem_load_op = 9'b0;
                Invalid_Instruction = 32'd2;
            end
        endcase
    endfunction

    function [8:0] get_mem_store_op(input [2:0] funct3);
        case (funct3)
            3'b000: get_mem_store_op = 9'b001000000;  //sb
            3'b001: get_mem_store_op = 9'b010000000;  //sh
            3'b010: get_mem_store_op = 9'b010000000;  //sw
            default: begin
                get_mem_store_op = 9'b0;
                Invalid_Instruction = 32'd2;
            end
        endcase
    endfunction

    function [7:0] get_machine_op(input [31:0] Instruction_Code);
        case (Instruction_Code)
            32'h100073: get_machine_op = 8'b00000001; //ebreak
            32'h73: get_machine_op = 8'b00000010; //ecall
            default: begin
                get_machine_op = 8'b0;
                Invalid_Instruction = 32'd2;
            end
        endcase
    endfunction

    always @(*) begin
      if (PC_EN) begin
        `CLEAR_ALL_OUTPINTS;
        if (opcode[1:0] != 2'b11) begin
            Invalid_Instruction = 32'd2;    //我们固定将Invalid_Instruction赋值为32'd2
        end
        else begin
            case (opcode)
                //alu_op_i
                7'b0010011: begin
                    alu_op = get_alu_op_i(funct3, funct7);
                end
                //alu_op_r
                7'b0110011: begin
                    alu_op = get_alu_op_r(funct3, funct7);
                end
                //cust_op
                7'b0011111: begin
                    cust_op = 1'b1;
                end
                //csr_op
                7'b1110011: begin
                    if (funct3 == 3'b000) begin
                        machine_op = get_machine_op(Instruction_Code);
                    end
                    else begin
                        csr_op = get_csr_op(funct3);
                    end    
                end
                //jmp_op
                7'b1101111: begin
                    jmp_op = 9'b000000001;  //jal
                end
                7'b1100111: begin
                    jmp_op = 9'b000000001;  //jalr
                end
                7'b1100011: begin
                    jmp_op = get_jmp_op(funct3);
                end
                //auipc
                7'b0010111: begin
                    jmp_op = 9'b100000000;
                end
                //mem_op
                7'b0110111: begin
                    mem_op = 9'b000000001;  //lui
                end
                7'b0000011: begin
                    mem_op = get_mem_load_op(funct3);
                end
                7'b0100011: begin
                    mem_op = get_mem_store_op(funct3);
                end
            endcase
        end
    end
    else begin
        `CLEAR_ALL_OUTPINTS;
    end
end

endmodule