library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package harv_pkg is

  ----- CONSTANTS -------
  constant ALUOP_SIZE  : integer := 4;
  constant ALU_ADD_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0000";
  constant ALU_SUB_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "1000";
  constant ALU_SLL_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0001";
  constant ALU_SLT_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0010";
  constant ALU_SLTU_OP : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0011";
  constant ALU_XOR_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0100";
  constant ALU_SRL_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0101";
  constant ALU_SRA_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "1101";
  constant ALU_OR_OP   : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0110";
  constant ALU_AND_OP  : std_logic_vector(ALUOP_SIZE-1 downto 0) := "0111";

  ------- COMPONENTS -----
  component harv
  generic (
    PROGRAM_START_ADDR    : std_logic_vector(31 downto 0);
    TRAP_HANDLER_ADDR     : std_logic_vector(31 downto 0);
    TMR_CONTROL           : boolean;
    TMR_ALU               : boolean;
    HAMMING_REGFILE       : boolean;
    HAMMING_PC            : boolean
  );
  port (
    rstn_i           : in  std_logic;
    clk_i            : in  std_logic;
    start_i          : in  std_logic;
    poweron_rstn_i   : in  std_logic;
    wdt_rstn_i       : in  std_logic;
    imem_instr_i      : in  std_logic_vector(31 downto 0);
    imem_pc_o         : out std_logic_vector(31 downto 0);
    imem_req_o        : out std_logic;
    imem_gnt_i        : in  std_logic;
    imem_err_i        : in  std_logic;
    hard_dmem_o      : out std_logic;
    dmem_data_i       : in  std_logic_vector(31 downto 0);
    dmem_req_o        : out std_logic;
    dmem_wren_o       : out std_logic;
    dmem_gnt_i        : in  std_logic;
    dmem_outofrange_i : in  std_logic;
    dmem_sbu_i        : in  std_logic;
    dmem_dbu_i        : in  std_logic;
    dmem_byte_en_o    : out std_logic_vector(1 downto 0);
    dmem_usgn_dat_o   : out std_logic;
    dmem_data_o       : out std_logic_vector(31 downto 0);
    dmem_addr_o       : out std_logic_vector(31 downto 0)
  );
  end component harv;

  component control
  port (
    imem_gnt_i        : in  std_logic;
    imem_err_i        : in  std_logic;
    dmem_gnt_i        : in  std_logic;
    dmem_outofrange_i : in  std_logic;
    dmem_sbu_i        : in  std_logic;
    dmem_dbu_i        : in  std_logic;
    opcode_i          : in  std_logic_vector(6 downto 0);
    funct3_i          : in  std_logic_vector(2 downto 0);
    funct7_i          : in  std_logic_vector(6 downto 0);
    funct12_i         : in  std_logic_vector(11 downto 0);
    rstn_i            : in  std_logic;
    clk_i             : in  std_logic;
    start_i           : in  std_logic;
    imem_req_o        : out std_logic;
    dmem_req_o        : out std_logic;
    update_pc_o       : out std_logic;
    trap_o            : out std_logic;
    aluop_o           : out std_logic_vector(ALUOP_SIZE-1 downto 0);
    alusrc_imm_o      : out std_logic;
    imm_shamt_o       : out std_logic;
    imm_up_o          : out std_logic;
    regwr_o           : out std_logic;
    inv_branch_o      : out std_logic;
    branch_o          : out std_logic;
    jump_o            : out std_logic;
    jalr_o            : out std_logic;
    ecall_o           : out std_logic;
    memrd_o           : out std_logic;
    memwr_o           : out std_logic;
    byte_en_o         : out std_logic_vector(1 downto 0);
    mem_usgn_o        : out std_logic;
    load_upimm_o      : out std_logic;
    auipc_o           : out std_logic;
    csr_enable_o      : out std_logic;
    csr_source_imm_o  : out std_logic;
    csr_maskop_o      : out std_logic;
    csr_clearop_o     : out std_logic
  );
  end component control;

  component instr_fetch
  generic (
    PROGRAM_START_ADDR    : std_logic_vector;
    TRAP_HANDLER_ADDR     : std_logic_vector;
    HAMMING_PC            : boolean
  );
  port (
    branch_imm_i    : in  std_logic_vector(12 downto 0);
    jump_imm_i      : in  std_logic_vector(31 downto 0);
    inv_branch_i    : in  std_logic;
    branch_i        : in  std_logic;
    zero_i          : in  std_logic;
    jump_i          : in  std_logic;
    ecall_i         : in  std_logic;
    correct_error_i : in  std_logic;
    instr_gnt_i     : in  std_logic;
    instr_i         : in  std_logic_vector(31 downto 0);
    rstn_i          : in  std_logic;
    clk_i           : in  std_logic;
    update_pc_i     : in  std_logic;
    trap_i          : in  std_logic;
    instr_o         : out std_logic_vector(31 downto 0);
    sbu_o           : out std_logic;
    dbu_o           : out std_logic;
    pc_o            : out std_logic_vector(31 downto 0);
    pc_4_o          : out std_logic_vector(31 downto 0)
  );
  end component instr_fetch;

  component regfile
  generic (
    HAMMING_ENABLE : boolean
  );
  port (
    data_i       : in  std_logic_vector(31 downto 0);
    wren_i       : in  std_logic;
    rd_i         : in  std_logic_vector(4 downto 0);
    rs1_i        : in  std_logic_vector(4 downto 0);
    rs2_i        : in  std_logic_vector(4 downto 0);
    correct_en_i : in  std_logic;
    clk_i        : in  std_logic;
    sbu1_o       : out std_logic;
    dbu1_o       : out std_logic;
    data1_o      : out std_logic_vector(31 downto 0);
    sbu2_o       : out std_logic;
    dbu2_o       : out std_logic;
    data2_o      : out std_logic_vector(31 downto 0)
  );
  end component regfile;

  component alu
  port (
    data1_i     : in  std_logic_vector(31 downto 0);
    data2_i     : in  std_logic_vector(31 downto 0);
    operation_i : in  std_logic_vector(ALUOP_SIZE-1 downto 0);
    zero_o      : out std_logic;
    data_o      : out std_logic_vector(31 downto 0)
  );
  end component alu;

  component csr
  generic (
    TMR_CONTROL     : boolean;
    TMR_ALU         : boolean;
    HAMMING_REGFILE : boolean;
    HAMMING_PC      : boolean
  );
  port (
    rstn_i         : in  std_logic;
    clk_i          : in  std_logic;
    addr_i         : in  std_logic_vector(11 downto 0);
    data_o         : out std_logic_vector(31 downto 0);
    rs1_data_i     : in  std_logic_vector(31 downto 0);
    imm_data_i     : in  std_logic_vector(4 downto 0);
    wren_i         : in  std_logic;
    source_imm_i   : in  std_logic;
    csr_maskop_i   : in  std_logic;
    csr_clearop_i  : in  std_logic;
    trap_i         : in  std_logic;
    uscratch_i     : in  std_logic_vector(31 downto 0);
    uepc_i         : in  std_logic_vector(31 downto 0);
    ucause_i       : in  std_logic_vector(31 downto 0);
    utval_i        : in  std_logic_vector(31 downto 0);
    uip_i          : in  std_logic_vector(31 downto 0);
    reg1_cen_i     : in  std_logic;
    reg1_sbu_i     : in  std_logic;
    reg1_dbu_i     : in  std_logic;
    reg2_cen_i     : in  std_logic;
    reg2_sbu_i     : in  std_logic;
    reg2_dbu_i     : in  std_logic;
    pc_cen_i       : in  std_logic;
    pc_sbu_i       : in  std_logic;
    pc_dbu_i       : in  std_logic;
    dmem_cen_i     : in  std_logic;
    dmem_sbu_i     : in  std_logic;
    dmem_dbu_i     : in  std_logic;
    control_cen_i  : in  std_logic;
    control_err_i  : in  std_logic;
    alu_cen_i      : in  std_logic;
    alu_err_i      : in  std_logic;
    hard_pc_o      : out std_logic;
    hard_regfile_o : out std_logic;
    hard_dmem_o    : out std_logic;
    hard_control_o : out std_logic;
    hard_alu_o     : out std_logic;
    poweron_rstn_i : in  std_logic;
    wdt_rstn_i     : in  std_logic
  );
  end component csr;

  ------------- FAULT TOLERANT COMPONENTS --------------------
  component control_tmr
  port (
    imem_gnt_i        : in  std_logic;
    imem_err_i        : in  std_logic;
    dmem_gnt_i        : in  std_logic;
    dmem_outofrange_i : in  std_logic;
    dmem_sbu_i        : in  std_logic;
    dmem_dbu_i        : in  std_logic;
    opcode_i          : in  std_logic_vector(6 downto 0);
    funct3_i          : in  std_logic_vector(2 downto 0);
    funct7_i          : in  std_logic_vector(6 downto 0);
    funct12_i         : in  std_logic_vector(11 downto 0);
    correct_error_i   : in  std_logic;
    rstn_i            : in  std_logic;
    clk_i             : in  std_logic;
    start_i           : in  std_logic;
    imem_req_o        : out std_logic;
    dmem_req_o        : out std_logic;
    update_pc_o       : out std_logic;
    trap_o            : out std_logic;
    error_o           : out std_logic;
    aluop_o           : out std_logic_vector(ALUOP_SIZE-1 downto 0);
    alusrc_imm_o      : out std_logic;
    imm_shamt_o       : out std_logic;
    imm_up_o          : out std_logic;
    regwr_o           : out std_logic;
    inv_branch_o      : out std_logic;
    branch_o          : out std_logic;
    jump_o            : out std_logic;
    jalr_o            : out std_logic;
    ecall_o           : out std_logic;
    memrd_o           : out std_logic;
    memwr_o           : out std_logic;
    byte_en_o         : out std_logic_vector(1 downto 0);
    mem_usgn_o        : out std_logic;
    load_upimm_o      : out std_logic;
    auipc_o           : out std_logic;
    csr_enable_o      : out std_logic;
    csr_source_imm_o  : out std_logic;
    csr_maskop_o      : out std_logic;
    csr_clearop_o     : out std_logic
  );
  end component control_tmr;

  component alu_tmr
  port (
    data1_i         : in  std_logic_vector(31 downto 0);
    data2_i         : in  std_logic_vector(31 downto 0);
    operation_i     : in  std_logic_vector(ALUOP_SIZE-1 downto 0);
    correct_error_i : in  std_logic;
    error_o         : out std_logic;
    zero_o          : out std_logic;
    data_o          : out std_logic_vector(31 downto 0)
  );
  end component alu_tmr;

end package;
