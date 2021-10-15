library ieee;
use ieee.std_logic_1164.all;

library work;
use work.hamming_pkg.hamming_encoder;
use work.hamming_pkg.hamming_decoder;
use work.hamming_pkg.get_parity_data_result;
use work.hamming_pkg.get_ecc_size;

entity hamming_register is
  generic (
    HAMMING_ENABLE : boolean;
    RESET_VALUE    : std_logic_vector(31 downto 0) := x"00000000"
  );
  port (
    correct_en_i : in std_logic;
    write_en_i   : in std_logic;
    data_i       : in std_logic_vector(31 downto 0);
    rstn_i       : in std_logic;
    clk_i        : in std_logic;
    single_err_o : out std_logic;
    double_err_o : out std_logic;
    data_o       : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of hamming_register is
begin

  -----------------------------------------------------------------------------------------------
  ------------------------------------- HAMMING DISABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------

  g_NORMAL_REG : if not HAMMING_ENABLE generate
    signal reg_r : std_logic_vector(31 downto 0);
  begin
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg_r <= RESET_VALUE;
      elsif rising_edge(clk_i) then
        if write_en_i = '1' then
          reg_r <= data_i;
        end if;
      end if;
    end process;
    single_err_o <= '0';
    double_err_o <= '0';
    data_o       <= reg_r;
  end generate;

  -----------------------------------------------------------------------------------------------
  -------------------------------------- HAMMING ENABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------
  g_HAMMING_REG : if HAMMING_ENABLE generate
    constant DETECT_DOUBLE  : boolean := TRUE;
    constant REG_DATA_WIDTH : integer := 32 + get_ecc_size(32, DETECT_DOUBLE);
    constant RESET_VALUE_HAMMING : std_logic_vector(REG_DATA_WIDTH-1 downto 0) := get_parity_data_result(RESET_VALUE, DETECT_DOUBLE) & RESET_VALUE;
    signal enc_w : std_logic_vector(REG_DATA_WIDTH-1 downto 0);
    signal reg_r : std_logic_vector(REG_DATA_WIDTH-1 downto 0);
  begin

    -- encode next register data
    hamming_encoder_u : hamming_encoder
    generic map (
      DATA_SIZE     => 32,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      data_i    => data_i,
      encoded_o => enc_w
    );

    -- create register
    p_REG : process(clk_i, rstn_i)
    begin
      if rstn_i = '0' then
        reg_r <= RESET_VALUE_HAMMING;
      elsif rising_edge(clk_i) then
        if write_en_i = '1' then
          reg_r <= enc_w;
        end if;
      end if;
    end process;

    -- decode the data
    hamming_decoder_u : hamming_decoder
    generic map (
      DATA_SIZE     => 32,
      DETECT_DOUBLE => DETECT_DOUBLE
    )
    port map (
      encoded_i       => reg_r,
      correct_error_i => correct_en_i,
      single_err_o    => single_err_o,
      double_err_o    => double_err_o,
      data_o          => data_o
    );
  end generate;

end architecture;
