library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;
use ieee.std_logic_textio.all;

library work;
use work.harv_pkg.harv;

entity sim_from_dump is
end entity;

architecture arch of sim_from_dump is
  constant period : time := 20 ns;
  signal rstn  : std_logic := '0';
  signal clk   : std_logic := '0';
  signal start : std_logic := '0';

  constant INST_BASE_ADDR : integer := 0;
  constant INST_SIZE      : integer := 4096;
  constant DATA_BASE_ADDR : integer := 8192;
  constant DATA_SIZE      : integer := 4096;

  type mem_t is array(natural range <>) of std_logic_vector(7 downto 0);
  signal inst_mem : mem_t(INST_SIZE + INST_BASE_ADDR - 1 downto INST_BASE_ADDR);
  signal data_mem : mem_t(DATA_SIZE + DATA_BASE_ADDR - 1 downto DATA_BASE_ADDR);

  -- instruction memory interface
  signal imem_instr_i : std_logic_vector(31 downto 0);
  signal imem_pc_o    : std_logic_vector(31 downto 0);
  signal imem_req_o   : std_logic;
  signal imem_gnt_i   : std_logic;

  -- data memory interface
  signal dmem_rdata_i : std_logic_vector(31 downto 0);
  signal dmem_req_o   : std_logic;
  signal dmem_wren_o  : std_logic;
  signal dmem_gnt_i   : std_logic;
  signal dmem_err_i   : std_logic;
  signal dmem_ben_o   : std_logic_vector(1 downto 0);
  signal dmem_usgn_o  : std_logic;
  signal dmem_wdata_o : std_logic_vector(31 downto 0);
  signal dmem_addr_o  : std_logic_vector(31 downto 0);

  constant INST_DUMP_FILE_PATH : string := "../../../../../src/test_text.dump";
  constant DATA_DUMP_FILE_PATH : string := "../../../../../src/test_data.dump";

  procedure load_memory (
      constant FILE_PATH : in string;
      constant BASE_ADDR : in integer;
      signal mem        : out mem_t
    ) is
      file     file_v  : text;
      variable line_v  : line;
      variable addr_v  : integer;
      variable byte_v  : std_logic_vector(7 downto 0);
      variable error_v : boolean;
  begin
    -- read data dump file
    file_open(file_v, FILE_PATH, READ_MODE);
    -- initialize instructions address counter
    addr_v := BASE_ADDR;
    -- iterate through all lines in the file
    while not endfile(file_v) loop
      -- read line from file_v
      readline(file_v, line_v);
      -- ensure that the line is not empty
      if line_v'length > 0 then
        -- iterate in each byte of the data
        for i in 3 downto 0 loop
          -- read hex byte from line
          hread(line_v, byte_v, error_v);
          -- assert if the hread had an error
          assert (error_v) report "Text I/O read error" severity FAILURE;
          -- write byte to memory
          mem(addr_v + i) <= byte_v;
        end loop;
        -- increment address
        addr_v := addr_v + 4;
      end if;
    end loop;
    file_close(file_v);
  end procedure;
begin
  rstn  <= '1' after period;
  clk   <= not clk after period/2;
  start <= '1' after period * 2; -- set start signal after 2 clock cycles

  harv_u : harv
  generic map (
    PROGRAM_START_ADDR => x"00000000",
    TRAP_HANDLER_ADDR  => x"00000000",
    TMR_CONTROL        => FALSE,
    TMR_ALU            => FALSE,
    HAMMING_REGFILE    => FALSE,
    HAMMING_PC         => FALSE
  )
  port map (
    rstn_i         => rstn,
    clk_i          => clk,
    start_i        => start,
    poweron_rstn_i => rstn,
    wdt_rstn_i     => '1',
    imem_instr_i   => imem_instr_i,
    imem_pc_o      => imem_pc_o,
    imem_req_o     => imem_req_o,
    imem_gnt_i     => imem_gnt_i,
    imem_err_i     => '0',
    hard_dmem_o    => open,
    dmem_rdata_i   => dmem_rdata_i,
    dmem_req_o     => dmem_req_o,
    dmem_wren_o    => dmem_wren_o,
    dmem_gnt_i     => dmem_gnt_i,
    dmem_err_i     => dmem_err_i,
    dmem_sbu_i     => '0',
    dmem_dbu_i     => '0',
    dmem_ben_o     => dmem_ben_o,
    dmem_usgn_o    => dmem_usgn_o,
    dmem_wdata_o   => dmem_wdata_o,
    dmem_addr_o    => dmem_addr_o
  );

  -- INSTRUCTION MEMORY ACCESS
  process
    variable addr_v : integer;
  begin
    -- load instruction memory
    report "Loading instruction memory from " & INST_DUMP_FILE_PATH severity NOTE;
    load_memory(INST_DUMP_FILE_PATH, INST_BASE_ADDR, inst_mem);
    -- infinite loop to provide instruction memory access
    loop
      -- disable grant signal
      imem_gnt_i <= '0';
      imem_instr_i <= (others => 'X');
      -- wait memory request
      wait until rising_edge(clk) and imem_req_o = '1';
      -- wait 1 cycle to give response
      wait for period;
      -- grant response
      imem_gnt_i <= '1';
      addr_v := to_integer(unsigned(imem_pc_o));
      imem_instr_i <= inst_mem(addr_v+3) &
                      inst_mem(addr_v+2) &
                      inst_mem(addr_v+1) &
                      inst_mem(addr_v);
      -- grant response for 1 cycle
      wait for period;
    end loop;
  end process;

  -- DATA MEMORY ACCESS
  process
    variable addr_v  : integer;
  begin
    -- if there is no data dump file
    if DATA_DUMP_FILE_PATH = "" then
      report "No data memory to load" severity NOTE;
    else -- if data dump file is defined
      -- load data memory from file
      report "Loading data memory from " & DATA_DUMP_FILE_PATH severity NOTE;
      load_memory (DATA_DUMP_FILE_PATH, DATA_BASE_ADDR, data_mem);
    end if;
    -- infinite loop to provide data memory access
    loop
      -- disable grant signal
      dmem_gnt_i   <= '0';
      dmem_rdata_i <= (others => 'X');
      dmem_err_i   <= '0';
      -- wait memory request
      wait until rising_edge(clk) and dmem_req_o = '1';
      -- wait 1 cycle to give response
      wait for period;
      -- convert address to integer
      addr_v := to_integer(unsigned(dmem_addr_o));
      -- check if range is ok
      if addr_v < DATA_BASE_ADDR or addr_v >= (DATA_BASE_ADDR + DATA_SIZE) then
        dmem_err_i <= '1';
      else
        -- grant response
        dmem_gnt_i <= '1';
        -- if it will perform a write
        if dmem_wren_o = '1' then
          -- write the first byte
          data_mem(addr_v) <= dmem_wdata_o(7 downto 0);
          -- write the second byte for half-word and word
          if dmem_ben_o(0) = '1' then
            data_mem(addr_v+1) <= dmem_wdata_o(15 downto 8);
          end if;
          -- write the upper 16 bits, only for full word
          if dmem_ben_o(1) = '1' then
            data_mem(addr_v+2) <= dmem_wdata_o(23 downto 16);
            data_mem(addr_v+3) <= dmem_wdata_o(31 downto 24);
          end if;

        -- read data memory
        else
          -- case between all acess possibilities
          case dmem_ben_o is
            -- byte read with and without sign-extension
            when "00" =>
              if dmem_usgn_o = '1' then
                dmem_rdata_i <= x"000000" & data_mem(addr_v);
              else
                dmem_rdata_i <= (31 downto 8 => data_mem(addr_v)(7)) & data_mem(addr_v);
              end if;

            -- half-word read with and without sign-extension
            when "01" =>
              if dmem_usgn_o = '1' then
                dmem_rdata_i <= (
                  31 downto 16 => data_mem(addr_v + 1)(7),
                  15 downto  8 => data_mem(addr_v + 1),
                   7 downto  0 => data_mem(addr_v)
                );
              else
                dmem_rdata_i <= x"000000" & data_mem(addr_v);
              end if;

            -- word read - concatanate bytes
            when "11" =>
              dmem_rdata_i <= data_mem(addr_v + 3) &
                             data_mem(addr_v + 2) &
                             data_mem(addr_v + 1) &
                             data_mem(addr_v);
            when others =>
              report "Wrong parameters to data memory" severity ERROR;

          end case;
          report to_hstring(dmem_addr_o) & ": " & to_hstring(dmem_rdata_i);
        end if;
      end if;
      -- response for 1 cycle
      wait for period;
    end loop;
  end process;

end architecture;
