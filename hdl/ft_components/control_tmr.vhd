library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.harv_pkg.all;

entity control_tmr is
  port (
    -- input ports
    -- processor status
    imem_gnt_i        : in std_logic;
    imem_err_i        : in std_logic;
    dmem_gnt_i        : in std_logic;
    dmem_outofrange_i : in std_logic;
    dmem_sbu_i        : in std_logic;
    dmem_dbu_i        : in std_logic;

    -- instruction decode
    opcode_i  : in std_logic_vector(6 downto 0);
    funct3_i  : in std_logic_vector(2 downto 0);
    funct7_i  : in std_logic_vector(6 downto 0);
    funct12_i : in std_logic_vector(11 downto 0);

    -- hardening
    correct_error_i : in std_logic;

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

    -- hardening
    error_o : out std_logic;

    -- ALU operations
    aluop_o      : out std_logic_vector(ALUOP_SIZE-1 downto 0);
    alusrc_imm_o : out std_logic;
    -- immediate selector
    imm_shamt_o : out std_logic;
    imm_up_o    : out std_logic;
    -- register bank
    regwr_o  : out std_logic;
    -- control transfer
    inv_branch_o : out std_logic;
    branch_o     : out std_logic;
    jump_o       : out std_logic;
    jalr_o       : out std_logic;
    ecall_o      : out std_logic;
    -- mem access
    memrd_o    : out std_logic;
    memwr_o    : out std_logic;
    byte_en_o  : out std_logic_vector(1 downto 0);
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

architecture arch of control_tmr is
  type tmr_std_logic_t is array(2 downto 0) of std_logic;
  signal imem_req_w        : tmr_std_logic_t;
  signal dmem_req_w        : tmr_std_logic_t;
  signal update_pc_w       : tmr_std_logic_t;
  signal trap_w            : tmr_std_logic_t;
  signal alusrc_imm_w      : tmr_std_logic_t;
  signal imm_shamt_w       : tmr_std_logic_t;
  signal imm_up_w          : tmr_std_logic_t;
  signal regwr_w           : tmr_std_logic_t;
  signal inv_branch_w      : tmr_std_logic_t;
  signal branch_w          : tmr_std_logic_t;
  signal jump_w            : tmr_std_logic_t;
  signal jalr_w            : tmr_std_logic_t;
  signal ecall_w           : tmr_std_logic_t;
  signal memrd_w           : tmr_std_logic_t;
  signal memwr_w           : tmr_std_logic_t;
  signal mem_usgn_w        : tmr_std_logic_t;
  signal load_upimm_w      : tmr_std_logic_t;
  signal auipc_w           : tmr_std_logic_t;
  signal csr_enable_w      : tmr_std_logic_t;
  signal csr_source_imm_w  : tmr_std_logic_t;
  signal csr_maskop_w      : tmr_std_logic_t;
  signal csr_clearop_w     : tmr_std_logic_t;

  signal corr_imem_req_w        : std_logic;
  signal corr_dmem_req_w        : std_logic;
  signal corr_update_pc_w       : std_logic;
  signal corr_trap_w            : std_logic;
  signal corr_alusrc_imm_w      : std_logic;
  signal corr_imm_shamt_w       : std_logic;
  signal corr_imm_up_w          : std_logic;
  signal corr_regwr_w           : std_logic;
  signal corr_inv_branch_w      : std_logic;
  signal corr_branch_w          : std_logic;
  signal corr_jump_w            : std_logic;
  signal corr_jalr_w            : std_logic;
  signal corr_ecall_w           : std_logic;
  signal corr_memrd_w           : std_logic;
  signal corr_memwr_w           : std_logic;
  signal corr_mem_usgn_w        : std_logic;
  signal corr_load_upimm_w      : std_logic;
  signal corr_auipc_w           : std_logic;
  signal corr_csr_enable_w      : std_logic;
  signal corr_csr_source_imm_w  : std_logic;
  signal corr_csr_maskop_w      : std_logic;
  signal corr_csr_clearop_w     : std_logic;

  signal error_imem_req_w        : std_logic;
  signal error_dmem_req_w        : std_logic;
  signal error_update_pc_w       : std_logic;
  signal error_trap_w            : std_logic;
  signal error_alusrc_imm_w      : std_logic;
  signal error_imm_shamt_w       : std_logic;
  signal error_imm_up_w          : std_logic;
  signal error_regwr_w           : std_logic;
  signal error_inv_branch_w      : std_logic;
  signal error_branch_w          : std_logic;
  signal error_jump_w            : std_logic;
  signal error_jalr_w            : std_logic;
  signal error_ecall_w           : std_logic;
  signal error_memrd_w           : std_logic;
  signal error_memwr_w           : std_logic;
  signal error_mem_usgn_w        : std_logic;
  signal error_load_upimm_w      : std_logic;
  signal error_auipc_w           : std_logic;
  signal error_csr_enable_w      : std_logic;
  signal error_csr_source_imm_w  : std_logic;
  signal error_csr_maskop_w      : std_logic;
  signal error_csr_clearop_w     : std_logic;

  type tmr_alu_operations_t is array(2 downto 0) of std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal aluop_w : tmr_alu_operations_t;
  signal corr_aluop_w : std_logic_vector(ALUOP_SIZE-1 downto 0);
  signal error_aluop_w : std_logic;

  type tmr_std_logic_2_t is array(2 downto 0) of std_logic_vector(1 downto 0);
  signal byte_en_w : tmr_std_logic_2_t;
  signal corr_byte_en_w : std_logic_vector(1 downto 0);
  signal error_byte_en_w : std_logic;

begin
  gen_TMR : for i in 2 downto 0 generate
    -- Xilinx attributes to prevent optimization of TMR
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of control_i : label is "TRUE";
    -- Synplify attributes to prevent optimization of TMR
    attribute syn_radhardlevel : string;
    attribute syn_keep         : boolean;
    attribute syn_safe_case    : boolean;
    attribute syn_noprune      : boolean;
    attribute syn_radhardlevel of control_i : label is "tmr";
    attribute syn_keep         of control_i : label is TRUE;
    attribute syn_safe_case    of control_i : label is TRUE;
    attribute syn_noprune      of control_i : label is TRUE;
  begin
    control_i : control
    port map (
      imem_gnt_i        => imem_gnt_i,
      imem_err_i        => imem_err_i,
      dmem_gnt_i        => dmem_gnt_i,
      dmem_outofrange_i => dmem_outofrange_i,
      dmem_sbu_i        => dmem_sbu_i,
      dmem_dbu_i        => dmem_dbu_i,
      opcode_i          => opcode_i,
      funct3_i          => funct3_i,
      funct7_i          => funct7_i,
      funct12_i         => funct12_i,
      rstn_i            => rstn_i,
      clk_i             => clk_i,
      start_i           => start_i,
      imem_req_o        => imem_req_w(i),
      dmem_req_o        => dmem_req_w(i),
      update_pc_o       => update_pc_w(i),
      trap_o            => trap_w(i),
      aluop_o           => aluop_w(i),
      alusrc_imm_o      => alusrc_imm_w(i),
      imm_shamt_o       => imm_shamt_w(i),
      imm_up_o          => imm_up_w(i),
      regwr_o           => regwr_w(i),
      inv_branch_o      => inv_branch_w(i),
      branch_o          => branch_w(i),
      jump_o            => jump_w(i),
      jalr_o            => jalr_w(i),
      ecall_o           => ecall_w(i),
      memrd_o           => memrd_w(i),
      memwr_o           => memwr_w(i),
      byte_en_o         => byte_en_w(i),
      mem_usgn_o        => mem_usgn_w(i),
      load_upimm_o      => load_upimm_w(i),
      auipc_o           => auipc_w(i),
      csr_enable_o      => csr_enable_w(i),
      csr_source_imm_o  => csr_source_imm_w(i),
      csr_maskop_o      => csr_maskop_w(i),
      csr_clearop_o     => csr_clearop_w(i)
    );
  end generate;

  corr_imem_req_w        <= (       imem_req_w(2) and        imem_req_w(1)) or (       imem_req_w(2) and        imem_req_w(0)) or (       imem_req_w(1) and        imem_req_w(0));
  corr_dmem_req_w        <= (       dmem_req_w(2) and        dmem_req_w(1)) or (       dmem_req_w(2) and        dmem_req_w(0)) or (       dmem_req_w(1) and        dmem_req_w(0));
  corr_update_pc_w       <= (      update_pc_w(2) and       update_pc_w(1)) or (      update_pc_w(2) and       update_pc_w(0)) or (      update_pc_w(1) and       update_pc_w(0));
  corr_trap_w            <= (           trap_w(2) and            trap_w(1)) or (           trap_w(2) and            trap_w(0)) or (           trap_w(1) and            trap_w(0));
  corr_aluop_w           <= (          aluop_w(2) and           aluop_w(1)) or (          aluop_w(2) and           aluop_w(0)) or (          aluop_w(1) and           aluop_w(0));
  corr_alusrc_imm_w      <= (     alusrc_imm_w(2) and      alusrc_imm_w(1)) or (     alusrc_imm_w(2) and      alusrc_imm_w(0)) or (     alusrc_imm_w(1) and      alusrc_imm_w(0));
  corr_imm_shamt_w       <= (      imm_shamt_w(2) and       imm_shamt_w(1)) or (      imm_shamt_w(2) and       imm_shamt_w(0)) or (      imm_shamt_w(1) and       imm_shamt_w(0));
  corr_imm_up_w          <= (         imm_up_w(2) and          imm_up_w(1)) or (         imm_up_w(2) and          imm_up_w(0)) or (         imm_up_w(1) and          imm_up_w(0));
  corr_regwr_w           <= (          regwr_w(2) and           regwr_w(1)) or (          regwr_w(2) and           regwr_w(0)) or (          regwr_w(1) and           regwr_w(0));
  corr_inv_branch_w      <= (     inv_branch_w(2) and      inv_branch_w(1)) or (     inv_branch_w(2) and      inv_branch_w(0)) or (     inv_branch_w(1) and      inv_branch_w(0));
  corr_branch_w          <= (         branch_w(2) and          branch_w(1)) or (         branch_w(2) and          branch_w(0)) or (         branch_w(1) and          branch_w(0));
  corr_jump_w            <= (           jump_w(2) and            jump_w(1)) or (           jump_w(2) and            jump_w(0)) or (           jump_w(1) and            jump_w(0));
  corr_jalr_w            <= (           jalr_w(2) and            jalr_w(1)) or (           jalr_w(2) and            jalr_w(0)) or (           jalr_w(1) and            jalr_w(0));
  corr_ecall_w           <= (          ecall_w(2) and           ecall_w(1)) or (          ecall_w(2) and           ecall_w(0)) or (          ecall_w(1) and           ecall_w(0));
  corr_memrd_w           <= (          memrd_w(2) and           memrd_w(1)) or (          memrd_w(2) and           memrd_w(0)) or (          memrd_w(1) and           memrd_w(0));
  corr_memwr_w           <= (          memwr_w(2) and           memwr_w(1)) or (          memwr_w(2) and           memwr_w(0)) or (          memwr_w(1) and           memwr_w(0));
  corr_byte_en_w         <= (        byte_en_w(2) and         byte_en_w(1)) or (        byte_en_w(2) and         byte_en_w(0)) or (        byte_en_w(1) and         byte_en_w(0));
  corr_mem_usgn_w        <= (       mem_usgn_w(2) and        mem_usgn_w(1)) or (       mem_usgn_w(2) and        mem_usgn_w(0)) or (       mem_usgn_w(1) and        mem_usgn_w(0));
  corr_load_upimm_w      <= (     load_upimm_w(2) and      load_upimm_w(1)) or (     load_upimm_w(2) and      load_upimm_w(0)) or (     load_upimm_w(1) and      load_upimm_w(0));
  corr_auipc_w           <= (          auipc_w(2) and           auipc_w(1)) or (          auipc_w(2) and           auipc_w(0)) or (          auipc_w(1) and           auipc_w(0));
  corr_csr_enable_w      <= (     csr_enable_w(2) and      csr_enable_w(1)) or (     csr_enable_w(2) and      csr_enable_w(0)) or (     csr_enable_w(1) and      csr_enable_w(0));
  corr_csr_source_imm_w  <= ( csr_source_imm_w(2) and  csr_source_imm_w(1)) or ( csr_source_imm_w(2) and  csr_source_imm_w(0)) or ( csr_source_imm_w(1) and  csr_source_imm_w(0));
  corr_csr_maskop_w      <= (     csr_maskop_w(2) and      csr_maskop_w(1)) or (     csr_maskop_w(2) and      csr_maskop_w(0)) or (     csr_maskop_w(1) and      csr_maskop_w(0));
  corr_csr_clearop_w     <= (    csr_clearop_w(2) and     csr_clearop_w(1)) or (    csr_clearop_w(2) and     csr_clearop_w(0)) or (    csr_clearop_w(1) and     csr_clearop_w(0));

  error_imem_req_w        <= (       imem_req_w(2) xor       imem_req_w(1)) or (       imem_req_w(2) xor       imem_req_w(0)) or (       imem_req_w(1) xor        imem_req_w(0));
  error_dmem_req_w        <= (       dmem_req_w(2) xor       dmem_req_w(1)) or (       dmem_req_w(2) xor       dmem_req_w(0)) or (       dmem_req_w(1) xor        dmem_req_w(0));
  error_update_pc_w       <= (      update_pc_w(2) xor      update_pc_w(1)) or (      update_pc_w(2) xor      update_pc_w(0)) or (      update_pc_w(1) xor       update_pc_w(0));
  error_trap_w            <= (           trap_w(2) xor           trap_w(1)) or (           trap_w(2) xor           trap_w(0)) or (           trap_w(1) xor            trap_w(0));
  error_aluop_w           <= or_reduce((          aluop_w(2) xor          aluop_w(1)) or (          aluop_w(2) xor          aluop_w(0)) or (          aluop_w(1) xor           aluop_w(0)));
  error_alusrc_imm_w      <= (     alusrc_imm_w(2) xor     alusrc_imm_w(1)) or (     alusrc_imm_w(2) xor     alusrc_imm_w(0)) or (     alusrc_imm_w(1) xor      alusrc_imm_w(0));
  error_imm_shamt_w       <= (      imm_shamt_w(2) xor      imm_shamt_w(1)) or (      imm_shamt_w(2) xor      imm_shamt_w(0)) or (      imm_shamt_w(1) xor       imm_shamt_w(0));
  error_imm_up_w          <= (         imm_up_w(2) xor         imm_up_w(1)) or (         imm_up_w(2) xor         imm_up_w(0)) or (         imm_up_w(1) xor          imm_up_w(0));
  error_regwr_w           <= (          regwr_w(2) xor          regwr_w(1)) or (          regwr_w(2) xor          regwr_w(0)) or (          regwr_w(1) xor           regwr_w(0));
  error_inv_branch_w      <= (     inv_branch_w(2) xor     inv_branch_w(1)) or (     inv_branch_w(2) xor     inv_branch_w(0)) or (     inv_branch_w(1) xor      inv_branch_w(0));
  error_branch_w          <= (         branch_w(2) xor         branch_w(1)) or (         branch_w(2) xor         branch_w(0)) or (         branch_w(1) xor          branch_w(0));
  error_jump_w            <= (           jump_w(2) xor           jump_w(1)) or (           jump_w(2) xor           jump_w(0)) or (           jump_w(1) xor            jump_w(0));
  error_jalr_w            <= (           jalr_w(2) xor           jalr_w(1)) or (           jalr_w(2) xor           jalr_w(0)) or (           jalr_w(1) xor            jalr_w(0));
  error_ecall_w           <= (          ecall_w(2) xor          ecall_w(1)) or (          ecall_w(2) xor          ecall_w(0)) or (          ecall_w(1) xor           ecall_w(0));
  error_memrd_w           <= (          memrd_w(2) xor          memrd_w(1)) or (          memrd_w(2) xor          memrd_w(0)) or (          memrd_w(1) xor           memrd_w(0));
  error_memwr_w           <= (          memwr_w(2) xor          memwr_w(1)) or (          memwr_w(2) xor          memwr_w(0)) or (          memwr_w(1) xor           memwr_w(0));
  error_byte_en_w         <= or_reduce((        byte_en_w(2) xor        byte_en_w(1)) or (        byte_en_w(2) xor        byte_en_w(0)) or (        byte_en_w(1) xor         byte_en_w(0)));
  error_mem_usgn_w        <= (       mem_usgn_w(2) xor       mem_usgn_w(1)) or (       mem_usgn_w(2) xor       mem_usgn_w(0)) or (       mem_usgn_w(1) xor        mem_usgn_w(0));
  error_load_upimm_w      <= (     load_upimm_w(2) xor     load_upimm_w(1)) or (     load_upimm_w(2) xor     load_upimm_w(0)) or (     load_upimm_w(1) xor      load_upimm_w(0));
  error_auipc_w           <= (          auipc_w(2) xor          auipc_w(1)) or (          auipc_w(2) xor          auipc_w(0)) or (          auipc_w(1) xor           auipc_w(0));
  error_csr_enable_w      <= (     csr_enable_w(2) xor     csr_enable_w(1)) or (     csr_enable_w(2) xor     csr_enable_w(0)) or (     csr_enable_w(1) xor      csr_enable_w(0));
  error_csr_source_imm_w  <= ( csr_source_imm_w(2) xor csr_source_imm_w(1)) or ( csr_source_imm_w(2) xor csr_source_imm_w(0)) or ( csr_source_imm_w(1) xor  csr_source_imm_w(0));
  error_csr_maskop_w      <= (     csr_maskop_w(2) xor     csr_maskop_w(1)) or (     csr_maskop_w(2) xor     csr_maskop_w(0)) or (     csr_maskop_w(1) xor      csr_maskop_w(0));
  error_csr_clearop_w     <= (    csr_clearop_w(2) xor    csr_clearop_w(1)) or (    csr_clearop_w(2) xor    csr_clearop_w(0)) or (    csr_clearop_w(1) xor     csr_clearop_w(0));


  error_o <= error_imem_req_w       or error_dmem_req_w   or error_update_pc_w      or
             error_trap_w           or error_aluop_w      or error_alusrc_imm_w     or
             error_imm_shamt_w      or error_imm_up_w     or error_regwr_w          or
             error_inv_branch_w     or error_branch_w     or error_jump_w           or
             error_jalr_w           or error_ecall_w      or error_memrd_w          or
             error_memwr_w          or error_byte_en_w    or error_mem_usgn_w       or
             error_load_upimm_w     or error_auipc_w      or error_csr_enable_w     or
             error_csr_source_imm_w or error_csr_maskop_w or error_csr_clearop_w;


  imem_req_o       <= corr_imem_req_w       when correct_error_i = '1' else imem_req_w      (0);
  dmem_req_o       <= corr_dmem_req_w       when correct_error_i = '1' else dmem_req_w      (0);
  update_pc_o      <= corr_update_pc_w      when correct_error_i = '1' else update_pc_w     (0);
  trap_o           <= corr_trap_w           when correct_error_i = '1' else trap_w          (0);
  aluop_o          <= corr_aluop_w          when correct_error_i = '1' else aluop_w         (0);
  alusrc_imm_o     <= corr_alusrc_imm_w     when correct_error_i = '1' else alusrc_imm_w    (0);
  imm_shamt_o      <= corr_imm_shamt_w      when correct_error_i = '1' else imm_shamt_w     (0);
  imm_up_o         <= corr_imm_up_w         when correct_error_i = '1' else imm_up_w        (0);
  regwr_o          <= corr_regwr_w          when correct_error_i = '1' else regwr_w         (0);
  inv_branch_o     <= corr_inv_branch_w     when correct_error_i = '1' else inv_branch_w    (0);
  branch_o         <= corr_branch_w         when correct_error_i = '1' else branch_w        (0);
  jump_o           <= corr_jump_w           when correct_error_i = '1' else jump_w          (0);
  jalr_o           <= corr_jalr_w           when correct_error_i = '1' else jalr_w          (0);
  ecall_o          <= corr_ecall_w          when correct_error_i = '1' else ecall_w         (0);
  memrd_o          <= corr_memrd_w          when correct_error_i = '1' else memrd_w         (0);
  memwr_o          <= corr_memwr_w          when correct_error_i = '1' else memwr_w         (0);
  byte_en_o        <= corr_byte_en_w        when correct_error_i = '1' else byte_en_w       (0);
  mem_usgn_o       <= corr_mem_usgn_w       when correct_error_i = '1' else mem_usgn_w      (0);
  load_upimm_o     <= corr_load_upimm_w     when correct_error_i = '1' else load_upimm_w    (0);
  auipc_o          <= corr_auipc_w          when correct_error_i = '1' else auipc_w         (0);
  csr_enable_o     <= corr_csr_enable_w     when correct_error_i = '1' else csr_enable_w    (0);
  csr_source_imm_o <= corr_csr_source_imm_w when correct_error_i = '1' else csr_source_imm_w(0);
  csr_maskop_o     <= corr_csr_maskop_w     when correct_error_i = '1' else csr_maskop_w    (0);
  csr_clearop_o    <= corr_csr_clearop_w    when correct_error_i = '1' else csr_clearop_w   (0);

end architecture;
