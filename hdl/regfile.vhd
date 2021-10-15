library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.hamming_pkg.all;

entity regfile is
  generic (
    HAMMING_ENABLE : boolean
  );
  port (
    -- input ports
    data_i       : in std_logic_vector(31 downto 0);
    wren_i       : in std_logic;
    rd_i         : in std_logic_vector(4 downto 0);
    rs1_i        : in std_logic_vector(4 downto 0);
    rs2_i        : in std_logic_vector(4 downto 0);
    correct_en_i : in std_logic;
    -- synchronization
    clk_i : in std_logic;
    -- output ports
    sbu1_o  : out std_logic;
    dbu1_o  : out std_logic;
    data1_o : out std_logic_vector(31 downto 0);
    sbu2_o  : out std_logic;
    dbu2_o  : out std_logic;
    data2_o : out std_logic_vector(31 downto 0)
  );
end entity;

architecture arch of regfile is
begin

  -----------------------------------------------------------------------------------------------
  ------------------------------------- HAMMING DISABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------

  g_NORMAL : if not HAMMING_ENABLE generate
    type regfile_t is array(natural range <>) of std_logic_vector(31 downto 0);
    signal regfile_r : regfile_t(31 downto 1);
    signal regfile_w : regfile_t(31 downto 0);

    signal rs1_w : std_logic_vector(4 downto 0);
    signal rs2_w : std_logic_vector(4 downto 0);
  begin
    -- WRITE REGISTERS
    p_WR : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if wren_i = '1' and rd_i /= "00000" and rd_i /= "UUUUU" then
          regfile_r(to_integer(unsigned(rd_i))) <= data_i;
        end if;
      end if;
    end process;

    regfile_w(31 downto 1) <= regfile_r;
    regfile_w(0) <= (others => '0');

    -- READ REGISTERS
    sbu1_o  <= '0';
    dbu1_o  <= '0';
    data1_o <= regfile_w(to_integer(unsigned(rs1_i)));

    sbu2_o  <= '0';
    dbu2_o  <= '0';
    data2_o <= regfile_w(to_integer(unsigned(rs2_i)));
  end generate;

  -----------------------------------------------------------------------------------------------
  -------------------------------------- HAMMING ENABLED ----------------------------------------
  -----------------------------------------------------------------------------------------------

  g_HAMMING : if HAMMING_ENABLE generate
    constant DETECT_DOUBLE : boolean := TRUE;
    constant PARITY_BITS_QT : integer := get_ecc_size(32, DETECT_DOUBLE);
    type regfile_hamming_t is array(natural range <>) of std_logic_vector(31+PARITY_BITS_QT downto 0);

    signal regfile_r : regfile_hamming_t(31 downto 1);
    signal regfile_w : regfile_hamming_t(31 downto 0);

    signal data_wr_enc_w : std_logic_vector(PARITY_BITS_QT+31 downto 0);
    signal data_s1_enc_w : std_logic_vector(PARITY_BITS_QT+31 downto 0);
    signal data_s2_enc_w : std_logic_vector(PARITY_BITS_QT+31 downto 0);
  begin
    hamming_encoder_u : hamming_encoder
     generic map (
       DATA_SIZE     => 32,
       DETECT_DOUBLE => DETECT_DOUBLE
     )
     port map (
       data_i    => data_i,
       encoded_o => data_wr_enc_w
     );

    -- WRITE REGISTER
    p_WR : process(clk_i, wren_i)
    begin
      if rising_edge(clk_i) then
        if wren_i = '1' and rd_i /= "00000" then
          regfile_r(to_integer(unsigned(rd_i))) <= data_wr_enc_w;
        end if;
      end if;
    end process;

    -- READ REGISTERS
    regfile_w(31 downto 1) <= regfile_r;
    regfile_w(0)           <= (others => '0');

    data_s1_enc_w <= regfile_w(to_integer(unsigned(rs1_i)));
    data_s2_enc_w <= regfile_w(to_integer(unsigned(rs2_i)));

    hamming_decoder_data1_u : hamming_decoder
     generic map (
       DATA_SIZE     => 32,
       DETECT_DOUBLE => DETECT_DOUBLE
     )
     port map (
       encoded_i       => data_s1_enc_w,
       correct_error_i => correct_en_i,
       single_err_o    => sbu1_o,
       double_err_o    => dbu1_o,
       data_o          => data1_o
     );

     hamming_decoder_data2_u : hamming_decoder
     generic map (
       DATA_SIZE     => 32,
       DETECT_DOUBLE => DETECT_DOUBLE
     )
     port map (
       encoded_i       => data_s2_enc_w,
       correct_error_i => correct_en_i,
       single_err_o    => sbu2_o,
       double_err_o    => dbu2_o,
       data_o          => data2_o
     );
  end generate;


end architecture;
