----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    23/04/2018 
-- Design Name: 
-- Module Name:    Ethash_FNV_Array8 - Behavioral
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
use work.keccak_globals.all;
use work.Ethash_pkg.all;

entity Ethash_FNV_Tri is
generic(
	FNV_DW			: Positive := 4 -- fixed
);
port (
	Prime		: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	
	a			: in	typ_1D_Word(FNV_DW-1 downto 0);
	b			: in	typ_1D_Word(FNV_DW-1 downto 0);
	c			: in	typ_1D_Word(FNV_DW-1 downto 0);
	d			: in	typ_1D_Word(FNV_DW-1 downto 0);
	o			: out	typ_1D_Word(FNV_DW-1 downto 0);
	
	clk		: in	std_logic
);
end Ethash_FNV_Tri;

architecture rtl of Ethash_FNV_Tri is
--============================ constant declare ============================--
constant cst_DL		: Positive := gcst_FNVDL*2+1;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_FNV
generic(
	data_width		: Positive := FNV_DW * gcst_WW -- 8*4=32
);
port (
	Prime	: in	std_logic_vector(data_width-1 downto 0);
	
	v1		: in	std_logic_vector(data_width-1 downto 0);
	v2		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic
	 );
end component;
--============================= signal declare =============================--
signal sgn_FNV1_v1, sgn_FNV1_v2, sgn_FNV1_o		: std_logic_vector(FNV_DW * gcst_WW-1 downto 0);
signal sgn_FNV2_v1, sgn_FNV2_v2, sgn_FNV2_o		: std_logic_vector(FNV_DW * gcst_WW-1 downto 0);
signal sgn_FNV3_v1, sgn_FNV3_v2, sgn_FNV3_o		: std_logic_vector(FNV_DW * gcst_WW-1 downto 0);

type typ_1D_4Word is array (natural range<>) of std_logic_vector(FNV_DW * gcst_WW-1 downto 0);
signal sgn_FNV2_v2_DL		: typ_1D_4Word(gcst_FNVDL-1 downto 0);
signal sgn_FNV3_v2_DL		: typ_1D_4Word(gcst_FNVDL*2-1 downto 0);

--============================ function declare ============================--

begin

-- step 1
sgn_FNV1_v1 <= a(3) & a(2) & a(1) & a(0);
sgn_FNV1_v2 <= b(3) & b(2) & b(1) & b(0);

inst00: Ethash_FNV
port map(
	Prime	=> Prime,--: in	std_logic_vector(data_width-1 downto 0);
	v1		=> sgn_FNV1_v1,--: in	std_logic_vector(data_width-1 downto 0);
	v2		=> sgn_FNV1_v2,--: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_FNV1_o,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk--: in	std_logic;
);

-- step 2
sgn_FNV2_v1 <= sgn_FNV1_o;

process(clk)
begin
	if(rising_edge(clk))then
		sgn_FNV2_v2_DL(0) <= c(3) & c(2) & c(1) & c(0);
		for j in 1 to gcst_FNVDL-1 loop
			sgn_FNV2_v2_DL(j) <= sgn_FNV2_v2_DL(j-1);
		end loop;
	end if;
end process;
sgn_FNV2_v2 <= sgn_FNV2_v2_DL(gcst_FNVDL-1);
inst01: Ethash_FNV
port map(
	Prime	=> Prime,--: in	std_logic_vector(data_width-1 downto 0);
	v1		=> sgn_FNV2_v1,--: in	std_logic_vector(data_width-1 downto 0);
	v2		=> sgn_FNV2_v2,--: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_FNV2_o,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk--: in	std_logic;
);

-- step 3
sgn_FNV3_v1 <= sgn_FNV2_o;
process(clk)
begin
	if(rising_edge(clk))then
		sgn_FNV3_v2_DL(0) <= d(3) & d(2) & d(1) & d(0);
		for j in 1 to gcst_FNVDL*2-1 loop
			sgn_FNV3_v2_DL(j) <= sgn_FNV3_v2_DL(j-1);
		end loop;
	end if;
end process;
sgn_FNV3_v2 <= sgn_FNV3_v2_DL(gcst_FNVDL*2-1);

inst02: Ethash_FNV
port map(
	Prime	=> Prime,--: in	std_logic_vector(data_width-1 downto 0);
	v1		=> sgn_FNV3_v1,--: in	std_logic_vector(data_width-1 downto 0);
	v2		=> sgn_FNV3_v2,--: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_FNV3_o,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk--: in	std_logic;
);

-- output
	
i0110: for j in 0 to FNV_DW-1 generate
	o(j) <= sgn_FNV3_o(gcst_WW*j + gcst_WW-1 downto gcst_WW*j + 0);
end generate i0110;

end rtl;
