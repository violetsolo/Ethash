----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    01/04/2018 
-- Design Name: 
-- Module Name:    Lg_Latch - Behavioral
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

entity Lg_Latch is
generic(
	d_width			: Positive := 8
);
port (
	di			: in	std_logic_vector(d_width-1 downto 0);
	do			: out	std_logic_vector(d_width-1 downto 0);
	Latch		: in	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Lg_Latch;

architecture rtl of Lg_Latch is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--

--============================ function declare ============================--

begin

process(clk, aclr)
begin
	if(aclr = '1')then
		do <= (others => '0');
	elsif(rising_edge(clk))then
		if(Latch = '1')then
			do <= di;
		end if;
	end if;
end process;

end rtl;
