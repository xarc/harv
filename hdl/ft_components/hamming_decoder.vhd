library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.hamming_pkg.all;

entity hamming_decoder is
  generic (
    DATA_SIZE     : integer := 32; -- 64(7), 32(6), 16(5), 8(4), 4(3)
    DETECT_DOUBLE : boolean
  );
  port (
    encoded_i       : in std_logic_vector(DATA_SIZE+get_ecc_size(DATA_SIZE, DETECT_DOUBLE)-1 downto 0);
    correct_error_i : in std_logic;
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;
    data_o          : out std_logic_vector(DATA_SIZE-1 downto 0)
  );
end entity;

architecture arch of hamming_decoder is
  constant HAMM_PARITY_SIZE  : integer := get_ecc_size(DATA_SIZE, FALSE);
  constant TOTAL_PARITY_SIZE : integer := get_ecc_size(DATA_SIZE, DETECT_DOUBLE);
  signal parity_data_w    : std_logic_vector(HAMM_PARITY_SIZE-1 downto 0);
  signal parity_diff_w    : std_logic_vector(HAMM_PARITY_SIZE-1 downto 0);
  signal corr_mask_w      : std_logic_vector(DATA_SIZE-1 downto 0);
  signal corr_data_w      : std_logic_vector(DATA_SIZE-1 downto 0);

  signal single_err_w     : std_logic;
  signal double_err_w     : std_logic;
begin

  gen_ENCODE : for i in HAMM_PARITY_SIZE-1 downto 0 generate
    constant BITS_QT  : integer := get_parity_qt(DATA_SIZE, i);
    signal ecc_data_w : std_logic_vector(BITS_QT-1 downto 0);
  begin
    gen_DATA : for j in ecc_data_w'range generate
      ecc_data_w(j) <= encoded_i(PARITY_POS(i, j));
    end generate;
    parity_data_w(i) <= xor_reduce(ecc_data_w);
  end generate;

  parity_diff_w <= parity_data_w xor encoded_i(DATA_SIZE+HAMM_PARITY_SIZE-1 downto DATA_SIZE);

  gen_CORRECTION_MASK : for i in corr_mask_w'range generate
    corr_mask_w(i) <= nor_reduce(ERROR_BIT(i)(HAMM_PARITY_SIZE-1 downto 0) xor parity_diff_w);
  end generate;

  corr_data_w <= (encoded_i(DATA_SIZE-1 downto 0) xor corr_mask_w) when correct_error_i = '1' else encoded_i(DATA_SIZE-1 downto 0);

  gen_DOUBLE_DETECT : if DETECT_DOUBLE generate
    signal addit_parity_w : std_logic;
    signal hamm_err_w     : std_logic;
  begin
    -- calculate additional parity
    addit_parity_w <= xor_reduce(encoded_i);
    -- get 1 if hamming has detected an error
    hamm_err_w  <= or_reduce(parity_diff_w);
    -- check double error
    double_err_w <= (not addit_parity_w) and hamm_err_w;
    -- set single error only when dont have double error
    single_err_w <= hamm_err_w and not double_err_w;
  end generate;
  gen_NOT_DOUBLE_DETECT : if not DETECT_DOUBLE generate
    -- set single error when hamming detects one
    single_err_w <= or_reduce(parity_diff_w);
    -- never detects two errors
    double_err_w <= '0';
  end generate;

  -- assign error wires to output
  single_err_o <= single_err_w;
  double_err_o <= double_err_w;

  -- output corrected data only when has corrected single error. If not, output not-modified data
  data_o <= corr_data_w when single_err_w = '1' else encoded_i(DATA_SIZE-1 downto 0);

end architecture;
