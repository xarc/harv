library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.harv_pkg.all;

entity alu_tmr is
  port (
    -- input ports
    data1_i         : in std_logic_vector(31 downto 0);
    data2_i         : in std_logic_vector(31 downto 0);
    operation_i     : in std_logic_vector(ALUOP_SIZE-1 downto 0);
    correct_error_i : in std_logic;
    -- output ports
    error_o : out std_logic;
    zero_o  : out std_logic;
    data_o  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of alu_tmr is
  type tmr_std_logic_t is array(2 downto 0) of std_logic;
  signal zero_w : tmr_std_logic_t;
  signal corr_zero_w : std_logic;
  signal error_zero_w : std_logic;

  type tmr_data_t is array(2 downto 0) of std_logic_vector(31 downto 0);
  signal data_w : tmr_data_t;
  signal corr_data_w : std_logic_vector(31 downto 0);
  signal error_data_w : std_logic;

begin
  gen_TMR : for i in 2 downto 0 generate
    -- Xilinx attributes to prevent optimization of TMR
    attribute DONT_TOUCH : string;
    attribute DONT_TOUCH of alu_i : label is "TRUE";
    -- Synplify attributes to prevent optimization of TMR
    attribute syn_radhardlevel : string;
    attribute syn_keep         : boolean;
    attribute syn_safe_case    : boolean;
    attribute syn_noprune      : boolean;
    attribute syn_radhardlevel of alu_i : label is "tmr";
    attribute syn_keep         of alu_i : label is TRUE;
    attribute syn_safe_case    of alu_i : label is TRUE;
    attribute syn_noprune      of alu_i : label is TRUE;
  begin
    alu_i : alu
    port map (
      data1_i     => data1_i,
      data2_i     => data2_i,
      operation_i => operation_i,
      zero_o      => zero_w(i),
      data_o      => data_w(i)
    );
  end generate;

  corr_zero_w <= (zero_w(2) and zero_w(1)) or
                 (zero_w(2) and zero_w(0)) or
                 (zero_w(1) and zero_w(0));

  corr_data_w <= (data_w(2) and data_w(1)) or
                 (data_w(2) and data_w(0)) or
                 (data_w(1) and data_w(0));

  error_zero_w <= (zero_w(2) xor zero_w(1)) or
                  (zero_w(2) xor zero_w(0)) or
                  (zero_w(1) xor zero_w(0));

  error_data_w <= or_reduce((data_w(2) xor data_w(1)) or
                            (data_w(2) xor data_w(0)) or
                            (data_w(1) xor data_w(0)));

  error_o <= error_zero_w or error_data_w;

  zero_o <= corr_zero_w when correct_error_i = '1' else zero_w(0);
  data_o <= corr_data_w when correct_error_i = '1' else data_w(0);

end architecture;
