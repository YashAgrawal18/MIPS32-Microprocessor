module pipe_MIPS32 (
    clk1, clk2
   
);
    input clk1, clk2;

    reg [31:0] PC, IF_ID_IR, IF_ID_NPC;                         //Initializing the registers in IF_ID stage
    reg [31:0] ID_EX_IR, ID_EX_NPC, ID_EX_A, ID_EX_B, ID_EX_IMM;  //Initializing the registers in ID_EX stage
    reg [31:0] EX_MEM_IR, EX_MEM_B, EX_MEM_ALUOUT;
    reg EX_MEM_cond; //Initializing the registers in EX_MEM stage
    reg [31:0] MEM_WB_IR, MEM_WB_LMD, MEM_WB_ALUOUT;            //Initializing the registers in MEM_WB stage
    reg [2:0]  ID_EX_type, EX_MEM_type, MEM_WB_type;            //Initializing the registers for type of set of opeartions.

    reg [31:0] Reg [0:31];                                          
    reg [31:0] Mem [0:1023];                                    //Initializing memory of 4KB

    parameter ADD=6'b000000, SUB=6'b000001, AND=6'b000010, OR=6'b000011, SLT=6'b000100, MUL=6'b000101, HLT=6'b111111, LW=6'b001000, SW=6'b001001, ADDI=6'b001010, SUBI=6'b001011, SLTI=6'b001100, BNEQZ=6'b001101, BEQZ=6'b001110;

    parameter RR_ALU=3'b000, RM_ALU=3'b001, LOAD=3'b010, STORE=3'b011, BRANCH=3'b100, HALT=3'b101;

    reg HALTED;       // Set after halt instruction is completed.
    reg TAKEN_BRANCH; // Required to disable instructions after branch.

    always @(posedge clk1) begin       //IF stage
        
        if(HALTED==0)
        begin
            if(((EX_MEM_IR[31:26]==BEQZ) && (EX_MEM_cond==1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond==0)))
            begin
                IF_ID_IR     <= #2 Mem[EX_MEM_ALUOUT] ;
                TAKEN_BRANCH <= #2 1'b1;
                IF_ID_NPC    <= #2 EX_MEM_ALUOUT + 1;
                PC           <= #2 EX_MEM_ALUOUT + 1;
            end

            else
            begin
                IF_ID_IR     <= #2 Mem[PC];
                IF_ID_NPC    <= #2 PC + 1;
                PC           <= #2 PC + 1;
            end
        end    
    end

    always @(posedge clk2) begin //ID stage
        if(HALTED==0)
        begin
            if(IF_ID_IR[25:21] == 5'b00000)  ID_EX_A <= 0;
            else ID_EX_A       <= #2 Reg[IF_ID_IR[25:21]];   //rs

            if(IF_ID_IR[20:16] == 5'b00000)  ID_EX_B <= 0;
            else ID_EX_B       <= #2 Reg[IF_ID_IR[20:16]];   //rt
            
            ID_EX_NPC          <= #2 IF_ID_NPC;
            ID_EX_IR           <= #2 IF_ID_IR;
            ID_EX_IMM          <= #2 {{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}};

            case (IF_ID_IR[31:26])
                   ADD, SUB, AND, OR, SLT, MUL: ID_EX_type <= #2 RR_ALU;
                   ADDI, SUBI, SLTI:            ID_EX_type <= #2 RM_ALU;
                   LW:                          ID_EX_type <= #2 LOAD;
                   SW:                          ID_EX_type <= #2 STORE;
                   BEQZ, BNEQZ:                 ID_EX_type <= #2 BRANCH;
                   HLT:                         ID_EX_type <= #2 HALT;
                   default:                     ID_EX_type <= #2 HALT;

            endcase
        end
    end

    always @(posedge clk1) begin   //EX stage
        if(HALTED==0)   
        begin
            EX_MEM_type  <= #2 ID_EX_type;
            EX_MEM_IR    <= #2 ID_EX_IR;
            TAKEN_BRANCH <= #2 0;

            case(ID_EX_type)
              RR_ALU: begin
                        case(ID_EX_IR[31:26]) 
                          ADD: EX_MEM_ALUOUT     <= #2 ID_EX_A + ID_EX_B; 
                          SUB: EX_MEM_ALUOUT     <= #2 ID_EX_A - ID_EX_B;
                          AND: EX_MEM_ALUOUT     <= #2 ID_EX_A & ID_EX_B;
                          OR:  EX_MEM_ALUOUT     <= #2 ID_EX_A | ID_EX_B;
                          SLT: EX_MEM_ALUOUT     <= #2 ID_EX_A < ID_EX_B;
                          MUL: EX_MEM_ALUOUT     <= #2 ID_EX_A * ID_EX_B;
                          default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx;
                        endcase
              end    
              RM_ALU: begin
                        case(ID_EX_IR[31:26])
                          ADDI:    EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM; 
                          SUBI:    EX_MEM_ALUOUT <= #2 ID_EX_A - ID_EX_IMM;
                          SLTI:    EX_MEM_ALUOUT <= #2 ID_EX_A < ID_EX_IMM;
                          default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx;
                        endcase      
              end
              LOAD, STORE: begin
                            EX_MEM_ALUOUT <= #2 ID_EX_A + ID_EX_IMM;
                            EX_MEM_B   <= #2 ID_EX_B;
              end

              BRANCH: begin
                        EX_MEM_ALUOUT <= #2 ID_EX_NPC + ID_EX_IMM;
                        EX_MEM_cond   <= #2 (ID_EX_A==0);
              end
            endcase
        end
    end

    always @(posedge clk2) begin    //MEM stage
        if(HALTED==0)
        begin
            MEM_WB_type <=  EX_MEM_type;
            MEM_WB_IR     <= #2 MEM_WB_IR;
            case(EX_MEM_type) 
              RR_ALU, RM_ALU: MEM_WB_ALUOUT <= #2 EX_MEM_ALUOUT;
              LOAD:           MEM_WB_LMD    <= #2 Mem[EX_MEM_ALUOUT];
              STORE:          if(TAKEN_BRANCH==0)
                                Mem [EX_MEM_ALUOUT] <= #2 EX_MEM_B;
            endcase
       end
    end

    always @(posedge clk1) begin   // WB stage
        if(TAKEN_BRANCH==0)       // Disable write if branch taken                            
        case(MEM_WB_type)                    
            RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOUT;  // rd = MEM_WB_IR[15:11], rd <--- MEM_WB_ALUOUT.
            RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOUT;  // rt = MEM_WB_IR[20:16], rt <--- MEM_WB_ALUOUT. 
            LOAD:   Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD;     // rt = MEM_WB_IR[20:16], rt <--- MEM_WB_LMD.
            HALT:   HALTED <= #2 1'b1;
        endcase
    end
endmodule