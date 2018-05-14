----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    05/04/2018 
-- Design Name: 
-- Module Name:    keccak_RC_gen - Behavioral
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
	
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;	

entity keccak_RC_gen is
port(
    Rn		: in natural range 0 to 31;
    RC		: out std_logic_vector(N-1 downto 0);
	 
	 clk		: in	std_logic
);
end keccak_RC_gen;

architecture rtl of keccak_RC_gen is
  ----------------------------------------------------------------------------
  -- Internal signal declarations
  ----------------------------------------------------------------------------
 
begin  -- Rtl

round_constants : process (clk)
begin
	if(rising_edge(clk))then
		case Rn is
			when 0 => RC <= X"0000000000000001" ;
			when 1 => RC <= X"0000000000008082" ;
			when 2 => RC <= X"800000000000808A" ;
			when 3 => RC <= X"8000000080008000" ;
			when 4 => RC <= X"000000000000808B" ;
			when 5 => RC <= X"0000000080000001" ;
			when 6 => RC <= X"8000000080008081" ;
			when 7 => RC <= X"8000000000008009" ;
			when 8 => RC <= X"000000000000008A" ;
			when 9 => RC <= X"0000000000000088" ;
			when 10 => RC <= X"0000000080008009" ;
			when 11 => RC <= X"000000008000000A" ;
			when 12 => RC <= X"000000008000808B" ;
			when 13 => RC <= X"800000000000008B" ;
			when 14 => RC <= X"8000000000008089" ;
			when 15 => RC <= X"8000000000008003" ;
			when 16 => RC <= X"8000000000008002" ;
			when 17 => RC <= X"8000000000000080" ;
			when 18 => RC <= X"000000000000800A" ;
			when 19 => RC <= X"800000008000000A" ;
			when 20 => RC <= X"8000000080008081" ;
			when 21 => RC <= X"8000000000008080" ;
			when 22 => RC <= X"0000000080000001" ;
			when 23 => RC <= X"8000000080008008" ;	    	    
			when others => RC <=(others => '0');
	end case;
	end if;
end process round_constants;

end rtl;
