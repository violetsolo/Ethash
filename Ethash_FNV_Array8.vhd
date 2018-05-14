------------------------------------------------------------------------------------
---- Company: 
---- Engineer: 		Logotorix
---- 
---- Create Date:    08/04/2018 
---- Design Name: 
---- Module Name:    Ethash_FNV_Array8 - Behavioral
---- Project Name: 
---- Target Devices: 
---- Tool versions: 
---- Description: 
----
---- Dependencies: 
----
---- Revision: 
----
---- Additional Comments: 
----
------------------------------------------------------------------------------------
--
--library ieee;
--use ieee.std_logic_1164.all;
--use ieee.std_logic_arith.all;	
--
--library work;
--use work.keccak_globals.all;
--use work.Ethash_pkg.all;
--
--entity Ethash_FNV_Array8 is
--generic(
--	di_Num			: Positive := 128; -- fixed
--	do_Num			: Positive := 32 -- fixed
--);
--port (
--	di			: in	typ_1D_Word(di_Num-1 downto 0); -- must be hold outside
--	do			: out	typ_1D_Word(do_Num-1 downto 0);
--	
--	clk		: in	std_logic;
--	aclr		: in	std_logic
--);
--end Ethash_FNV_Array8;
--
--architecture rtl of Ethash_FNV_Array8 is
----============================ constant declare ============================--
---- cst_WW = 8
--constant cst_SectSize		: Positive := 4;
--constant cst_FNV_DW			: Positive := 4;
--constant cst_SectNum			: Positive := di_Num/cst_SectSize/cst_FNV_DW; -- 8
----======================== Altera component declare ========================--
--
----===================== user-defined component declare =====================--
--component Ethash_FNV
--generic(
--	data_width		: Positive := cst_FNV_DW * cst_WW -- 8*4=32
--);
--port (
--	v1		: in	std_logic_vector(data_width-1 downto 0);
--	v2		: in	std_logic_vector(data_width-1 downto 0);
--	o		: out	std_logic_vector(data_width-1 downto 0);
--	
--	clk	: in	std_logic;
--	aclr	: in	std_logic
--	 );
--end component;
----============================= signal declare =============================--
--type typ_1D_4Word is array (0 to cst_SectNum-1) of std_logic_vector(cst_FNV_DW * cst_WW-1 downto 0);
--signal sgn_FNV1_v1, sgn_FNV1_v2, sgn_FNV1_o		: typ_1D_4Word;
--signal sgn_FNV2_v1, sgn_FNV2_v2, sgn_FNV2_o		: typ_1D_4Word;
--signal sgn_FNV3_v1, sgn_FNV3_v2, sgn_FNV3_o		: typ_1D_4Word;
--
--type typ_2D_4Word is array (natural range<>, natural range<>) of std_logic_vector(cst_FNV_DW * cst_WW-1 downto 0);
--signal sgn_FNV2_v2_DL		: typ_2D_4Word(cst_FNVDL-1 downto 0, cst_SectNum-1 downto 0);
--signal sgn_FNV3_v2_DL		: typ_2D_4Word(cst_FNVDL*2-1 downto 0, cst_SectNum-1 downto 0);
--
----============================ function declare ============================--
--
--begin
--
--i0100: for i in 0 to cst_SectNum-1 generate -- 8
--	sgn_FNV1_v1(i) <= di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*0 + 3) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*0 + 2) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*0 + 1) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*0 + 0);
--	sgn_FNV1_v2(i) <= di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*1 + 3) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*1 + 2) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*1 + 1) & 
--							di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*1 + 0);
--							
--	sgn_FNV2_v1(i) <= sgn_FNV1_o(i);
--	
--	process(clk,aclr)
--	begin
--		if(aclr = '1')then
--			for j in 0 to cst_FNVDL-1 loop
--				sgn_FNV2_v2_DL(j,i) <= (others => '0');
--			end loop;
--		elsif(rising_edge(clk))then
--			sgn_FNV2_v2_DL(0,i) <= di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*2 + 3) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*2 + 2) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*2 + 1) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*2 + 0);
--			for j in 1 to cst_FNVDL-1 loop
--				sgn_FNV2_v2_DL(j,i) <= sgn_FNV2_v2_DL(j-1,i);
--			end loop;
--		end if;
--	end process;
--	sgn_FNV2_v2(i) <= sgn_FNV2_v2_DL(cst_FNVDL-1,i);
--							
--	sgn_FNV3_v1(i) <= sgn_FNV2_o(i);
--	process(clk,aclr)
--	begin
--		if(aclr = '1')then
--			for j in 0 to cst_FNVDL*2-1 loop
--				sgn_FNV3_v2_DL(j,i) <= (others => '0');
--			end loop;
--		elsif(rising_edge(clk))then
--			sgn_FNV3_v2_DL(0,i) <= di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*3 + 3) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*3 + 2) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*3 + 1) & 
--											di(cst_SectSize*cst_FNV_DW*i + cst_FNV_DW*3 + 0);
--			for j in 1 to cst_FNVDL*2-1 loop
--				sgn_FNV3_v2_DL(j,i) <= sgn_FNV3_v2_DL(j-1,i);
--			end loop;
--		end if;
--	end process;
--	sgn_FNV3_v2(i) <= sgn_FNV3_v2_DL(cst_FNVDL*2-1,i);
--							
--	i0110: for j in 0 to cst_FNV_DW-1 generate
--		do(j + cst_FNV_DW*i) <= sgn_FNV3_o(i)(cst_WW*j + cst_WW-1 downto cst_WW*j + 0);
--	end generate i0110;
--	
--	inst00: Ethash_FNV
--	port map(
--		v1		=> sgn_FNV1_v1(i),--: in	std_logic_vector(data_width-1 downto 0);
--		v2		=> sgn_FNV1_v2(i),--: in	std_logic_vector(data_width-1 downto 0);
--		o		=> sgn_FNV1_o(i),--: out	std_logic_vector(data_width-1 downto 0);
--		
--		clk	=> clk,--: in	std_logic;
--		aclr	=> aclr--: in	std_logic
--	);
--	
--	inst01: Ethash_FNV
--	port map(
--		v1		=> sgn_FNV2_v1(i),--: in	std_logic_vector(data_width-1 downto 0);
--		v2		=> sgn_FNV2_v2(i),--: in	std_logic_vector(data_width-1 downto 0);
--		o		=> sgn_FNV2_o(i),--: out	std_logic_vector(data_width-1 downto 0);
--		
--		clk	=> clk,--: in	std_logic;
--		aclr	=> aclr--: in	std_logic
--	);
--	
--	inst02: Ethash_FNV
--	port map(
--		v1		=> sgn_FNV3_v1(i),--: in	std_logic_vector(data_width-1 downto 0);
--		v2		=> sgn_FNV3_v2(i),--: in	std_logic_vector(data_width-1 downto 0);
--		o		=> sgn_FNV3_o(i),--: out	std_logic_vector(data_width-1 downto 0);
--		
--		clk	=> clk,--: in	std_logic;
--		aclr	=> aclr--: in	std_logic
--	);
--
--end generate i0100;
--
--end rtl;


----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    08/04/2018 
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

entity Ethash_FNV_Array8 is
generic(
	di_Num			: Positive := 128; -- fixed
	do_Num			: Positive := 32; -- fixed
	FNV_DW			: Positive := 4
);
port (
	Prime		: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	di			: in	typ_1D_Word(di_Num-1 downto 0); -- must be hold outside
	do			: out	typ_1D_Word(do_Num-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_FNV_Array8;

architecture rtl of Ethash_FNV_Array8 is
--============================ constant declare ============================--
constant cst_SectSize		: Positive := 4 * FNV_DW; -- 16
constant cst_SectNum			: Positive := di_Num/cst_SectSize; -- 8

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_FNV_Tri
generic(
	FNV_DW			: Positive := FNV_DW -- fixed
);
port (
	Prime		: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	a			: in	typ_1D_Word(FNV_DW-1 downto 0);
	b			: in	typ_1D_Word(FNV_DW-1 downto 0);
	c			: in	typ_1D_Word(FNV_DW-1 downto 0);
	d			: in	typ_1D_Word(FNV_DW-1 downto 0);
	o			: out	typ_1D_Word(FNV_DW-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--

--============================ function declare ============================--

begin

i0100: for i in 0 to cst_SectNum-1 generate -- 8
	inst00: Ethash_FNV_Tri
	port map(
		Prime		=> Prime,--: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
		a			=> di(cst_SectSize*i+FNV_DW*1-1 downto cst_SectSize*i+FNV_DW*0),--: in	typ_1D_Word(FNV_DW-1 downto 0);
		b			=> di(cst_SectSize*i+FNV_DW*2-1 downto cst_SectSize*i+FNV_DW*1),--: in	typ_1D_Word(FNV_DW-1 downto 0);
		c			=> di(cst_SectSize*i+FNV_DW*3-1 downto cst_SectSize*i+FNV_DW*2),--: in	typ_1D_Word(FNV_DW-1 downto 0);
		d			=> di(cst_SectSize*i+FNV_DW*4-1 downto cst_SectSize*i+FNV_DW*3),--: in	typ_1D_Word(FNV_DW-1 downto 0);
		o			=> do(FNV_DW*i+FNV_DW-1 downto FNV_DW*i+0),--: out	typ_1D_Word(FNV_DW-1 downto 0);
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);

end generate i0100;

end rtl;
