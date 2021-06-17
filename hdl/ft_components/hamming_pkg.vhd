library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

package hamming_pkg is

  -- TYPES
  type parity_pos_t is array (natural range <>, natural range <>) of integer;
  type err_bit_t is array(natural range <>) of std_logic_vector(6 downto 0);

  -- CONSTANTS
  constant PARITY_POS : parity_pos_t := (
    0 => ( 0,  1,  3,  4,  6,  8, 10, 11, 13, 15, 17, 19, 21, 23, 25, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 57, 59, 61, 63),
    1 => ( 0,  2,  3,  5,  6,  9, 10, 12, 13, 16, 17, 20, 21, 24, 25, 27, 28, 31, 32, 35, 36, 39, 40, 43, 44, 47, 48, 51, 52, 55, 56, 58, 59, 62, 63),
    2 => ( 1,  2,  3,  7,  8,  9, 10, 14, 15, 16, 17, 22, 23, 24, 25, 29, 30, 31, 32, 37, 38, 39, 40, 45, 46, 47, 48, 53, 54, 55, 56, 60, 61, 62, 63),
    3 => ( 4,  5,  6,  7,  8,  9, 10, 18, 19, 20, 21, 22, 23, 24, 25, 33, 34, 35, 36, 37, 38, 39, 40, 49, 50, 51, 52, 53, 54, 55, 56, 64, -1, -1, -1),
    4 => (11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, -1, -1, -1, -1),
    5 => (26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, -1, -1, -1, -1),
    6 => (57, 58, 59, 60, 61, 62, 63, 64, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)
  );

  constant ERROR_BIT : err_bit_t := (
     0 => "0000011",  1 => "0000101",  2 => "0000110",  3 => "0000111",  4 => "0001001",  5 => "0001010",
     6 => "0001011",  7 => "0001100",  8 => "0001101",  9 => "0001110", 10 => "0001111", 11 => "0010001",
    12 => "0010010", 13 => "0010011", 14 => "0010100", 15 => "0010101", 16 => "0010110", 17 => "0010111",
    18 => "0011000", 19 => "0011001", 20 => "0011010", 21 => "0011011", 22 => "0011100", 23 => "0011101",
    24 => "0011110", 25 => "0011111", 26 => "0100001", 27 => "0100010", 28 => "0100011", 29 => "0100100",
    30 => "0100101", 31 => "0100110", 32 => "0100111", 33 => "0101000", 34 => "0101001", 35 => "0101010",
    36 => "0101011", 37 => "0101100", 38 => "0101101", 39 => "0101110", 40 => "0101111", 41 => "0110000",
    42 => "0110001", 43 => "0110010", 44 => "0110011", 45 => "0110100", 46 => "0110101", 47 => "0110110",
    48 => "0110111", 49 => "0111000", 50 => "0111001", 51 => "0111010", 52 => "0111011", 53 => "0111100",
    54 => "0111101", 55 => "0111110", 56 => "0111111", 57 => "1000001", 58 => "1000010", 59 => "1000011",
    60 => "1000100", 61 => "1000101", 62 => "1000110", 63 => "1000111", 64 => "1001000"
  );

  -- FUNCTIONS -- runs only at synthesis
  function get_parity_qt (data_size : in integer; pos : in integer) return integer;
  function get_ecc_size (data_size : in integer; detect_double : in boolean) return integer;
  function get_parity_data_result (data : in std_logic_vector; detect_double : in boolean) return std_logic_vector;

  -- COMPONENTS
  component hamming_encoder
  generic (
    DATA_SIZE     : integer;
    DETECT_DOUBLE : boolean
  );
  port (
    data_i    : in  std_logic_vector(DATA_SIZE-1 downto 0);
    encoded_o : out std_logic_vector(DATA_SIZE+get_ecc_size(DATA_SIZE, DETECT_DOUBLE)-1 downto 0)
  );
  end component hamming_encoder;

  component hamming_decoder
  generic (
    DATA_SIZE     : integer := 32;
    DETECT_DOUBLE : boolean
  );
  port (
    encoded_i       : in  std_logic_vector(DATA_SIZE+get_ecc_size(DATA_SIZE, DETECT_DOUBLE)-1 downto 0);
    correct_error_i : in  std_logic;
    single_err_o    : out std_logic;
    double_err_o    : out std_logic;
    data_o          : out std_logic_vector(DATA_SIZE-1 downto 0)
  );
  end component hamming_decoder;

  component hamming_register
  generic (
    HAMMING_ENABLE : boolean;
    RESET_VALUE    : std_logic_vector
  );
  port (
    correct_en_i : in  std_logic;
    write_en_i   : in  std_logic;
    data_i       : in  std_logic_vector(31 downto 0);
    rstn_i       : in  std_logic;
    clk_i        : in  std_logic;
    single_err_o : out std_logic;
    double_err_o : out std_logic;
    data_o       : out std_logic_vector(31 downto 0)
  );
  end component hamming_register;

end package;

package body hamming_pkg is

  function get_parity_qt (data_size : in integer; pos : in integer) return integer is
  begin
    for j in 0 to PARITY_POS'length(2)-1 loop
      if PARITY_POS(pos, j) >= data_size or PARITY_POS(pos, j) = -1 then
        return j;
      end if;
    end loop;
    return PARITY_POS'length(2);
  end function;

  function get_ecc_size (data_size : in integer; detect_double : in boolean) return integer is
  begin
    if detect_double then
      return 1 + get_ecc_size(data_size, FALSE);
    end if;
    for j in 0 to PARITY_POS'length(1)-1 loop
      if data_size < PARITY_POS(j, 0) then
        return j;
      end if;
    end loop;
    return PARITY_POS'length(1);
  end function;

  function get_parity_data_result (data : in std_logic_vector; detect_double : in boolean) return std_logic_vector is
    constant HAMM_PARITY_SIZE  : integer := get_ecc_size(data'length, FALSE);
    constant TOTAL_PARITY_SIZE : integer := get_ecc_size(data'length, detect_double);
    variable par_data : std_logic_vector(HAMM_PARITY_SIZE-1 downto 0) := (others => '0');
  begin
    for i in 0 to HAMM_PARITY_SIZE-1 loop
      for j in 0 to get_parity_qt(data'length, i)-1 loop
        if PARITY_POS(i, j) < data'length and PARITY_POS(i, j) /= -1 then
          par_data(i) := par_data(i) xor data(PARITY_POS(i, j));
        end if;
      end loop;
    end loop;
    if detect_double then
      return xor_reduce(par_data) & par_data;
    end if;
    return par_data;
  end function;

end hamming_pkg;
