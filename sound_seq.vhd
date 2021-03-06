library ieee;
use ieee.std_logic_1164.all,ieee.numeric_std.all;

entity sound_seq is
port (
	clk  : in  std_logic;
	addr : in  std_logic_vector(6 downto 0);
	data : out std_logic_vector(3 downto 0)
);
end entity;

architecture prom of sound_seq is
	type rom is array(0 to  127) of std_logic_vector(3 downto 0);
	signal rom_data: rom := (
		X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",
		X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",
		X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",
		X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",X"F",X"D",X"F",X"F",
		X"7",X"F",X"E",X"D",X"F",X"F",X"E",X"D",X"F",X"F",X"E",X"D",X"F",X"F",X"E",X"D",
		X"F",X"F",X"E",X"D",X"F",X"F",X"F",X"B",X"7",X"F",X"E",X"D",X"F",X"F",X"E",X"D",
		X"F",X"F",X"E",X"D",X"F",X"F",X"E",X"D",X"F",X"F",X"F",X"B",X"7",X"F",X"E",X"D",
		X"F",X"F",X"E",X"D",X"F",X"F",X"E",X"D",X"F",X"F",X"E",X"D",X"F",X"F",X"F",X"B");
begin
process(clk)
begin
	if rising_edge(clk) then
		data <= rom_data(to_integer(unsigned(addr)));
	end if;
end process;
end architecture;
