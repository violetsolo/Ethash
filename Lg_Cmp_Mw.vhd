----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    16/04/2018 
-- Design Name: 
-- Module Name:    Lg_Cmp_Mw - Behavioral
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

entity Lg_Cmp_Mw is
generic(
	d_Num			: Positive := 4;
	Typ_Cmp		: string := "S" -- "Larger"="L", "Larger equal"="LE", "Small"="S", "Small equal"="SE", "equal"="E"
);
port (
	a			: in	typ_1D_Word(d_Num-1 downto 0);
	b			: in	typ_1D_Word(d_Num-1 downto 0);
	Res		: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Lg_Cmp_Mw;

architecture rtl of Lg_Cmp_Mw is
--============================ constant declare ============================--
--constant cst_DL		: Positive := 3;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_isEq, sgn_CmpRes		: std_logic_vector(d_Num-1 downto 0);
signal sgn_Msk, sgn_CmpRes_DL		: std_logic_vector(d_Num-1 downto 0);
signal sgn_Res							: std_logic_vector(d_Num-1 downto 0);
signal sgn_Eq							: std_logic;
--============================ function declare ============================--

begin

i0100: for i in 0 to d_Num-1 generate
	process(clk, aclr)
	begin
		if(aclr='1')then
			sgn_isEq(i) <= '0';
		elsif(rising_edge(clk))then
			if(unsigned(a(i)) = unsigned(b(i))) then
				sgn_isEq(i) <= '0'; -- a=b
			else
				sgn_isEq(i) <= '1'; -- a/=b
			end if;
		end if;
	end process;
	-- larger
	g0110: if (Typ_Cmp="L")generate
		process(clk, aclr)
		begin
			if(aclr='1')then
				sgn_CmpRes(i) <= '0';
			elsif(rising_edge(clk))then
				if(unsigned(a(i)) > unsigned(b(i)))then
					sgn_CmpRes(i) <= '1'; -- a > b;
				else
					sgn_CmpRes(i) <= '0';
				end if;
			end if;
		end process;
	end generate g0110;
	-- larger equal
	g0120: if (Typ_Cmp="LE")generate
		process(clk, aclr)
		begin
			if(aclr='1')then
				sgn_CmpRes(i) <= '0';
			elsif(rising_edge(clk))then
				if(unsigned(a(i)) >= unsigned(b(i)))then
					sgn_CmpRes(i) <= '1'; -- a > b;
				else
					sgn_CmpRes(i) <= '0';
				end if;
			end if;
		end process;
	end generate g0120;
	-- small
	g0130: if (Typ_Cmp="S")generate
		process(clk, aclr)
		begin
			if(aclr='1')then
				sgn_CmpRes(i) <= '0';
			elsif(rising_edge(clk))then
				if(unsigned(a(i)) < unsigned(b(i)))then
					sgn_CmpRes(i) <= '1'; -- a > b;
				else
					sgn_CmpRes(i) <= '0';
				end if;
			end if;
		end process;
	end generate g0130;
	-- small equal
	g0140: if (Typ_Cmp="SE")generate
		process(clk, aclr)
		begin
			if(aclr='1')then
				sgn_CmpRes(i) <= '0';
			elsif(rising_edge(clk))then
				if(unsigned(a(i)) <= unsigned(b(i)))then
					sgn_CmpRes(i) <= '1'; -- a > b;
				else
					sgn_CmpRes(i) <= '0';
				end if;
			end if;
		end process;
	end generate g0140;
	-- equal
	g0150: if (Typ_Cmp="E")generate
		process(clk, aclr)
		begin
			if(aclr='1')then
				sgn_CmpRes(i) <= '0';
			elsif(rising_edge(clk))then
				if(unsigned(a(i)) = unsigned(b(i)))then
					sgn_CmpRes(i) <= '1'; -- a > b;
				else
					sgn_CmpRes(i) <= '0';
				end if;
			end if;
		end process;
	end generate g0150;
end generate i0100;

i0200: for i in 0 to d_Num-2 generate
	process(clk, aclr)
	begin
		if(aclr='1')then
			sgn_Msk(i) <= '0';
			sgn_CmpRes_DL(i) <= '0';
		elsif(rising_edge(clk))then
			if(unsigned(sgn_isEq(d_Num-1 downto i+1)) = 0 and sgn_isEq(i) = '1')then
				sgn_Msk(i) <= '1';
			else
				sgn_Msk(i) <= '0';
			end if;
			sgn_CmpRes_DL(i) <= sgn_CmpRes(i);
		end if;
	end process;
end generate i0200;
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_Msk(d_Num-1) <= '0';
		sgn_CmpRes_DL(d_Num-1) <= '0';
	elsif(rising_edge(clk))then
		sgn_Msk(d_Num-1) <= sgn_isEq(d_Num-1);
		sgn_CmpRes_DL(d_Num-1) <= sgn_CmpRes(d_Num-1);
	end if;
end process;

sgn_Res <= sgn_Msk and sgn_CmpRes_DL;
g0300: if(Typ_Cmp="L" or Typ_Cmp="S")generate
	sgn_Eq <= '0';
end generate g0300;
g0400: if(Typ_Cmp="LE" or Typ_Cmp="SE" or Typ_Cmp="E")generate
	process(clk, aclr)
	begin
		if(aclr='1')then
			sgn_Eq <= '0';
		elsif(rising_edge(clk))then
			if(unsigned(sgn_isEq) = 0)then
				sgn_Eq <= '1';
			else
				sgn_Eq <= '0';
			end if;
		end if;
	end process;
end generate g0400;

process(clk,aclr)
begin
	if(aclr='1')then
		Res <= '0';
	elsif(rising_edge(clk))then
--		if(sgn_Res=conv_std_logic_vector(0,d_Num-1) and sgn_Eq='0')then
		if(unsigned(sgn_Res)=0 and sgn_Eq='0')then
			Res <= '0';
		else
			Res <= '1';
		end if;
	end if;
end process;

end rtl;
