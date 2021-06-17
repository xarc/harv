library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.harv_pkg.all;

entity alu is
  port (
    -- input ports
    data1_i     : in std_logic_vector(31 downto 0);
    data2_i     : in std_logic_vector(31 downto 0);
    operation_i : in std_logic_vector(ALUOP_SIZE-1 downto 0);
    -- output ports
    zero_o  : out std_logic;
    data_o  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of alu is
  signal add_sub_data2_w : signed(31 downto 0);
  signal add_sub_w : std_logic_vector(31 downto 0);
  signal and_w     : std_logic_vector(31 downto 0);
  signal or_w      : std_logic_vector(31 downto 0);
  signal xor_w     : std_logic_vector(31 downto 0);
  signal sll_w     : std_logic_vector(31 downto 0);
  signal srl_w     : std_logic_vector(31 downto 0);
  signal sra_w     : std_logic_vector(31 downto 0);
  signal slt_w     : std_logic_vector(31 downto 0);
  signal sltu_w    : std_logic_vector(31 downto 0);
  signal result_w  : std_logic_vector(31 downto 0);
begin
  add_sub_data2_w <= signed(data2_i) when operation_i = ALU_ADD_OP else -signed(data2_i);
  add_sub_w <= std_logic_vector(signed(data1_i) + add_sub_data2_w);
  and_w   <= data1_i and data2_i;
  or_w    <= data1_i or  data2_i;
  xor_w   <= data1_i xor data2_i;
  sll_w   <= std_logic_vector(shift_left(unsigned(data1_i),  to_integer(unsigned(data2_i))));
  srl_w   <= std_logic_vector(shift_right(unsigned(data1_i), to_integer(unsigned(data2_i))));
  sra_w   <= std_logic_vector(shift_right(signed(data1_i),   to_integer(unsigned(data2_i))));
  slt_w   <= (0 => '1', others => '0') when signed(data1_i)   <   signed(data2_i) else (others => '0');
  sltu_w  <= (0 => '1', others => '0') when unsigned(data1_i) < unsigned(data2_i) else (others => '0');

  with operation_i select result_w <=
    add_sub_w       when ALU_ADD_OP,
    add_sub_w       when ALU_SUB_OP,
    sll_w           when ALU_SLL_OP,
    slt_w           when ALU_SLT_OP,
    sltu_w          when ALU_SLTU_OP,
    xor_w           when ALU_XOR_OP,
    srl_w           when ALU_SRL_OP,
    sra_w           when ALU_SRA_OP,
    or_w            when ALU_OR_OP,
    and_w           when ALU_AND_OP,
    (others => '0') when others;

  data_o <= result_w;
  zero_o <= '1' when result_w = (31 downto 0 => '0') else '0';
end architecture;
