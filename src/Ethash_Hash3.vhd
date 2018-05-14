----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    08/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hash3 - Behavioral
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
library work;
use work.keccak_globals.all;
use work.Ethash_pkg.all;
	
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;	

entity Ethash_Hash3 is
generic(
	di_Num			: Positive := 200;-- fixed
	do_Num			: Positive := 64; -- fixed
	PP_Lattic		: Positive := 4 -- must be 1 2 3 4 6 8 12 24 
);
port (
	di			: in	typ_1D_Word(di_Num-1 downto 0);
	do			: out	typ_1D_Word(do_Num-1 downto 0);
	Typ		: in	typ_Hash;
	Num		: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			: in	std_logic;
	Ed			: out	std_logic;
	pEd		: out std_logic;
	ppEd		: out	std_logic;
	Bsy		: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_Hash3;

architecture rtl of Ethash_Hash3 is
--============================ constant declare ============================--
constant cst_rNum_H512		: Positive := 72;
constant cst_rNum_H256		: Positive := 136;
constant cst_KNum			: Positive := KNum_Org / PP_Lattic;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component keccak_core
generic(
	KNum		: Positive := cst_KNum;
	PP_L		: Natural
);
port (
    di		: in  k_state;
    do		: out k_state;
	 
	 St		: in	std_logic;
	 Ed		: out	std_logic;
	 pEd		: out	std_logic;
	 ppEd		: out	std_logic;
	 Bsy		: out	std_logic;
	 
	 clk		: in	std_logic;
	 aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
type typ_Karray is array (PP_Lattic-1 downto 0) of k_state;
signal sgn_Keccak_di, sgn_Keccak_do		: typ_Karray;
--signal sgn_di									: typ_1D_stdv(di_Num-1 downto 0)(data_width-1 downto 0);
signal sgn_di									: typ_1D_Word(di_Num-1 downto 0);
signal sgn_St,sgn_Ed,sgn_Bsy, sgn_pEd,sgn_ppEd	: std_logic_vector(PP_Lattic-1 downto 0);
--============================ function declare ============================--

begin

i0100: for i in 0 to di_Num-1 generate
	process(clk, aclr)
		variable var_sel	: Natural range 0 to 4;
	begin
		if(aclr='1')then
			var_sel := 0;
		elsif(rising_edge(clk))then
			if (Typ = e_Hash256) then -- r = 136
				if(i>=cst_rNum_H256 or (i<cst_rNum_H256-1 and i>Num))then
					var_sel := 1;
				elsif(i=Num and Num < cst_rNum_H256-1)then
					var_sel := 2;
				elsif(i=cst_rNum_H256-1 and Num < cst_rNum_H256-1)then
					var_sel := 3;
				elsif(i=cst_rNum_H256-1 and Num >= cst_rNum_H256-1)then
					var_sel := 4;
				else
					var_sel := 0;
				end if;
			elsif(Typ = e_Hash512)then -- r = 72
				if(i>=cst_rNum_H512 or (i<cst_rNum_H512-1 and i>Num))then
					var_sel := 1;
				elsif(i=Num and Num < cst_rNum_H512-1)then
					var_sel := 2;
				elsif(i=cst_rNum_H512-1 and Num < cst_rNum_H512-1)then
					var_sel := 3;
				elsif(i=cst_rNum_H512-1 and Num >= cst_rNum_H512-1)then
					var_sel := 4;
				else
					var_sel := 0;
				end if;
			else
				var_sel := 0;
			end if;
			
			case var_sel is
				when 0 => sgn_di(i) <= di(i);
				when 1 => sgn_di(i) <= x"00";
				when 2 => sgn_di(i) <= x"01";
				when 3 => sgn_di(i) <= x"80";
				when 4 => sgn_di(i) <= x"81";
			end case;
		end if;
	end process;
end generate i0100;

process(clk, aclr)
begin
	if(aclr='1')then
		sgn_St(0) <= '0';
	elsif(rising_edge(clk))then
		sgn_St(0) <= St;
	end if;
end process;

i0200: for i in 0 to di_Num-1 generate
	i0210: for j in 0 to gcst_WW-1 generate
		sgn_Keccak_di(0)(i/(gcst_WW*5))((i/gcst_WW) mod 5)((i mod gcst_WW)*gcst_WW + j) <= sgn_di(i)(j);
	end generate i0210;
end generate i0200;

-- keccak
i0300: for i in 0 to PP_Lattic-1 generate
	inst01: keccak_core
	generic map(
		PP_L => i
	)
	port map(
		 di		=> sgn_Keccak_di(i),--: in  k_state;
		 do		=> sgn_Keccak_do(i),--: out k_state;
		 
		 St		=> sgn_St(i),--: in	std_logic;
		 Ed		=> sgn_Ed(i),--: out	std_logic;
		 pEd		=> sgn_pEd(i),--: out	std_logic;
		 ppEd		=> sgn_ppEd(i),--: out	std_logic;
		 Bsy		=> sgn_Bsy(i),--: out	std_logic;
		 
		 clk		=> clk,--: in	std_logic;
		 aclr		=> aclr--: in	std_logic
	);
end generate i0300;

i1300: if (PP_Lattic/=1) generate
	i1310: for i in 1 to PP_Lattic-1 generate
		sgn_St(i) <= sgn_Ed(i-1);
		sgn_Keccak_di(i) <= sgn_Keccak_do(i-1);
	end generate i1310;
end generate i1300;

Ed <= sgn_Ed(PP_Lattic-1);
pEd <= sgn_pEd(PP_Lattic-1);
ppEd <= sgn_ppEd(PP_Lattic-1);
Bsy <= sgn_Bsy(0);

-- output connecitons
i0400: for i in 0 to do_Num-1 generate
	i0410: for j in 0 to gcst_WW-1 generate
		do(i)(j) <= sgn_Keccak_do(PP_Lattic-1)(i/(gcst_WW*5))((i/gcst_WW) mod 5)((i mod gcst_WW)*gcst_WW + j);
	end generate i0410;
end generate i0400;

end rtl;
