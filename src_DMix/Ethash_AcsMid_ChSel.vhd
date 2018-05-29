----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    21/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid_ChSel - Behavioral
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

entity Ethash_AcsMid_ChSel is
generic(
	Num_Ch			: Positive := 32;
	Size_Ram_Expo	: Positive := 6 -- 64
);
port (
	Flag_i	: in	std_logic_vector(2**Size_Ram_Expo-1 downto 0);
	Ch_i		: in	typ_1D_Word(2**Size_Ram_Expo-1 downto 0);
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	
	Flag_Clr	: out	std_logic_vector(2**Size_Ram_Expo-1 downto 0);
	
	Flag_o	: out	std_logic;
	Ch_o		: out	std_logic_vector(gcst_WW-1 downto 0);
	Msk_o		: out	std_logic_vector(Num_Ch-1 downto 0);
	Addr_o	: out	std_logic_vector(Size_Ram_Expo-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_AcsMid_ChSel;

architecture rtl of Ethash_AcsMid_ChSel is
--============================ constant declare ============================--
constant Size_Ram	: Positive := 2**Size_Ram_Expo;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_AcsMid_ChSel_Cell
generic(
	Num_Ch			: Positive := Num_Ch;
	Size_Ram			: Positive := 2**Size_Ram_Expo;
	Idx_M				: Natural -- from 0 to Size_Ram-1
);
port (
	Flag		: in	std_logic;
	Ch			: in	std_logic_vector(gcst_WW-1 downto 0);
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	
	V_Mi		: in	std_logic_vector(Size_Ram-1 downto 0);
	V_Mo		: out	std_logic;
	
	Flag_Clr	: out	std_logic;
	Sel		: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Mux_nL1w_T2
generic(
	nL					: Positive := Size_Ram_Expo;
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	typ_1D_Word(2**nL-1 downto 0);
	Do			: out	std_logic_vector(gcst_WW-1 downto 0);
	Sel		: in	std_logic_vector(2**nL-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Mux_nL1b_T2
generic(
	nL					: Positive := Size_Ram_Expo;
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	std_logic_vector(2**nL-1 downto 0);
	Do			: out	std_logic;
	Sel		: in	std_logic_vector(2**nL-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_BoolOpt
generic(
	nL					: Positive := Size_Ram_Expo;
	Typ				: string	:= "or"; -- "or" "and" "xor" "nor" "nand" "xnor"
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
signal sgn_VM				: std_logic_vector(Size_Ram-1 downto 0);
signal sgn_Sel				: std_logic_vector(Size_Ram-1 downto 0);

type typ_1D_Addr is array (natural range<>) of std_logic_vector(Size_Ram_Expo-1 downto 0);
signal sgn_Addr			: typ_1D_Addr(Size_Ram-1 downto 0);
type typ_1D_AddrTr is array (natural range<>) of std_logic_vector(Size_Ram-1 downto 0);
signal sgn_Addr_Tr		: typ_1D_AddrTr(Size_Ram_Expo-1 downto 0);
signal sgn_Ch_o			: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Ch_o_syn		: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Addr_o			: std_logic_vector(Size_Ram_Expo-1 downto 0);
signal sgn_Flag_o			: std_logic;
signal sgn_Flag_o_syn	: std_logic;
signal sgn_cmp				: std_logic_vector(Num_Ch-1 downto 0);

constant cst_Msk_DL			: Positive := 2 + 1;
signal sgn_Msk					: std_logic_vector(Num_Ch-1 downto 0);
type typ_1D_Msk is array (natural range<>) of std_logic_vector(Num_Ch-1 downto 0);
signal sgn_Msk_DL				: typ_1D_Msk(cst_Msk_DL-1 downto 0);
constant cst_Ch_DL			: Positive := 2;
signal sgn_Ch					: typ_1D_Word(Size_Ram-1 downto 0);
type typ_2D_Ch is array (natural range<>) of typ_1D_Word(Size_Ram-1 downto 0);
signal sgn_Ch_DL				: typ_2D_Ch(cst_Ch_DL-1 downto 0);
--============================ function declare ============================--
attribute keep : boolean;
attribute keep of sgn_VM : signal is true;
attribute keep of sgn_Sel : signal is true;
begin

-- channel selcet array
i0100: for i in 0 to Size_Ram-1 generate
	inst01: Ethash_AcsMid_ChSel_Cell
	generic map(
		Idx_M				=> i--: Natural -- from 0 to Size_Ram-1
	)
	port map(
		Flag		=> Flag_i(i),--: in	std_logic;
		Ch			=> Ch_i(i),--: in	std_logic_vector(gcst_WW-1 downto 0);
		Msk_i		=> Msk_i,--: in	std_logic_vector(Num_Ch-1 downto 0);
		
		V_Mi		=> sgn_VM,--: in	std_logic_vector(Size_Ram-1 downto 0);
		V_Mo		=> sgn_VM(i),--: out	std_logic;
		
		Flag_Clr	=> Flag_Clr(i),--: out	std_logic;
		Sel		=> sgn_Sel(i),--: out	std_logic;
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0100;

-- ch mux / sel or / addr decoder
inst02: Lg_Mux_nL1w_T2
port map(
	Di			=> sgn_Ch_DL(cst_Ch_DL-1),--: in	typ_1D_Word(2**nL-1 downto 0);
	Do			=> sgn_Ch_o,--(io): out	std_logic_vector(gcst_WW-1 downto 0);
	Sel		=> sgn_Sel,--: in	std_logic_vector(nL-1 downto 0);
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

i0200: for i in 0 to Size_Ram-1 generate
	sgn_Addr(i) <= conv_std_logic_vector(i, Size_Ram_Expo);
end generate i0200;

i0500: for i in 0 to Size_Ram-1 generate
	i0510: for j in 0 to Size_Ram_Expo-1 generate
		sgn_Addr_Tr(j)(i) <= sgn_Addr(i)(j);
	end generate i0510;
end generate i0500;

i0400: for i in 0 to Size_Ram_Expo-1 generate
	insto3:Lg_Mux_nL1b_T2
	port map(
		Di			=> sgn_Addr_Tr(i),--: in	typ_1D_Word(2**nL-1 downto 0);
		Do			=> sgn_Addr_o(i),--(io): out	std_logic_vector(gcst_WW-1 downto 0);
		Sel		=> sgn_Sel,--: in	std_logic_vector(nL-1 downto 0);
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0400;

inst04: Lg_BoolOpt
port map(
	Di			=> sgn_Sel,--: in	std_logic_vector(2**nL-1 downto 0);
	Do			=> sgn_Flag_o,--: out	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

process(clk,aclr)
begin
	if(aclr = '1')then
	elsif(rising_edge(clk))then
		Ch_o <= sgn_Ch_o;
		sgn_Ch_o_syn <= sgn_Ch_o;
		Addr_o <= sgn_Addr_o;
		Flag_o <= sgn_Flag_o;
		sgn_Flag_o_syn <= sgn_Flag_o;
	end if;
end process;

-- channel result compare
i0300: for i in 0 to Num_Ch-1 generate
	sgn_cmp(i) <= '1' when (unsigned(sgn_Ch_o_syn)=i and sgn_Flag_o_syn='1') else
					  '0';
end generate i0300;

-- msk xor
--process(aclr, clk)
--begin
--	if(aclr = '1')then
--		Msk_o <= (others => '0');
--	elsif(rising_edge(clk))then
		Msk_o <= sgn_Msk_DL(cst_Msk_DL-1) xor sgn_cmp;
--	end if;
--end process;

-- Msk ch value delay
sgn_Msk <= Msk_i;
sgn_Ch <= Ch_i;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Msk_DL <= (others => (others => '0'));
		sgn_Ch_DL <= (others => (others => (others => '0')));
	elsif(rising_edge(clk))then
		sgn_Msk_DL(0) <= sgn_Msk; -- (io)
		for i in 1 to cst_Msk_DL-1 loop -- 7
			sgn_Msk_DL(i) <= sgn_Msk_DL(i-1);
		end loop;
		sgn_Ch_DL(0) <= sgn_Ch; -- (io)
		for i in 1 to cst_Ch_DL-1 loop -- 2
			sgn_Ch_DL(i) <= sgn_Ch_DL(i-1);
		end loop;
	end if;
end process;

end rtl;
