library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;
use ieee.numeric_std.all;

entity csr is
  generic (
    TMR_CONTROL           : boolean;
    TMR_ALU               : boolean;
    HAMMING_REGFILE       : boolean;
    HAMMING_PC            : boolean
  );
  port (
    -- sync
    rstn_i : in std_logic;
    clk_i  : in std_logic;
    -- access interface
    addr_i     : in std_logic_vector(11 downto 0);
    data_o     : out std_logic_vector(31 downto 0);
    rs1_data_i : in std_logic_vector(31 downto 0);
    imm_data_i : in std_logic_vector(4 downto 0);
    -- write control
    wren_i        : in std_logic;
    source_imm_i  : in std_logic;
    csr_maskop_i  : in std_logic;
    csr_clearop_i : in std_logic;
    -- trap handling
    trap_i     : in std_logic;
    uscratch_i : in std_logic_vector(31 downto 0);
    uepc_i     : in std_logic_vector(31 downto 0);
    ucause_i   : in std_logic_vector(31 downto 0);
    utval_i    : in std_logic_vector(31 downto 0);
    uip_i      : in std_logic_vector(31 downto 0);
    -- error counter inputs
    reg1_cen_i    : in std_logic;
    reg1_sbu_i    : in std_logic;
    reg1_dbu_i    : in std_logic;
    reg2_cen_i    : in std_logic;
    reg2_sbu_i    : in std_logic;
    reg2_dbu_i    : in std_logic;
    pc_cen_i      : in std_logic;
    pc_sbu_i      : in std_logic;
    pc_dbu_i      : in std_logic;
    dmem_cen_i    : in std_logic;
    dmem_sbu_i    : in std_logic;
    dmem_dbu_i    : in std_logic;
    control_cen_i : in std_logic;
    control_err_i : in std_logic;
    alu_cen_i     : in std_logic;
    alu_err_i     : in std_logic;
    -- hardening configuration outputs
    hard_pc_o      : out std_logic;
    hard_regfile_o : out std_logic;
    hard_dmem_o    : out std_logic;
    hard_control_o : out std_logic;
    hard_alu_o     : out std_logic;
    -- reset cause input
    poweron_rstn_i : in std_logic;
    wdt_rstn_i     : in std_logic
  );
end entity;

architecture arch of csr is
  -- USER: Counter/Timers
  constant CYCLE_ADDR    : std_logic_vector(11 downto 0) := x"C00";
  constant TIME_ADDR     : std_logic_vector(11 downto 0) := x"C01";
  constant INSTRET_ADDR  : std_logic_vector(11 downto 0) := x"C02";
  constant CYCLEH_ADDR   : std_logic_vector(11 downto 0) := x"C80";
  constant TIMEH_ADDR    : std_logic_vector(11 downto 0) := x"C81";
  constant INSTRETH_ADDR : std_logic_vector(11 downto 0) := x"C82";
  -- USER: trap handling
  constant USCRATCH_ADDR : std_logic_vector(11 downto 0) := x"040";
  constant UEPC_ADDR     : std_logic_vector(11 downto 0) := x"041";
  constant UCAUSE_ADDR   : std_logic_vector(11 downto 0) := x"042";
  constant UTVAL_ADDR    : std_logic_vector(11 downto 0) := x"043";
  constant UIP_ADDR      : std_logic_vector(11 downto 0) := x"044";
  -- MACHINE: custom  error counter registers
  constant REG1_SBU_ADDR    : std_logic_vector(11 downto 0) := x"7C0";
  constant REG1_DBU_ADDR    : std_logic_vector(11 downto 0) := x"7C1";
  constant REG2_SBU_ADDR    : std_logic_vector(11 downto 0) := x"7C2";
  constant REG2_DBU_ADDR    : std_logic_vector(11 downto 0) := x"7C3";
  constant PC_SBU_ADDR      : std_logic_vector(11 downto 0) := x"7C4";
  constant PC_DBU_ADDR      : std_logic_vector(11 downto 0) := x"7C5";
  constant DMEM_SBU_ADDR    : std_logic_vector(11 downto 0) := x"7C6";
  constant DMEM_DBU_ADDR    : std_logic_vector(11 downto 0) := x"7C7";
  constant CONTROL_ERR_ADDR : std_logic_vector(11 downto 0) := x"7C8";
  constant ALU_ERR_ADDR     : std_logic_vector(11 downto 0) := x"7C9";
  -- MACHINE: hardening configuration
  constant HARDEN_CONF_ADDR : std_logic_vector(11 downto 0) := x"BC0";
  -- MACHINE: information
  constant MVENDORID_ADDR : std_logic_vector(11 downto 0) := x"F11";
  constant MARCHID_ADDR   : std_logic_vector(11 downto 0) := x"F12";
  constant MIMPID_ADDR    : std_logic_vector(11 downto 0) := x"F13";
  constant MHARTID_ADDR   : std_logic_vector(11 downto 0) := x"F14";
  -- MACHINE: reset cause
  constant RSTCAUSE_ADDR : std_logic_vector(11 downto 0) := x"FC0";

  -- Registers from unprivileged specification -- except float CSR
  signal cycle_r    : std_logic_vector(31 downto 0); -- read by RDCYCLE
  signal time_r     : std_logic_vector(31 downto 0); -- read by RDTIME
  signal instret_r  : std_logic_vector(31 downto 0); -- read by RDINSTRET
  signal cycleh_r   : std_logic_vector(31 downto 0); -- read by RDCYCLEH
  signal timeh_r    : std_logic_vector(31 downto 0); -- read by RDTIMEH
  signal instreth_r : std_logic_vector(31 downto 0); -- read by RDINSTRETH

  -- Registers for trap handling
  signal uscratch_r : std_logic_vector(31 downto 0); --at 0x040
  signal uepc_r     : std_logic_vector(31 downto 0); --at 0x041
  signal ucause_r   : std_logic_vector(31 downto 0); --at 0x042
  signal utval_r    : std_logic_vector(31 downto 0); --at 0x043
  signal uip_r      : std_logic_vector(31 downto 0); --at 0x044

  -- Registers for error counting
  signal reg1_sbu_r  : std_logic_vector(31 downto 0); -- at 0x7C0
  signal reg1_dbu_r  : std_logic_vector(31 downto 0); -- at 0x7C1

  signal reg2_sbu_r  : std_logic_vector(31 downto 0); -- at 0x7C2
  signal reg2_dbu_r  : std_logic_vector(31 downto 0); -- at 0x7C3

  signal pc_sbu_r  : std_logic_vector(31 downto 0); -- at 0x7C4
  signal pc_dbu_r  : std_logic_vector(31 downto 0); -- at 0x7C5

  signal dmem_sbu_r  : std_logic_vector(31 downto 0); -- at 0x7C6
  signal dmem_dbu_r  : std_logic_vector(31 downto 0); -- at 0x7C7

  signal control_err_r : std_logic_vector(31 downto 0); -- at 0x7C8
  signal alu_err_r     : std_logic_vector(31 downto 0); -- at 0x7C9

  -- Register for hardening flags
  signal harden_conf_r : std_logic_vector(31 downto 0); -- at 0xBC0

  -- Registers for information registers
  signal mvendorid_r : std_logic_vector(31 downto 0);
  signal marchid_r   : std_logic_vector(31 downto 0);
  signal mimpid_r    : std_logic_vector(31 downto 0);
  signal mhartid_r   : std_logic_vector(31 downto 0);

  -- Register for reset cause
  signal rstcause_r : std_logic_vector(31 downto 0);

  -- write and read signals
  signal wdata_w : std_logic_vector(31 downto 0);
  signal rdata_w : std_logic_vector(31 downto 0);

  -- auxiliar signals
  signal mask_w         : std_logic_vector(31 downto 0);
  signal cleared_data_w : std_logic_vector(31 downto 0);
  signal setted_data_w  : std_logic_vector(31 downto 0);
  signal maskop_res_w   : std_logic_vector(31 downto 0);

begin

  rdata_w <= cycle_r    when addr_i = CYCLE_ADDR    else
             time_r     when addr_i = TIME_ADDR     else
             instret_r  when addr_i = INSTRET_ADDR  else
             cycleh_r   when addr_i = CYCLEH_ADDR   else
             timeh_r    when addr_i = TIMEH_ADDR    else
             instreth_r when addr_i = INSTRETH_ADDR else
             -- USER TRAP
             uscratch_r when addr_i = USCRATCH_ADDR else
             uepc_r     when addr_i = UEPC_ADDR     else
             ucause_r   when addr_i = UCAUSE_ADDR   else
             utval_r    when addr_i = UTVAL_ADDR    else
             uip_r      when addr_i = UIP_ADDR      else
             -- MACHINE INFORMATION
             mvendorid_r when addr_i = MVENDORID_ADDR else
             marchid_r   when addr_i = MARCHID_ADDR   else
             mimpid_r    when addr_i = MIMPID_ADDR    else
             mhartid_r   when addr_i = MHARTID_ADDR   else
             -- MACHINE HARDENING CONFIGURATION
             harden_conf_r when addr_i = HARDEN_CONF_ADDR else
             -- MACHINE RSTCAUSE
             rstcause_r when addr_i = RSTCAUSE_ADDR else
             -- CUSTOM ERROR
             reg1_sbu_r    when addr_i = REG1_SBU_ADDR    else
             reg1_dbu_r    when addr_i = REG1_DBU_ADDR    else
             reg2_sbu_r    when addr_i = REG2_SBU_ADDR    else
             reg2_dbu_r    when addr_i = REG2_DBU_ADDR    else
             pc_sbu_r      when addr_i = PC_SBU_ADDR      else
             pc_dbu_r      when addr_i = PC_DBU_ADDR      else
             dmem_sbu_r    when addr_i = DMEM_SBU_ADDR    else
             dmem_dbu_r    when addr_i = DMEM_DBU_ADDR    else
             control_err_r when addr_i = CONTROL_ERR_ADDR else
             alu_err_r     when addr_i = ALU_ERR_ADDR     else
             x"deadbeef";
  data_o  <= rdata_w;

  -- define data to be written
  mask_w <= ((31 downto 5 => '0') & imm_data_i) when source_imm_i = '1' else rs1_data_i;

  cleared_data_w <= rdata_w and (not mask_w);
  setted_data_w  <= rdata_w or mask_w;

  maskop_res_w <= cleared_data_w when csr_clearop_i = '1' else setted_data_w;

  -- select data that will be written
  wdata_w <= maskop_res_w when csr_maskop_i = '1' else rs1_data_i;


  --------------------------------------------------------------------------------------
  --------------------------------------- CSRs -----------------------------------------
  --------------------------------------------------------------------------------------

  p_CYCLE_COUNT : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      cycle_r  <= (others => '0');
      cycleh_r <= (others => '0');
    elsif rising_edge(clk_i) then
      -- increment cycle
      cycle_r <= std_logic_vector(unsigned(cycle_r) + 1);
      -- in case of cycle_r overflow, increase cycleh_r
      if cycle_r = x"FFFFFFFF" then
        cycleh_r <= std_logic_vector(unsigned(cycleh_r) + 1);
      end if;
    end if;
  end process;

  p_TIME_COUNT : process(clk_i, rstn_i)
  begin
    if rstn_i = '0' then
      time_r  <= (others => '0');
      timeh_r <= (others => '0');
    elsif rising_edge(clk_i) then
      -- increment time
      time_r <= std_logic_vector(unsigned(time_r) + 1);
      -- in case of time_r overflow, increase timeh_r
      if time_r = x"FFFFFFFF" then
        timeh_r <= std_logic_vector(unsigned(timeh_r) + 1);
      end if;
    end if;
  end process;

  p_TRAP_REGISTERS : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if trap_i = '1' then
        uscratch_r <= uscratch_i;
        uepc_r     <= uepc_i;
        ucause_r   <= ucause_i;
        utval_r    <= utval_i;
        uip_r      <= uip_i;
      end if;
    end if;
  end process;

  -- information registers
  mvendorid_r <= x"CAFECAFE";
  marchid_r   <= x"000000CA";
  mimpid_r(31 downto 6) <= (others => '0');
  mimpid_r( 3 downto 2) <= (others => '0');
  mimpid_r(0) <= '1' when HAMMING_PC      else '0';
  mimpid_r(1) <= '1' when HAMMING_REGFILE else '0';
  mimpid_r(4) <= '1' when TMR_CONTROL     else '0';
  mimpid_r(5) <= '1' when TMR_ALU         else '0';
  mhartid_r   <= x"00000000";

  p_RSTCAUSE : process(poweron_rstn_i, wdt_rstn_i)
  begin
    if poweron_rstn_i = '0' then
      rstcause_r <= x"00000001";
    elsif wdt_rstn_i = '0' then
      rstcause_r <= x"00000002";
    end if;
  end process;

  p_HARDENING : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if wren_i = '1' and addr_i = HARDEN_CONF_ADDR then
        harden_conf_r <= wdata_w;
      end if;
    end if;
  end process;
  -- Hamming
  hard_pc_o      <= harden_conf_r(0);
  hard_regfile_o <= harden_conf_r(1);
  hard_dmem_o    <= harden_conf_r(2);
  -- TMR
  hard_control_o <= harden_conf_r(4);
  hard_alu_o     <= harden_conf_r(5);

  p_ERROR_COUNT : process(clk_i)
  begin
    if rising_edge(clk_i) then

      -- Register file upsets
      if wren_i = '1' and addr_i = REG1_SBU_ADDR then
        reg1_sbu_r <= wdata_w;
      elsif reg1_cen_i = '1' and reg1_sbu_i = '1' then
        reg1_sbu_r <= std_logic_vector(unsigned(reg1_sbu_r)+1);
      end if;

      if wren_i = '1' and addr_i = REG1_DBU_ADDR then
        reg1_dbu_r <= wdata_w;
      elsif reg1_cen_i = '1' and reg1_dbu_i = '1' then
        reg1_dbu_r <= std_logic_vector(unsigned(reg1_dbu_r)+1);
      end if;

      -- Register file upsets
      if wren_i = '1' and addr_i = REG2_SBU_ADDR then
        reg2_sbu_r <= wdata_w;
      elsif reg2_cen_i = '1' and reg2_sbu_i = '1' then
        reg2_sbu_r <= std_logic_vector(unsigned(reg2_sbu_r)+1);
      end if;

      if wren_i = '1' and addr_i = REG2_DBU_ADDR then
        reg2_dbu_r <= wdata_w;
      elsif reg2_cen_i = '1' and reg2_dbu_i = '1' then
        reg2_dbu_r <= std_logic_vector(unsigned(reg2_dbu_r)+1);
      end if;

      -- PC upsets
      if wren_i = '1' and addr_i = PC_SBU_ADDR then
        pc_sbu_r <= wdata_w;
      elsif pc_cen_i = '1' and pc_sbu_i = '1' then
        pc_sbu_r <= std_logic_vector(unsigned(pc_sbu_r)+1);
      end if;

      if wren_i = '1' and addr_i = PC_DBU_ADDR then
        pc_dbu_r <= wdata_w;
      elsif pc_cen_i = '1' and pc_dbu_i = '1' then
        pc_dbu_r <= std_logic_vector(unsigned(pc_dbu_r)+1);
      end if;

      -- Data memory upsets
      if wren_i = '1' and addr_i = DMEM_SBU_ADDR then
        dmem_sbu_r <= wdata_w;
      elsif dmem_cen_i = '1' and dmem_sbu_i = '1' then
        dmem_sbu_r <= std_logic_vector(unsigned(dmem_sbu_r)+1);
      end if;

      if wren_i = '1' and addr_i = DMEM_DBU_ADDR then
        dmem_dbu_r <= wdata_w;
      elsif dmem_cen_i = '1' and dmem_dbu_i = '1' then
        dmem_dbu_r <= std_logic_vector(unsigned(dmem_dbu_r)+1);
      end if;

      -- CONTROL errors
      if wren_i = '1' and addr_i = CONTROL_ERR_ADDR then
        control_err_r <= wdata_w;
      elsif control_cen_i = '1' and control_err_i = '1' then
        control_err_r <= std_logic_vector(unsigned(control_err_r)+1);
      end if;

      -- ALU errors
      if wren_i = '1' and addr_i = ALU_ERR_ADDR then
        alu_err_r <= wdata_w;
      elsif alu_cen_i = '1' and alu_err_i = '1' then
        alu_err_r <= std_logic_vector(unsigned(alu_err_r)+1);
      end if;

    end if;
  end process;

end architecture;
