library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

library work;
use work.hamming_pkg.all;

entity hamming_encoder is
  generic (
    DATA_SIZE     : integer := 32; -- 64(7), 32(6), 16(5), 8(4), 4(3)
    DETECT_DOUBLE : boolean
  );
  port (
    data_i       : in std_logic_vector(DATA_SIZE-1 downto 0);
    encoded_o    : out std_logic_vector(DATA_SIZE+get_ecc_size(DATA_SIZE, DETECT_DOUBLE)-1 downto 0)
  );
end entity;

architecture arch of hamming_encoder is
  constant HAMM_PARITY_SIZE  : integer := get_ecc_size(DATA_SIZE, FALSE);
  constant TOTAL_PARITY_SIZE : integer := get_ecc_size(DATA_SIZE, DETECT_DOUBLE);
  signal parity_data_w : std_logic_vector(TOTAL_PARITY_SIZE-1 downto 0);
  signal encoded_w : std_logic_vector(DATA_SIZE+TOTAL_PARITY_SIZE-1 downto 0);
begin

  gen_ENCODE : for i in HAMM_PARITY_SIZE-1 downto 0 generate
    constant BITS_QT  : integer := get_parity_qt(DATA_SIZE, i);
    signal ecc_data_w : std_logic_vector(BITS_QT-1 downto 0);
  begin
    gen_DATA : for j in ecc_data_w'range generate
      ecc_data_w(j) <= data_i(PARITY_POS(i, j));
    end generate;
    parity_data_w(i) <= xor_reduce(ecc_data_w);
  end generate;

  gen_ADDITIONAL_PARITY : if DETECT_DOUBLE generate
    signal hamm_encoded_w : std_logic_vector(DATA_SIZE+HAMM_PARITY_SIZE-1 downto 0);
  begin
    hamm_encoded_w <= parity_data_w(HAMM_PARITY_SIZE-1 downto 0) & data_i;
    parity_data_w(TOTAL_PARITY_SIZE-1) <= xor_reduce(hamm_encoded_w);
  end generate;

  encoded_w <= parity_data_w & data_i;
  encoded_o <= encoded_w;
end architecture;
