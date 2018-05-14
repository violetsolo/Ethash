----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    05/04/2018 
-- Design Name: 
-- Module Name:    keccak_chi_iota - Behavioral
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

entity keccak_chi_iota is
port (
    chi_in		: in  k_state;
	 RC			: in std_logic_vector(N-1 downto 0);
    iota_out	: out k_state;
	 
	 clk			: in	std_logic
);
end keccak_chi_iota;

architecture rtl of keccak_chi_iota is
  ----------------------------------------------------------------------------
  -- Internal signal declarations
  ----------------------------------------------------------------------------
 signal chi_out,iota_in : k_state;
begin  -- Rtl

--connecitons

--order chi, iota
iota_in <= chi_out;
iota_out <= iota_in;

--chi
process(clk)
begin
	if(rising_edge(clk))then
		i0000: for y in 0 to 4 loop
			i0001: for x in 0 to 2 loop
				if(x=0 and y=0)then
					i0002rc: for i in 0 to 63 loop
						chi_out(y)(x)(i)<=chi_in(y)(x)(i) xor  ( not(chi_in (y)(x+1)(i))and chi_in (y)(x+2)(i)) xor RC(i); -- ito
					end loop;
				else
					i0002: for i in 0 to 63 loop
						chi_out(y)(x)(i)<=chi_in(y)(x)(i) xor  ( not(chi_in (y)(x+1)(i))and chi_in (y)(x+2)(i));
					end loop;
				end if;
			end loop;
		end loop;

			i0011: for y in 0 to 4 loop
				i0021: for i in 0 to 63 loop
					chi_out(y)(3)(i)<=chi_in(y)(3)(i) xor  ( not(chi_in (y)(4)(i))and chi_in (y)(0)(i));
				end loop;	
			end loop;
			
			i0012: for y in 0 to 4 loop
				i0022: for i in 0 to 63 loop
					chi_out(y)(4)(i)<=chi_in(y)(4)(i) xor  ( not(chi_in (y)(0)(i))and chi_in (y)(1)(i));
				end loop;	
			end loop;
			
	end if;
end process;

end rtl;
