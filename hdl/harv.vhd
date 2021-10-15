library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.harv_pkg.all;

entity harv is
  generic (
    PROGRAM_START_ADDR    : std_logic_vector(31 downto 0) := x"00000000";
    TRAP_HANDLER_ADDR     : std_logic_vector(31 downto 0) := x"00000000";
    TMR_CONTROL           : boolean := FALSE;
    TMR_ALU               : boolean := FALSE;
    HAMMING_REGFILE       : boolean := FALSE;
    HAMMING_PC            : boolean := FALSE
  );
  port (
    -- syncronization
    rstn_i  : in std_logic;
    clk_i   : in std_logic;
    start_i : in std_logic;
    -- reset cause
    poweron_rstn_i : in std_logic;
    wdt_rstn_i     : in std_logic;
    -- INSTRUCTION MEMORY
    imem_instr_i : in  std_logic_vector(31 downto 0);
    imem_pc_o    : out std_logic_vector(31 downto 0);
    imem_req_o   : out std_logic;
    imem_gnt_i   : in  std_logic;
    imem_err_i   : in  std_logic;
    -- DATA MEMORY
    hard_dmem_o  : out std_logic;
    dmem_req_o   : out std_logic;
    dmem_wren_o  : out std_logic;
    dmem_ben_o   : out std_logic_vector(1 downto 0);
    dmem_usgn_o  : out std_logic;
    dmem_addr_o  : out std_logic_vector(31 downto 0);
    dmem_wdata_o : out std_logic_vector(31 downto 0);
    dmem_gnt_i   : in  std_logic;
    dmem_err_i   : in  std_logic;
    dmem_sbu_i   : in  std_logic;
    dmem_dbu_i   : in  std_logic;
    dmem_rdata_i : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of harv is
  signal clk_w : std_logic;
  ---------Instruction Fetch ---------
  signal if_pc_w     : std_logic_vector(31 downto 0);
  signal if_pc_4_w   : std_logic_vector(31 downto 0);
  signal update_pc_w : std_logic;
  signal trap_w      : std_logic;

  --------- Instruction Decode --------
  signal opcode_w     : std_logic_vector( 6 downto 0);
  signal funct3_w     : std_logic_vector( 2 downto 0);
  signal funct7_w     : std_logic_vector( 6 downto 0);
  signal funct12_w    : std_logic_vector(11 downto 0);
  signal rd_w         : std_logic_vector( 4 downto 0);
  signal rs1_w        : std_logic_vector( 4 downto 0);
  signal rs2_w        : std_logic_vector( 4 downto 0);
  signal imm_shamt_w  : std_logic_vector( 4 downto 0);
  signal imm_up_w     : std_logic_vector(19 downto 0);
  signal imm_upj_w    : std_logic_vector(20 downto 0);
  signal imm_branch_w : std_logic_vector(12 downto 0);
  signal imm_store_w  : std_logic_vector(11 downto 0);
  signal imm_i_w      : std_logic_vector(11 downto 0);
  -- Immediate value
  signal imm_sel_w : std_logic_vector(3 downto 0);
  signal imm_w     : std_logic_vector(31 downto 0);
  -------------- CONTROL -------------
  signal ctl_aluop_w          : std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal ctl_alusrc_imm_w     : std_logic;
  signal ctl_imm_shamt_w      : std_logic;
  signal ctl_imm_up_w         : std_logic;
  signal ctl_regwr_w          : std_logic;
  signal ctl_inv_branch_w     : std_logic;
  signal ctl_branch_w         : std_logic;
  signal ctl_jump_w           : std_logic;
  signal ctl_jalr_w           : std_logic;
  signal ctl_ecall_w          : std_logic;
  signal ctl_mem_rd_w         : std_logic;
  signal ctl_mem_wr_w         : std_logic;
  signal ctl_mem_ben_w        : std_logic_vector(1 downto 0);
  signal ctl_mem_usgn_w       : std_logic;
  signal ctl_load_upimm_w     : std_logic;
  signal ctl_auipc_w          : std_logic;
  signal ctl_csr_enable_w     : std_logic;
  signal ctl_csr_source_imm_w : std_logic;
  signal ctl_csr_maskop_w     : std_logic;
  signal ctl_csr_clearop_w    : std_logic;
  signal instr_w              : std_logic_vector(31 downto 0);
  ------------- REGFILE  -------------
  signal data_wr_w   : std_logic_vector(31 downto 0);
  signal reg_data1_w : std_logic_vector(31 downto 0);
  signal reg_data2_w : std_logic_vector(31 downto 0);
  -------------- ALU -----------------
  signal alu_data1_w : std_logic_vector(31 downto 0);
  signal alu_data2_w : std_logic_vector(31 downto 0);
  signal alu_zero_w  : std_logic;
  signal alu_data_w  : std_logic_vector(31 downto 0);
  --------------- CSR -----------------
  signal csr_rdata_w  : std_logic_vector(31 downto 0);
  signal csr_ucause_w : std_logic_vector(31 downto 0);
  signal hard_pc_w      : std_logic;
  signal hard_regfile_w : std_logic;
  signal hard_control_w : std_logic;
  signal hard_alu_w     : std_logic;
  ----------- ERROR wires -------------
  -- signal reg1_cen_w : std_logic;
  signal reg1_sbu_w : std_logic;
  signal reg1_dbu_w : std_logic;
  -- signal reg2_cen_w : std_logic;
  signal reg2_sbu_w : std_logic;
  signal reg2_dbu_w : std_logic;
  -- signal pc_cen_w   : std_logic;
  signal pc_sbu_w : std_logic;
  signal pc_dbu_w : std_logic;

  signal control_err_w : std_logic;
  signal alu_err_w     : std_logic;
begin

  clk_w <= clk_i;

  instr_fetch_u : instr_fetch
  generic map (
    PROGRAM_START_ADDR    => PROGRAM_START_ADDR,
    TRAP_HANDLER_ADDR     => TRAP_HANDLER_ADDR,
    HAMMING_PC            => HAMMING_PC
  )
  port map (
    branch_imm_i    => imm_branch_w,
    jump_imm_i      => alu_data_w,
    inv_branch_i    => ctl_inv_branch_w,
    branch_i        => ctl_branch_w,
    zero_i          => alu_zero_w,
    jump_i          => ctl_jump_w,
    ecall_i         => ctl_ecall_w,
    correct_error_i => hard_pc_w,
    instr_gnt_i     => imem_gnt_i,
    instr_i         => imem_instr_i,
    rstn_i          => rstn_i,
    clk_i           => clk_w,
    update_pc_i     => update_pc_w,
    trap_i          => trap_w,
    instr_o         => instr_w,
    sbu_o           => pc_sbu_w,
    dbu_o           => pc_dbu_w,
    pc_o            => if_pc_w,
    pc_4_o          => if_pc_4_w
  );
  imem_pc_o <= if_pc_w;

  opcode_w     <= instr_w( 6 downto  0);
  funct3_w     <= instr_w(14 downto 12);
  funct7_w     <= instr_w(31 downto 25);
  funct12_w    <= instr_w(31 downto 20);
  rd_w         <= instr_w(11 downto  7);
  rs1_w        <= instr_w(19 downto 15);
  rs2_w        <= instr_w(24 downto 20);
  imm_shamt_w  <= instr_w(24 downto 20);
  imm_up_w     <= instr_w(31 downto 12);
  imm_upj_w    <= instr_w(31) & instr_w(19 downto 12) & instr_w(20) & instr_w(30 downto 21) & '0';
  imm_branch_w <= instr_w(31) & instr_w(7) & instr_w(30 downto 25) & instr_w(11 downto 8) & '0';
  imm_store_w  <= instr_w(31 downto 25) & instr_w(11 downto 7);
  imm_i_w      <= instr_w(31 downto 20);

  gen_ft_control : if TMR_CONTROL generate
      control_u : control_tmr
      port map (
        start_i          => start_i,
        imem_gnt_i       => imem_gnt_i,
        imem_err_i       => imem_err_i,
        dmem_gnt_i       => dmem_gnt_i,
        dmem_err_i       => dmem_err_i,
        dmem_sbu_i       => dmem_sbu_i and dmem_gnt_i and ctl_mem_rd_w,
        dmem_dbu_i       => dmem_dbu_i and dmem_gnt_i and ctl_mem_rd_w,
        opcode_i         => opcode_w,
        funct3_i         => funct3_w,
        funct7_i         => funct7_w,
        funct12_i        => funct12_w,
        rstn_i           => rstn_i,
        clk_i            => clk_i,
        imem_req_o       => imem_req_o,
        dmem_req_o       => dmem_req_o,
        update_pc_o      => update_pc_w,
        trap_o           => trap_w,
        aluop_o          => ctl_aluop_w,
        alusrc_imm_o     => ctl_alusrc_imm_w,
        imm_shamt_o      => ctl_imm_shamt_w,
        imm_up_o         => ctl_imm_up_w,
        regwr_o          => ctl_regwr_w,
        inv_branch_o     => ctl_inv_branch_w,
        branch_o         => ctl_branch_w,
        jump_o           => ctl_jump_w,
        jalr_o           => ctl_jalr_w,
        ecall_o          => ctl_ecall_w,
        mem_rd_o         => ctl_mem_rd_w,
        mem_wr_o         => ctl_mem_wr_w,
        mem_ben_o        => ctl_mem_ben_w,
        mem_usgn_o       => ctl_mem_usgn_w,
        load_upimm_o     => ctl_load_upimm_w,
        auipc_o          => ctl_auipc_w,
        csr_enable_o     => ctl_csr_enable_w,
        csr_source_imm_o => ctl_csr_source_imm_w,
        csr_maskop_o     => ctl_csr_maskop_w,
        csr_clearop_o    => ctl_csr_clearop_w,
        correct_error_i  => hard_control_w,
        error_o          => control_err_w
      );
  end generate;
  gen_normal_control : if not TMR_CONTROL generate
    control_u : control
    port map (
      -- processor status
      start_i    => start_i,
      imem_gnt_i => imem_gnt_i,
      imem_err_i => imem_err_i,
      dmem_gnt_i => dmem_gnt_i,
      dmem_err_i => dmem_err_i,
      dmem_sbu_i => dmem_sbu_i,
      dmem_dbu_i => dmem_dbu_i,

      -- instruction decode
      opcode_i  => opcode_w,
      funct3_i  => funct3_w,
      funct7_i  => funct7_w,
      funct12_i => funct12_w,

      rstn_i => rstn_i,
      clk_i  => clk_i,

      -- processor status
      imem_req_o  => imem_req_o,
      dmem_req_o  => dmem_req_o,
      update_pc_o => update_pc_w,
      trap_o      => trap_w,

      -- instruction decode
      aluop_o          => ctl_aluop_w,
      alusrc_imm_o     => ctl_alusrc_imm_w,
      imm_shamt_o      => ctl_imm_shamt_w,
      imm_up_o         => ctl_imm_up_w,
      regwr_o          => ctl_regwr_w,
      inv_branch_o     => ctl_inv_branch_w,
      branch_o         => ctl_branch_w,
      jump_o           => ctl_jump_w,
      jalr_o           => ctl_jalr_w,
      ecall_o          => ctl_ecall_w,
      mem_rd_o         => ctl_mem_rd_w,
      mem_wr_o         => ctl_mem_wr_w,
      mem_ben_o        => ctl_mem_ben_w,
      mem_usgn_o       => ctl_mem_usgn_w,
      load_upimm_o     => ctl_load_upimm_w,
      auipc_o          => ctl_auipc_w,
      csr_enable_o     => ctl_csr_enable_w,
      csr_source_imm_o => ctl_csr_source_imm_w,
      csr_maskop_o     => ctl_csr_maskop_w,
      csr_clearop_o    => ctl_csr_clearop_w
    );
  end generate;

  data_wr_w <= dmem_rdata_i when ctl_mem_rd_w     = '1' else
               imm_w        when ctl_load_upimm_w = '1' else
               if_pc_4_w    when ctl_jump_w       = '1' else
               csr_rdata_w  when ctl_csr_enable_w = '1' else
               alu_data_w;

  regfile_u : regfile
  generic map (
    HAMMING_ENABLE => HAMMING_REGFILE
  )
  port map (
    data_i       => data_wr_w,
    wren_i       => ctl_regwr_w,
    rd_i         => rd_w,
    rs1_i        => rs1_w,
    rs2_i        => rs2_w,
    correct_en_i => hard_regfile_w,
    clk_i        => clk_w,
    sbu1_o       => reg1_sbu_w,
    dbu1_o       => reg1_dbu_w,
    data1_o      => reg_data1_w,
    sbu2_o       => reg2_sbu_w,
    dbu2_o       => reg2_dbu_w,
    data2_o      => reg_data2_w
  );

 imm_sel_w <= ctl_imm_shamt_w & ctl_imm_up_w & ctl_mem_wr_w & (ctl_jump_w and not ctl_jalr_w);

 with imm_sel_w select imm_w <=
   std_logic_vector(resize(unsigned(imm_shamt_w), 32))            when "1000", -- ctl_imm_shamt_w                 = '1' else
   std_logic_vector(shift_left(resize(signed(imm_up_w), 32), 12)) when "0100", -- ctl_imm_up_w                    = '1' else
   std_logic_vector(resize(signed(imm_store_w), 32))              when "0010", -- ctl_mem_wr_w                    = '1' else
   std_logic_vector(resize(signed(imm_upj_w),   32))              when "0001", -- (ctl_jump_w and not ctl_jalr_w) = '1' else
   std_logic_vector(resize(signed(imm_i_w),     32))              when others;

  alu_data1_w <= if_pc_w when (ctl_auipc_w or (ctl_jump_w and not ctl_jalr_w)) = '1' else reg_data1_w;
  alu_data2_w <= imm_w when ctl_alusrc_imm_w = '1' else reg_data2_w;

  gen_ft_alu : if TMR_ALU generate
    alu_u : alu_tmr
    port map (
      data1_i         => alu_data1_w,
      data2_i         => alu_data2_w,
      operation_i     => ctl_aluop_w,
      zero_o          => alu_zero_w,
      data_o          => alu_data_w,
      correct_error_i => hard_alu_w,
      error_o         => alu_err_w
    );
  end generate;
  gen_normal_alu : if not TMR_ALU generate
    alu_u : alu
    port map (
      data1_i     => alu_data1_w,
      data2_i     => alu_data2_w,
      operation_i => ctl_aluop_w,
      zero_o      => alu_zero_w,
      data_o      => alu_data_w
    );
  end generate;

  ---------- CSR registers ---------
  csr_ucause_w <= x"00000010" when dmem_sbu_i   = '1' else -- SBU
                  x"00000020" when dmem_dbu_i   = '1' else -- DBU
                  x"00000007" when ctl_mem_wr_w = '1' else -- store address fault
                  x"00000005"; -- when ctl_mem_rd_w = '1'  -- load address fault
  csr_u : csr
  generic map (
    TMR_CONTROL     => TMR_CONTROL,
    TMR_ALU         => TMR_ALU,
    HAMMING_REGFILE => HAMMING_REGFILE,
    HAMMING_PC      => HAMMING_PC
  )
  port map (
    -- sync
    rstn_i         => rstn_i,
    clk_i          => clk_i,
    -- access interface
    addr_i         => imm_i_w,
    data_o         => csr_rdata_w,
    rs1_data_i     => reg_data1_w,
    imm_data_i     => rs1_w,
    wren_i         => ctl_csr_enable_w,
    source_imm_i   => ctl_csr_source_imm_w,
    csr_maskop_i   => ctl_csr_maskop_w,
    csr_clearop_i  => ctl_csr_clearop_w,
    -- trap handling
    trap_i        => trap_w,
    uscratch_i    => alu_data_w,
    uepc_i        => if_pc_w,
    ucause_i      => csr_ucause_w,
    utval_i       => reg_data2_w,
    uip_i         => x"00000000",
    -- errors
    reg1_cen_i     => update_pc_w,
    reg1_sbu_i     => reg1_sbu_w,
    reg1_dbu_i     => reg1_dbu_w,
    reg2_cen_i     => update_pc_w,
    reg2_sbu_i     => reg2_sbu_w,
    reg2_dbu_i     => reg2_dbu_w,
    pc_cen_i       => update_pc_w,
    pc_sbu_i       => pc_sbu_w,
    pc_dbu_i       => pc_dbu_w,
    dmem_cen_i     => dmem_gnt_i and not ctl_mem_wr_w,
    dmem_sbu_i     => dmem_sbu_i,
    dmem_dbu_i     => dmem_dbu_i,
    control_cen_i  => '1',
    control_err_i  => control_err_w,
    alu_cen_i      => dmem_gnt_i or update_pc_w or ctl_regwr_w,
    alu_err_i      => alu_err_w,
    -- hardening
    hard_pc_o      => hard_pc_w,
    hard_regfile_o => hard_regfile_w,
    hard_dmem_o    => hard_dmem_o,
    hard_control_o => hard_control_w,
    hard_alu_o     => hard_alu_w,
    -- resets
    poweron_rstn_i => poweron_rstn_i,
    wdt_rstn_i     => wdt_rstn_i
  );

  -------- DATA MEMORY --------
  -- output signals
  -- dmem_req_o is set by the control unit
  dmem_wren_o  <= ctl_mem_wr_w;
  dmem_ben_o   <= ctl_mem_ben_w;
  dmem_usgn_o  <= ctl_mem_usgn_w;
  dmem_wdata_o <= reg_data2_w;
  dmem_addr_o  <= alu_data_w;

end architecture;
