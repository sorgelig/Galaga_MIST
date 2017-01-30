---------------------------------------------------------------------------------
-- Mist FPGA Top level for Galaga Midway by Gehstock. Original DE2 Toplevel by Dar (darfpga@aol.fr) (December 2016)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- Main features :
--  PS2 keyboard input
--  Joystick input
--  Sigma Delta sound output
--  NO board SRAM/Flash used
--
-- Uses 1 pll for 18MHz, 11MHz and 14khz generation from 27MHz
--
-- Board key :
--      0 : reset
--
-- Keyboard inputs :
--   ESC : Add coin
--   1 : Start 1 player
--   2 : Start 2 players
--   SPACE       : Fire player 1 & 2
--   UP arrow : Move right player 1 & 2
--   DOWN arrow  : Move left player 1 & 2
--
-- Dip switch and other details : see galaga.vhd

---------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.all;

entity galaga_mist is
port(
	CLOCK_27  	: in std_logic;
	LED 			: out std_logic;
	VGA_R     	: out std_logic_vector(5 downto 0);
	VGA_G     	: out std_logic_vector(5 downto 0);
	VGA_B     	: out std_logic_vector(5 downto 0);
	VGA_HS    	: out std_logic;
	VGA_VS    	: out std_logic;
	SPI_SCK 		: in std_logic;
	SPI_DI 		: in std_logic;
	SPI_DO 		: out std_logic;
	SPI_SS3 		: in std_logic;
	CONF_DATA0	: in std_logic;
	AUDIO_L 		: out std_logic;
	AUDIO_R 		: out std_logic

);
end galaga_mist;

architecture struct of galaga_mist is
	signal clock_72  		: std_logic;
	signal clock_18  		: std_logic;
	signal pll_locked  	: std_logic;
	signal r         		: std_logic_vector(2 downto 0);
	signal g         		: std_logic_vector(2 downto 0);
	signal b         		: std_logic_vector(1 downto 0);
	signal hsync 			: std_logic; 
	signal vsync 			: std_logic;  
	signal blankn			: std_logic;  
	signal pix_ce			: std_logic;  
	signal audio_pwm 		: std_logic; 
	signal audio        	: std_logic_vector(9 downto 0);
	signal reset        	: std_logic;

	-- User IO
	signal buttons    	: std_logic_vector(1 downto 0);
	signal joy0       	: std_logic_vector(7 downto 0);
	signal joy1       	: std_logic_vector(7 downto 0);
	signal status     	: std_logic_vector(31 downto 0);
	signal scandoubler_disable : std_logic;  
	signal ypbpr         : std_logic;  

	signal kbd_joy0 		: std_logic_vector(7 downto 0);
	signal kbd_joy1 		: std_logic_vector(7 downto 0);  
	signal ps2Clk     	: std_logic;
	signal ps2Data    	: std_logic;
	signal ps2_scancode 	: std_logic_vector(7 downto 0);

	signal VGA_R_O  		: std_logic_vector(7 downto 0);
	signal VGA_G_O  		: std_logic_vector(7 downto 0);
	signal VGA_B_O  		: std_logic_vector(7 downto 0);
 

	constant CONF_STR : string := 
		"Galaga;;T1,Add Coin       (ESC);T2,Player 1 Start (1);T3,Player 2 Start (2);O89,Scanlines,OFF,25%,50%,75%;T5,Reset;";

	function to_slv(s: string) return std_logic_vector is
		constant ss: string(1 to s'length) := s;
		variable rval: std_logic_vector(1 to 8 * s'length);
		variable p: integer;
		variable c: integer; 
	begin  
		for i in ss'range loop
			p := 8 * i;
			c := character'pos(ss(i));
			rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8));
		end loop;
		return rval;
	end function;
  
   component mist_io
		generic ( STRLEN : integer := 0 );
		port (
			clk_sys :in std_logic;
			SPI_SCK, CONF_DATA0, SPI_DI :in std_logic;
			SPI_DO : out std_logic;
			conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
			buttons : out std_logic_vector(1 downto 0);
			joystick_0 : out std_logic_vector(7 downto 0);
			joystick_1 : out std_logic_vector(7 downto 0);
			status : out std_logic_vector(31 downto 0);
			scandoubler_disable, ypbpr : out std_logic;
			ps2_kbd_clk : out std_logic;
			ps2_kbd_data : out std_logic
		);
	end component mist_io;

	component video_mixer
		port (
			clk_sys, ce_pix : in std_logic;
			SPI_SCK, SPI_SS3, SPI_DI : in std_logic;
			scanlines : in std_logic_vector(1 downto 0);
			scandoubler_disable, ypbpr, ypbpr_full : in std_logic;

			R, G, B : in std_logic_vector(7 downto 0);
			HSync, VSync : in std_logic;

			VGA_R,VGA_G, VGA_B : out std_logic_vector(5 downto 0);
			VGA_VS, VGA_HS : out std_logic
		);
	end component video_mixer;

   component keyboard
		PORT(
			clk : in std_logic;
			reset : in std_logic;
			ps2_kbd_clk : in std_logic;
			ps2_kbd_data : in std_logic;
			joystick : out std_logic_vector (7 downto 0)
		);
	end component;

begin

reset <= status(0) or status(5) or buttons(1) or not pll_locked; 

pll : entity work.pll
	port map(
		inclk0 => CLOCK_27,
		c0 => clock_72,
		c1 => clock_18,
		locked => pll_locked
);

vmixer : video_mixer
	port map (
		clk_sys => clock_72,
		ce_pix  => pix_ce,

		SPI_SCK => SPI_SCK, 
		SPI_SS3 => SPI_SS3,
		SPI_DI => SPI_DI,

		scanlines => status(9 downto 8),
		scandoubler_disable => scandoubler_disable,
		ypbpr => ypbpr,
		ypbpr_full => '1',

		R => VGA_R_O,
		G => VGA_G_O,
		B => VGA_B_O,
		HSync => hsync,
		VSync => vsync,

		VGA_R => VGA_R,
		VGA_G => VGA_G,
		VGA_B => VGA_B,
		VGA_VS => VGA_VS,
		VGA_HS => VGA_HS
);
	 
mist_io_inst : mist_io
	generic map (STRLEN => CONF_STR'length)
	port map (
		clk_sys => clock_18,
		SPI_SCK => SPI_SCK,
		CONF_DATA0 => CONF_DATA0,
		SPI_DI => SPI_DI,
		SPI_DO => SPI_DO,
		conf_str => to_slv(CONF_STR),
		buttons  => buttons,
		scandoubler_disable => scandoubler_disable,
		ypbpr => ypbpr,
		joystick_1 => joy1,
		joystick_0 => joy0,
		status => status,
		ps2_kbd_clk => ps2Clk,
		ps2_kbd_data => ps2Data
);

galaga : entity work.galaga
	port map(
		clock_18     => clock_18,
		reset        => reset,
		video_r      => r,
		video_g      => g,
		video_b      => b,
		video_blankn => blankn,
		video_hs     => hsync,
		video_vs     => vsync,
		pix_ce       => pix_ce,

		audio        => audio,
		b_test       => '0', --no Function at all
		b_svce       => '0', --no Function at all 
		coin         => kbd_joy0(3) or status(1),
		start1       => kbd_joy0(1) or status(2),
		start2       => kbd_joy0(2) or status(3), 
		left1        => joy0(2) or joy0(1) or kbd_joy0(5) or kbd_joy0(6),
		right1       => joy0(3) or joy0(0) or kbd_joy0(4) or kbd_joy0(7),
		fire1        => joy0(4) or kbd_joy0(0),
		left2        => joy1(2) or joy0(1) or kbd_joy0(5) or kbd_joy0(6),
		right2       => joy1(3) or joy0(0) or kbd_joy0(4) or kbd_joy0(7),
		fire2        => joy1(4) or kbd_joy0(0)
);

VGA_R_O <= r & r & r(2 downto 1) when blankn = '1' else "00000000";
VGA_G_O <= g & g & g(2 downto 1) when blankn = '1' else "00000000";
VGA_B_O <= b & b & b & b         when blankn = '1' else "00000000";

u_dac : entity work.dac
	port  map(
		clk_i    => clock_18,
		res_n_i  => not reset,
		dac_i  	=> audio,
		dac_o 	=> audio_pwm
);
    
AUDIO_L <= audio_pwm;
AUDIO_R <= audio_pwm;

u_keyboard : keyboard
	port  map(
		clk 				=> clock_18,
		reset 			=> reset,
		ps2_kbd_clk 	=> ps2Clk,
		ps2_kbd_data 	=> ps2Data,
		joystick 		=> kbd_joy0
);

LED <= '1';

end struct;
