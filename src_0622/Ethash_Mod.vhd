----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    01/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Mod - Behavioral
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

entity Ethash_Mod is
generic(
	data_width		: Positive	:= 32;
	sft_num			: Natural	:= 6
);
port (
	a		: in	std_logic_vector(data_width-1 downto 0);
	b		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic
);
end Ethash_Mod;

architecture rtl of Ethash_Mod is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
type typ_sub_arr	is array(sft_num+1 downto 0) of std_logic_vector(data_width-1 downto 0);
signal sgn_a		: typ_sub_arr;
signal sgn_b		: typ_sub_arr;

--============================ function declare ============================--
function Mod_sub(signal a, b : std_logic_vector; n : Natural) return std_logic_vector is
	variable b1				: std_logic_vector(b'length-1 downto 0);
	variable c				: std_logic_vector(b'length-1 downto 0);
begin
	b1(b'length-1 downto n) := b(b'length-n-1 downto 0);
	if(n /= 0)then
		b1(n-1 downto 0) := (others => '0');
	end if;
	if ( ((n = 0) or 
			(unsigned(b(b'length-1 downto b'length-n)) = 0)
		  ) and
		  (unsigned(a) >= unsigned(b1))
		) then
		c := unsigned(a) - unsigned(b1);
	else
		c := a;
	end if;
	return c;
end Mod_sub;

begin
--
sgn_b(0) <= b;
sgn_a(0) <= a;

i0100: for i in 0 to sft_num generate
	process(clk)
	begin
		if (rising_edge(clk)) then
			sgn_a(i+1) <= Mod_sub(sgn_a(i), sgn_b(i), sft_num - i);
			sgn_b(i+1) <= sgn_b(i);
		end if;
	end process;
end generate i0100;

o <= sgn_a(sft_num+1);

end rtl;