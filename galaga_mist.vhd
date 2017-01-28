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
 CLOCK_27  		: in std_logic;
 LED 				: in std_logic;
 VGA_R     		: out std_logic_vector(5 downto 0);
 VGA_G     		: out std_logic_vector(5 downto 0);
 VGA_B     		: out std_logic_vector(5 downto 0);
 VGA_HS    		: out std_logic;
 VGA_VS    		: out std_logic;
  SPI_SCK 		: in std_logic;
  SPI_DI 		: in std_logic;
  SPI_DO 		: out std_logic;
  SPI_SS2 		: in std_logic;
  SPI_SS3 		: in std_logic;
  SPI_SS4 		: in std_logic;
  CONF_DATA0	: in std_logic;
  AUDIO_L 		: out std_logic;
  AUDIO_R 		: out std_logic

);
end galaga_mist;

architecture struct of galaga_mist is
 signal clock_14k			: std_logic;
 signal clock_18  		: std_logic;
 signal clock_11  		: std_logic; 
 signal pll_locked  		: std_logic;
 signal r         		: std_logic_vector(2 downto 0);
 signal g         		: std_logic_vector(2 downto 0);
 signal b         		: std_logic_vector(1 downto 0);
 signal hsync 				: std_logic; 
 signal vsync 				: std_logic;  
 signal audio_pwm 		: std_logic; 
 signal audio        	: std_logic_vector(9 downto 0);
 signal reset        	: std_logic;
 
  -- User IO
  signal buttons    		: std_logic_vector(1 downto 0);
  signal joy0       		: std_logic_vector(7 downto 0);
  signal joy1       		: std_logic_vector(7 downto 0);
  signal status     		: std_logic_vector(7 downto 0);

  signal kbd_joy0 		: std_logic_vector(7 downto 0);
  signal kbd_joy1 		: std_logic_vector(7 downto 0);  
  signal ps2Clk     		: std_logic;
  signal ps2Data    		: std_logic;
  signal ps2_scancode 	: std_logic_vector(7 downto 0);

  signal VGA_R_O  : std_logic_vector(5 downto 0);
  signal VGA_G_O  : std_logic_vector(5 downto 0);
  signal VGA_B_O  : std_logic_vector(5 downto 0);
  signal VGA_HS_O : std_logic;
  signal VGA_VS_O : std_logic;
 

  constant CONF_STR : string := 
  "Galaga;;T1,Coin;T2,Player 1 Start;T3,Player 2 Start;O4,Scanlines,OFF,ON;T5,Reset;O6,Service,OFF,ON;O7,TestMode,OFF,ON;";

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
  
   component user_io
	 generic ( STRLEN : integer := 0 );
    port (
      SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
      SPI_MISO : out std_logic;
      conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
      buttons : out std_logic_vector(1 downto 0);
      joystick_0 : out std_logic_vector(7 downto 0);
      joystick_1 : out std_logic_vector(7 downto 0);
      status : out std_logic_vector(7 downto 0);
      ps2_clk : in std_logic;
      ps2_kbd_clk : out std_logic;
      ps2_kbd_data : out std_logic
    );
  end component user_io;

  component osd
    port (
      pclk, sck, ss, sdi, hs_in, vs_in, scanline_ena_h : in std_logic;
      red_in, blue_in, green_in : in std_logic_vector(5 downto 0);
      red_out, blue_out, green_out : out std_logic_vector(5 downto 0);
      hs_out, vs_out : out std_logic
    );
  end component osd;

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

clk_11_18 : entity work.pll50_to_11_and_18
port map(
 inclk0 => CLOCK_27,
 c0 => clock_14k,
 c1 => clock_18,
 c2 => clock_11,
 locked => pll_locked
);
  
  osd_inst : osd
    port map (
      pclk => clock_18,
      sdi => SPI_DI,
      sck => SPI_SCK,
      ss => SPI_SS3,
      red_in => VGA_R_O,
      green_in => VGA_G_O,
      blue_in => VGA_B_O,
      hs_in => VGA_HS_O,
      vs_in => VGA_VS_O,
      scanline_ena_h => status(4),
      red_out => VGA_R,
      green_out => VGA_G,
      blue_out => VGA_B,
      hs_out => VGA_HS,
      vs_out => VGA_VS
    );
	 
	 user_io_inst : user_io
 	generic map (STRLEN => CONF_STR'length)
   port map (
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,
      SPI_MOSI => SPI_DI,
      SPI_MISO => SPI_DO,
      conf_str => to_slv(CONF_STR),
      buttons  => buttons,
      joystick_1 => joy1,
      joystick_0 => joy0,
      status => status,
      ps2_clk => clock_14k,
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );

galaga : entity work.galaga
port map(
 clock_18     => 	clock_18,
 clock_11     => 	clock_11, 
 reset        => 	reset,
 video_r      => 	r,
 video_g      => 	g,
 video_b      => 	b,
-- video_csync  => csync,
-- video_blankn => blankn,
 video_hs     => hsync,
 video_vs     => vsync,

 audio        => 	audio,
 b_test       =>  status(7),--'1',--no Function at all
 b_svce       =>  status(6),--'1',--no Function at all 
 coin         =>  kbd_joy0(3) or status(1),
 start1       =>  kbd_joy0(1) or status(2),
 start2       =>  kbd_joy0(2) or status(3), 
 left1        => 	joy0(2) or kbd_joy0(5),
 right1       => 	joy0(3) or kbd_joy0(4),
 fire1        => 	joy0(4) or kbd_joy0(0),
 left2        =>  joy1(2) or kbd_joy0(5),
 right2       =>  joy1(3) or kbd_joy0(4),
 fire2        =>  joy1(4) or kbd_joy0(0)
);

VGA_R_O <= r & "000";
VGA_G_O <= g & "000";
VGA_B_O <= b & "0000";

-- synchro composite/ synchro horizontale
VGA_HS_O <= hsync;
-- commutation rapide / synchro verticale
VGA_VS_O <= vsync;



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

end struct;
