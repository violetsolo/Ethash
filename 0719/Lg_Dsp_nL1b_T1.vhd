----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Lg_Dsp_nL1b_T1 - Behavioral
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

entity Lg_Dsp_nL1b_T1 is
generic(
	nL					: Positive := 3;
	Syn				: string := "true" -- "true" "false"
);
port (
	Di			: in	std_logic;
	Do			: out	std_logic_vector(2**nL-1 downto 0);
	Sel		: in	std_logic_vector(nL-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Lg_Dsp_nL1b_T1;

architecture rtl of Lg_Dsp_nL1b_T1 is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_Mux		: std_logic_vector(2**(nL+1)-2 downto 0);

type typ_Sel		is array (natural range<>) of std_logic_vector(nL-1 downto 0);
signal sgn_Sel		: typ_Sel(nL-1 downto 0);
--============================ function declare ============================--

begin

sgn_Mux(2**(nL+1)-2) <= Di;

i0300: for i in 0 to nL-1 generate
	i0310: if(i=0)generate
		sgn_Sel(0) <= Sel;
	end generate i0310;
	i0320: if(i/=0)generate
		process(clk,aclr)
		begin
			if(aclr='1')then
				sgn_Sel(i) <= (others => '0');
			elsif(rising_edge(clk))then
				sgn_Sel(i) <= sgn_Sel(i-1);
			end if;
		end process;
	end generate i0320;
end generate i0300;

t01: if (Syn = "true") generate
	i0100: for i in 0 to nL-1 generate
		i0110: for j in 0 to 2**(nL-1-i)-1 generate
			process(clk, aclr)
			begin
				if(aclr = '1')then
					sgn_Mux(j*2+  (2**(nL+1)-2**(nL-i+1))) <= '0';
					sgn_Mux(j*2+1+(2**(nL+1)-2**(nL-i+1))) <= '0';
				elsif(rising_edge(clk))then
					sgn_Mux(j*2+  (2**(nL+1)-2**(nL-i+1))) <= sgn_Mux(j+(2**(nL+1)-2**(nL-i))) and (not Sel(i));
					sgn_Mux(j*2+1+(2**(nL+1)-2**(nL-i+1))) <= sgn_Mux(j+(2**(nL+1)-2**(nL-i))) and (    Sel(i));
				end if;
			end process;
		end generate i0110;
	end generate i0100;
end generate t01;

t02: if (Syn = "false") generate
	i0100: for i in 0 to nL-1 generate
		i0110: for j in 0 to 2**(nL-1-i)-1 generate
			sgn_Mux(j*2+  (2**(nL+1)-2**(nL-i+1))) <= sgn_Mux(j+(2**(nL+1)-2**(nL-i))) and (not Sel(i));
			sgn_Mux(j*2+1+(2**(nL+1)-2**(nL-i+1))) <= sgn_Mux(j+(2**(nL+1)-2**(nL-i))) and (    Sel(i));
		end generate i0110;
	end generate i0100;
end generate t02;

i0200: for i in 0 to 2**nL-1 generate
	Do(i) <= sgn_Mux(i);
end generate i0200;

end rtl;
