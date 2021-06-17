library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.hamming_pkg.hamming_register;

entity instr_fetch is
  generic (
    PROGRAM_START_ADDR : std_logic_vector(31 downto 0);
    TRAP_HANDLER_ADDR  : std_logic_vector(31 downto 0);
    HAMMING_PC         : boolean
  );
  port (
    -- input ports
    branch_imm_i : in std_logic_vector(12 downto 0);
    jump_imm_i   : in std_logic_vector(31 downto 0);
    inv_branch_i : in std_logic;
    branch_i     : in std_logic;
    zero_i       : in std_logic;
    jump_i       : in std_logic;
    ecall_i      : in std_logic;
    correct_error_i : in std_logic;
    -- instruction data
    instr_gnt_i : in std_logic;
    instr_i     : in std_logic_vector(31 downto 0);
    -- sync
    rstn_i      : in std_logic;
    clk_i       : in std_logic;
    update_pc_i : in std_logic;
    trap_i      : in std_logic;
    -- output ports
    instr_o : out std_logic_vector(31 downto 0);
    sbu_o   : out std_logic;
    dbu_o   : out std_logic;
    pc_o    : out std_logic_vector(31 downto 0);
    pc_4_o  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of instr_fetch is
  signal pc_par_w   : std_logic_vector(31 downto 0);
  signal pc_adder_w : std_logic_vector(31 downto 0);
  signal next_pc_w  : std_logic_vector(31 downto 0);
  signal pc_w       : std_logic_vector(31 downto 0);
begin
  -- calculate (PC + 4) or (PC + branch_eq)
  pc_par_w   <= std_logic_vector(resize(signed(branch_imm_i), 32)) when (branch_i and (zero_i xor inv_branch_i)) = '1' else x"00000004";
  pc_adder_w <= std_logic_vector(signed(pc_w) + signed(pc_par_w));
  pc_4_o     <= pc_adder_w;

  -- define the next PC address
  next_pc_w <= TRAP_HANDLER_ADDR when trap_i = '1' else
               jump_imm_i        when jump_i = '1' else
               pc_adder_w;
  -- set PC output
  pc_o <= pc_w;

  register_pc_i : hamming_register
  generic map (
    HAMMING_ENABLE => HAMMING_PC,
    RESET_VALUE    => PROGRAM_START_ADDR
  )
  port map (
    correct_en_i => correct_error_i,
    write_en_i   => update_pc_i,
    data_i       => next_pc_w,
    rstn_i       => rstn_i,
    clk_i        => clk_i,
    single_err_o => sbu_o,
    double_err_o => dbu_o,
    data_o       => pc_w
  );

  register_instr_i : hamming_register
  generic map (
    HAMMING_ENABLE => HAMMING_PC,
    RESET_VALUE    => (31 downto 0 => '0')
  )
  port map (
    correct_en_i => correct_error_i,
    write_en_i   => instr_gnt_i,
    data_i       => instr_i,
    rstn_i       => rstn_i,
    clk_i        => clk_i,
    single_err_o => open,
    double_err_o => open,
    data_o       => instr_o
  );

end architecture;
