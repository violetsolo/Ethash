----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid_pkg - pakage
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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_arith.all;

library work;

package Ethash_AcsMid_pkg is
--constants
constant gcst_AM_WidthData		: Positive := 256; -- word width
constant gcst_AM_SelDL			: Positive := 3;
constant gcst_AM_SelORamDL		: Positive := 4;
--types

--type typ_1D_stdv		is array (natural range<>) of std_logic_vector(natural range<>);
type typ_AM_1D_Data		is array (natural range<>) of std_logic_vector(gcst_AM_WidthData-1 downto 0);

end package;

PACKAGE BODY Ethash_AcsMid_pkg IS


END Ethash_AcsMid_pkg;