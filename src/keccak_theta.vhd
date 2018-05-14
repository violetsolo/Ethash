----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    05/04/2018 
-- Design Name: 
-- Module Name:    keccak_theta - Behavioral
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

entity keccak_theta is
port (
    theta_in    : in  k_state;
	 sum_sheet	 : in  k_plane;
    theta_out   : out k_state;
	 
	 clk			: in	std_logic
);
end keccak_theta;

architecture rtl of keccak_theta is
  ----------------------------------------------------------------------------
  -- Internal signal declarations
  ----------------------------------------------------------------------------
--  signal theta_in_d1		: k_state;
--  signal sum_sheet: k_plane;
 
begin  -- Rtl

--theta

--compute sum of columns

--process(clk)
--begin
--	if(rising_edge(clk))then
--		i0101: for x in 0 to 4 loop
--			i0102: for i in 0 to 63 loop
--				sum_sheet(x)(i)<=theta_in(0)(x)(i) xor theta_in(1)(x)(i) xor theta_in(2)(x)(i) xor theta_in(3)(x)(i) xor theta_in(4)(x)(i);
--			end loop;	
--		end loop;
--		theta_in_d1<=theta_in;
--	end if;
--end process;

process(clk)
begin
	if(rising_edge(clk))then
		i0200: for y in 0 to 4 loop
			i0201: for x in 1 to 3 loop
				theta_out(y)(x)(0)<=theta_in(y)(x)(0) xor sum_sheet(x-1)(0) xor sum_sheet(x+1)(63);
				i0202: for i in 1 to 63 loop
					theta_out(y)(x)(i)<=theta_in(y)(x)(i) xor sum_sheet(x-1)(i) xor sum_sheet(x+1)(i-1);
				end loop;	
			end loop;
		end loop;

		i2001: for y in 0 to 4 loop
			theta_out(y)(0)(0)<=theta_in(y)(0)(0) xor sum_sheet(4)(0) xor sum_sheet(1)(63);
			i2021: for i in 1 to 63 loop
				theta_out(y)(0)(i)<=theta_in(y)(0)(i) xor sum_sheet(4)(i) xor sum_sheet(1)(i-1);
			end loop;	
		end loop;

		i2002: for y in 0 to 4 loop
			theta_out(y)(4)(0)<=theta_in(y)(4)(0) xor sum_sheet(3)(0) xor sum_sheet(0)(63);
			i2022: for i in 1 to 63 loop
				theta_out(y)(4)(i)<=theta_in(y)(4)(i) xor sum_sheet(3)(i) xor sum_sheet(0)(i-1);
			end loop;	
		end loop;
	end if;
end process;

end rtl;
