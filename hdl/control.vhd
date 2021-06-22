library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.harv_pkg.all;

entity control is
  port (
    -- input ports
    -- processor status
    imem_gnt_i : in std_logic;
    imem_err_i : in std_logic;
    dmem_gnt_i : in std_logic;
    dmem_err_i : in std_logic;
    dmem_sbu_i : in std_logic;
    dmem_dbu_i : in std_logic;

    -- instruction decode
    opcode_i  : in std_logic_vector(6 downto 0);
    funct3_i  : in std_logic_vector(2 downto 0);
    funct7_i  : in std_logic_vector(6 downto 0);
    funct12_i : in std_logic_vector(11 downto 0);

    -- sync
    rstn_i  : in std_logic;
    clk_i   : in std_logic;
    start_i : in std_logic;

    -- output ports
    -- processor status
    imem_req_o : out std_logic;
    dmem_req_o : out std_logic;

    update_pc_o : out std_logic;
    trap_o      : out std_logic;

    -- ALU operations
    aluop_o      : out std_logic_vector(ALUOP_SIZE-1 downto 0);
    alusrc_imm_o : out std_logic;
    -- immediate selector
    imm_shamt_o : out std_logic;
    imm_up_o    : out std_logic;
    -- register bank
    regwr_o : out std_logic;
    -- control transfer
    inv_branch_o : out std_logic;
    branch_o     : out std_logic;
    jump_o       : out std_logic;
    jalr_o       : out std_logic;
    ecall_o      : out std_logic;
    -- mem access
    mem_rd_o   : out std_logic;
    mem_wr_o   : out std_logic;
    mem_ben_o  : out std_logic_vector(1 downto 0);
    mem_usgn_o : out std_logic; -- unsigned data
    -- U type
    load_upimm_o : out std_logic;
    auipc_o      : out std_logic;
    -- csr control
    csr_enable_o     : out std_logic;
    csr_source_imm_o : out std_logic;
    csr_maskop_o     : out std_logic;
    csr_clearop_o    : out std_logic
  );
end entity;

architecture arch of control is
  --------- PROCESSOR STATUS -----------
  subtype proc_status_t is std_logic_vector(2 downto 0);
  constant STAT_IDLE       : proc_status_t := "000";
  constant STAT_REQ_INSTR  : proc_status_t := "001";
  constant STAT_RUN        : proc_status_t := "010";
  constant STAT_DMEM_STALL : proc_status_t := "011";
  constant STAT_UPDATE_PC  : proc_status_t := "100";
  constant STAT_TRAP       : proc_status_t := "101";

  signal proc_status_r      : proc_status_t;
  signal next_proc_status_w : proc_status_t;

  -------- INSTRUCTION DECODE ----------
  subtype instr_format_t is std_logic_vector(3 downto 0);
  constant R        : instr_format_t := x"1";
  constant I_jalr   : instr_format_t := x"2";
  constant I_load   : instr_format_t := x"3";
  constant I_arith  : instr_format_t := x"4";
  constant I_fence  : instr_format_t := x"5";
  constant I_system : instr_format_t := x"6";
  constant S        : instr_format_t := x"7";
  constant B        : instr_format_t := x"8";
  constant U_lui    : instr_format_t := x"9";
  constant U_auipc  : instr_format_t := x"A";
  constant U_jal    : instr_format_t := x"B";

  --- CSR TYPES ---
  constant SYS_ECALL  : std_logic_vector(2 downto 0) := "000";
  constant SYS_CSRRW  : std_logic_vector(2 downto 0) := "001"; -- Atomic Read/Write CSR
  constant SYS_CSRRS  : std_logic_vector(2 downto 0) := "010"; -- Atomic Read and Set Bits in CSR
  constant SYS_CSRRC  : std_logic_vector(2 downto 0) := "011"; -- Atomic Read and Clear Bits in CSR
  constant SYS_CSRRWI : std_logic_vector(2 downto 0) := "101";
  constant SYS_CSRRSI : std_logic_vector(2 downto 0) := "110";
  constant SYS_CSRRCI : std_logic_vector(2 downto 0) := "111";

  -- auxiliar signals
  signal mem_wr_w : std_logic;
  signal mem_rd_w : std_logic;
  signal mem_req_w : std_logic;

  -- opcodes

  signal instr_format_w : instr_format_t;

  -- signal rshift_op_w   : std_logic_vector(ALUOP_SIZE-1 downto 0);
  -- signal add_op_w      : std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal arith_aluop_w : std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal branch_op_w   : std_logic_vector(ALUOP_SIZE-1 downto 0);

begin
  ------------------------- PROCESSOR STATUS ------------------------------
  -- STAT_REQ_INSTR
  imem_req_o <= '1' when proc_status_r = STAT_REQ_INSTR else '0';

  -- STAT_DMEM_STALL
  mem_req_w <= mem_rd_w or mem_wr_w;
  dmem_req_o <= '1' when proc_status_r = STAT_DMEM_STALL else '0';

  -- STAT_UPDATE_PC
  update_pc_o <= '1' when proc_status_r = STAT_UPDATE_PC else
                 '1' when proc_status_r = STAT_TRAP      else
                 '0';
  trap_o      <= '1' when proc_status_r = STAT_TRAP else '0';


  PROC_CURRENT_STATUS : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      proc_status_r <= STAT_IDLE;
    elsif rising_edge(clk_i) then
      proc_status_r <= next_proc_status_w;
    end if;
  end process;

  PROC_NEXT_STATUS : process(proc_status_r, start_i, imem_gnt_i, imem_err_i, dmem_err_i, mem_req_w, dmem_gnt_i)
  begin
    case proc_status_r is

      when STAT_IDLE =>
        if start_i = '1' then
          next_proc_status_w <= STAT_REQ_INSTR;
        else
          next_proc_status_w <= STAT_IDLE;
        end if;

      when STAT_REQ_INSTR =>
        if imem_err_i = '1' then
          next_proc_status_w <= STAT_IDLE;

        elsif imem_gnt_i = '1' then
          next_proc_status_w <= STAT_RUN;

        else
          next_proc_status_w <= STAT_REQ_INSTR;
        end if;

      when STAT_RUN =>
        if mem_req_w = '1' then
          next_proc_status_w <= STAT_DMEM_STALL;
        else
          next_proc_status_w <= STAT_UPDATE_PC;
        end if;

      when STAT_DMEM_STALL =>
        if dmem_err_i = '1' then -- or dmem_sbu_i = '1' or dmem_dbu_i = '1' then
          next_proc_status_w <= STAT_TRAP;
        elsif dmem_gnt_i = '1' then
          next_proc_status_w <= STAT_UPDATE_PC;
        else
          next_proc_status_w <= STAT_DMEM_STALL;
        end if;

      when STAT_UPDATE_PC =>
        next_proc_status_w <= STAT_REQ_INSTR;

      when STAT_TRAP =>
        next_proc_status_w <= STAT_REQ_INSTR;

      when others =>
        next_proc_status_w <= STAT_TRAP;

    end case;
  end process;

  ------------------------ INSTRUCTIONS DECODE ----------------------------
  with opcode_i select instr_format_w <=
    R               when "0110011",
    I_jalr          when "1100111",
    I_load          when "0000011",
    I_arith         when "0010011",
    I_fence         when "0001111",
    I_system        when "1110011",
    S               when "0100011",
    B               when "1100011",
    U_lui           when "0110111",
    U_auipc         when "0010111",
    U_jal           when "1101111",
    (others => '0') when others;
  --------------------------------- ALU -----------------------------------
  -- rshift_op_w <= ALU_SRL_OP when funct7_i = "0000000" else ALU_SRA_OP;
  -- add_op_w    <= ALU_SUB_OP when funct7_i = "0100000" and instr_format_w = R else ALU_ADD_OP;
  --
  -- with funct3_i select arith_aluop_w <=
  --   add_op_w        when "000",
  --   ALU_SLL_OP      when "001",
  --   ALU_SLT_OP      when "010",
  --   ALU_SLTU_OP     when "011",
  --   ALU_XOR_OP      when "100",
  --   rshift_op_w     when "101",
  --   ALU_OR_OP       when "110",
  --   ALU_AND_OP      when "111",
  --   (others => '0') when others;
  arith_aluop_w <= funct7_i(5) & funct3_i;

  with funct3_i(2 downto 1) select branch_op_w <=
    ALU_XOR_OP  when "00", -- beq  or bne
    ALU_SLT_OP  when "10", -- blt  or bge
    ALU_SLTU_OP when "11", -- bltu or bgeu
    (others => '0') when others;

  aluop_o <= arith_aluop_w when instr_format_w = I_arith or
                                instr_format_w = R       else
             branch_op_w   when instr_format_w = B       else
             ALU_ADD_OP; -- when instr_format_w = U_auipc, I_load, S
  alusrc_imm_o <= '1' when instr_format_w /= R and instr_format_w /= B else '0';

  ------------------------ IMMEDIATE SELECTOR ------------------------------
  -- instr[24:20]
  imm_shamt_o <= '1' when (arith_aluop_w = ALU_SLL_OP  or
                           arith_aluop_w = ALU_SRL_OP  or
                           arith_aluop_w = ALU_SRA_OP) and
                           instr_format_w = I_arith else '0';
  -- instr[31:12] -> imm[31:12]
  imm_up_o <= '1' when instr_format_w = U_lui   or
                       instr_format_w = U_auipc else '0';

  ----------------------------- REGISTER BANK -------------------------------
  regwr_o <= '1' when proc_status_r = STAT_UPDATE_PC and not (
                      instr_format_w  = I_fence                            or
                      (instr_format_w = I_system and funct3_i = SYS_ECALL) or
                      instr_format_w  = S or instr_format_w  = I_load      or
                      instr_format_w  = B)                                 else
             '1' when proc_status_r  = STAT_DMEM_STALL and
                      instr_format_w = I_load          and
                      dmem_gnt_i     = '1'             else
             '0';

  ------------------------------- BRANCHES ----------------------------------
  inv_branch_o <= funct3_i(2) xor funct3_i(0);
  branch_o <= '1' when instr_format_w = B else '0';
  jump_o   <= '1' when instr_format_w = U_jal or instr_format_w = I_jalr else '0';
  jalr_o   <= '1' when instr_format_w = I_jalr else '0';

  ecall_o  <= '0'; -- '1' when instr_format_w = I_system else

  ------------------------------ MEM ACCESS ---------------------------------
  mem_rd_w   <= '1' when instr_format_w = I_load else '0';
  mem_rd_o   <= mem_rd_w;
  mem_wr_w   <= '1' when instr_format_w = S else '0';
  mem_wr_o   <= mem_wr_w;
  mem_ben_o  <= funct3_i(1 downto 0) when funct3_i(1) = '0' else "11"; -- byte or halfword -- else word
  mem_usgn_o <= funct3_i(2);

  -------------------------------- U type -----------------------------------
  load_upimm_o <= '1' when instr_format_w = U_lui else '0';
  auipc_o      <= '1' when instr_format_w = U_auipc else '0';

  -------------------------- CSR instructions  ------------------------------
  csr_enable_o     <= '1' when instr_format_w = I_system and funct3_i /= SYS_ECALL else '0';
  csr_source_imm_o <= funct3_i(2); -- select source to write the CSR (immediate or register)
  csr_maskop_o     <= funct3_i(1); -- write operation based on mask
  csr_clearop_o    <= funct3_i(0); -- operation is CLEAR, if not, operation is SET

end architecture;
