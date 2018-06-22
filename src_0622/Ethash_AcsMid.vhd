----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
--
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;	

library work;
use work.Ethash_pkg.all;
use work.Ethash_AcsMid_pkg.all;

entity Ethash_AcsMid is
generic(
	NumExpo_Ch_i			: Positive := 5; -- must lager than NumExpo_Ch_o
	NumExpo_Ch_o			: Positive := 4
);
port (
	Data_i		: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i			: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		: in	std_logic_vector(2**NumExpo_Ch_i-1 downto 0);
	Valid_i		: out	std_logic_vector(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		: out	std_logic_vector(2**NumExpo_Ch_o-1 downto 0);
	
	clk			: in	std_logic;
	aclr			: in	std_logic
);
end Ethash_AcsMid;

architecture rtl of Ethash_AcsMid is
--============================ constant declare ============================--
constant cst_NumCh_i		: Positive := 2**NumExpo_Ch_i; -- 32
constant cst_NumCh_o		: Positive := 2**NumExpo_Ch_o; -- 16
constant cst_Deepth_iRam	: Positive := 64; -- 64
constant cst_Deepth_oRam	: Positive := 2*cst_NumCh_i*gcst_AM_SelDL; -- 2*(32*3)=192
constant cst_DeepthExpo_iRam	: Positive := Fnc_Int2Wd(cst_Deepth_iRam-1); -- 6
constant cst_DeepthExpo_oRam	: Positive := Fnc_Int2Wd(cst_Deepth_oRam-1); -- 8
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_AcsMid_oRamAddrGen
generic(
	WrGen_N			: Positive := cst_NumCh_i; -- 32
	WrGen_P			: Positive := 2;
	WrGen_L			: Positive := gcst_AM_SelDL; -- 3
	RdRam_N			: Positive := cst_NumCh_i; -- 32
	RdRam_P			: Positive := gcst_AM_SelDL * 2; -- 6
	WrGen_DL			: Positive := gcst_AM_SeloRamDL; -- 4
	RdGen_DL			: Positive := cst_NumCh_i*gcst_AM_SelDL+gcst_AM_SeloRamDL -- 32*3+4
);
port (
	Addr_Wr		: out	Natural;
	Addr_Rd		: out	typ_1D_Nat(RdRam_N-1 downto 0);
	Msk_clr		: out	std_logic;
	
	En				: in	std_logic;
	
	clk			: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Ethash_AcsMid_Cell
generic(
	Device_Family			: string := "Cyclone V"; --"Stratix 10";--"Cyclone V"
	Width_Data				: Positive := gcst_AM_WidthData;
	Num_Ch					: Positive := cst_NumCh_i;
	DeepthExpo_iRam		: Positive := cst_DeepthExpo_iRam; -- 64 = 2^6
	DeepthExpo_oRam		: Positive := cst_DeepthExpo_oRam -- 256 = 2^8
);
port (
	Data_i	: in	std_logic_vector(Width_Data-1 downto 0);
	Ch_i		: in	std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Wr			: in	std_logic;
	Valid		: out	std_logic;
	
	Data_o	: out	std_logic_vector(Width_Data-1 downto 0);
	Ch_o		: out std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Flag_o	: out std_logic;
	
	oRam_AddrWr	: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	oRam_AddrRd	: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	
	Msk_Clr	: in	std_logic;
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	Msk_o		: out	std_logic_vector(Num_Ch-1 downto 0);
	
	AcsMid_Valid	: out std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Ethash_AcsMid_DCross
generic(
	NumExpo_Ch_i			: Positive := NumExpo_Ch_i;
	NumExpo_Ch_o			: Positive := NumExpo_Ch_o
);
port (
	Data_i		: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i			: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		: in	std_logic_vector(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		: out	std_logic_vector(2**NumExpo_Ch_o-1 downto 0);

	clk			: in	std_logic;
	aclr			: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	nL					: Positive := NumExpo_Ch_i;
	Typ				: string	:= "and"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	std_logic_vector(2**nL-1 downto 0);
	Do			: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_oRam_AddrWr		: Natural;
signal sgn_oRam_AddrRd		: typ_1D_Nat(cst_NumCh_i-1 downto 0);
signal sgn_Msk_clr			: std_logic;

signal sgn_AcsMid_Valid		: std_logic_vector(cst_NumCh_i-1 downto 0);
signal sgn_AcsMid_Valid_tot	: std_logic;

type typ_1D_Msk is array (natural range<>) of std_logic_vector(cst_NumCh_i-1 downto 0);
signal sgn_Msk_i				: typ_1D_Msk(cst_NumCh_i-1 downto 0);
signal sgn_Msk_o				: typ_1D_Msk(cst_NumCh_i-1 downto 0);

signal sgn_Data_Sel		: typ_AM_1D_Data(cst_NumCh_i-1 downto 0);
signal sgn_Ch_Sel			: typ_1D_Word(cst_NumCh_i-1 downto 0); -- 0 to Num_Ch_o-1
signal sgn_Flag_Sel		: std_logic_vector(cst_NumCh_i-1 downto 0);
--============================ function declare ============================--

--=========================== attribute declare ============================--

begin

inst01: Ethash_AcsMid_oRamAddrGen
port map(
	Addr_Wr		=> sgn_oRam_AddrWr,--: out	Natural;
	Addr_Rd		=> sgn_oRam_AddrRd,--: out	typ_1D_Nat(RdRam_N-1 downto 0);
	Msk_clr		=> sgn_Msk_clr,--: out	std_logic;
	
	En				=> sgn_AcsMid_Valid_tot,--: in	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

inst04:Lg_BoolOpt
port map(
	Di			=> sgn_AcsMid_Valid,--: in	std_logic_vector(2**nL-1 downto 0);
	Do			=> sgn_AcsMid_Valid_tot,--: out	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

i0100: for i in 0 to cst_NumCh_i-1 generate
	inst02: Ethash_AcsMid_Cell
	port map(
		Data_i		=> Data_i(i),--(io): in	std_logic_vector(Width_Data-1 downto 0);
		Ch_i			=> Ch_i(i),--(io): in	std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
		Wr				=> Flag_i(i),--(io): in	std_logic;
		Valid			=> Valid_i(i),--: out	std_logic;
		
		Data_o		=> sgn_Data_Sel(i),--: out	std_logic_vector(Width_Data-1 downto 0);
		Ch_o			=> sgn_Ch_Sel(i),--: out std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
		Flag_o		=> sgn_Flag_Sel(i),--: out std_logic;
		
		oRam_AddrWr	=> conv_std_logic_vector(sgn_oRam_AddrWr,cst_DeepthExpo_oRam),--: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
		oRam_AddrRd	=> conv_std_logic_vector(sgn_oRam_AddrRd(i),cst_DeepthExpo_oRam),--: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
		
		Msk_Clr		=> sgn_Msk_clr,--: in	std_logic;
		Msk_i			=> sgn_Msk_i(i),--: in	std_logic_vector(Num_Ch-1 downto 0);
		Msk_o			=> sgn_Msk_o(i),--: out	std_logic_vector(Num_Ch-1 downto 0);
		
		AcsMid_Valid	=> sgn_AcsMid_Valid(i),--: out std_logic;
		
		clk			=> clk,--: in	std_logic;
		aclr			=> aclr--: in	std_logic
	);
end generate i0100;

sgn_Msk_i(0) <= sgn_Msk_o(cst_NumCh_i-1);
i0200: for i in 1 to cst_NumCh_i-1 generate
	sgn_Msk_i(i) <= sgn_Msk_o(i-1);
end generate i0200;

inst03:Ethash_AcsMid_DCross
port map(
	Data_i		=> sgn_Data_Sel,--: in	typ_AM_1D_Data(2**NumExpo_Ch_i-1 downto 0);
	Ch_i			=> sgn_Ch_Sel,--: in	typ_1D_Word(2**NumExpo_Ch_i-1 downto 0); -- 0 to Num_Ch_o-1
	Flag_i		=> sgn_Flag_Sel,--: in	std_logic_vector(2**NumExpo_Ch_i-1 downto 0);
	
	Data_o		=> Data_o,--: out	typ_AM_1D_Data(2**NumExpo_Ch_o-1 downto 0);
	Flag_o		=> Flag_o,--: out	std_logic_vector(2**NumExpo_Ch_o-1 downto 0);

	clk			=> clk,--: in	std_logic;
	aclr			=> aclr--: in	std_logic
);

end rtl;
