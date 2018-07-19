----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    01/04/2018 
-- Design Name: 
-- Module Name:    Ethash_pkg - pakage
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

package Ethash_pkg is
--constants
constant gcst_WW		: Positive := 8; -- word width
constant gcst_FNVDL	: Positive := 3;
constant gcst_AW		: Positive := 4; -- addr word number
constant gcst_IDW		: Positive := 1; -- addr word number

constant gAttribut_maxFanout	: Natural := 32;
constant gcst_MaxWidth_RamPort	: Natural := 32;
--types

type typ_Hash			is (e_Hash512, e_Hash256);
--type typ_1D_stdv		is array (natural range<>) of std_logic_vector(natural range<>);
type typ_1D_Word		is array (natural range<>) of std_logic_vector(gcst_WW-1 downto 0);
type typ_1D_Nat		is array (natural range<>) of Natural;

type typ_InfoSocket is record
	i	: std_logic_vector(gcst_WW-1 downto 0); -- index of i (round)
	ID	: std_logic_vector(gcst_IDW*gcst_WW-1 downto 0); -- index of nonce / DAG_j
	S0	: std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- S0/DAG_j
	inst	: std_logic_vector(gcst_WW-1 downto 0); -- index of inst
end record typ_InfoSocket;

-- all purpose funtion

function Fnc_Int2Wd(W : Natural) return NATURAL;

end package;


--
PACKAGE BODY Ethash_pkg IS

function Fnc_Int2Wd(W : Natural) return NATURAL IS
	variable A : STD_LOGIC_VECTOR(31 DOWNTO 0);
begin
	A := CONV_STD_LOGIC_VECTOR(W,32);
	IF (A(31) = '1') THEN
		return 32;
	ELSIF (A(30) = '1') THEN
		return 31;
	ELSIF (A(29) = '1') THEN
		return 30;
	ELSIF (A(28) = '1') THEN
		return 29;
	ELSIF (A(27) = '1') THEN
		return 28;
	ELSIF (A(26) = '1') THEN
		return 27;
	ELSIF (A(25) = '1') THEN
		return 26;
	ELSIF (A(24) = '1') THEN
		return 25;
	ELSIF (A(23) = '1') THEN
		return 24;
	ELSIF (A(22) = '1') THEN
		return 23;
	ELSIF (A(21) = '1') THEN
		return 22;
	ELSIF (A(20) = '1') THEN
		return 21;
	ELSIF (A(19) = '1') THEN
		return 20;
	ELSIF (A(18) = '1') THEN
		return 19;
	ELSIF (A(17) = '1') THEN
		return 18;
	ELSIF (A(16) = '1') THEN
		return 17;
	ELSIF (A(15) = '1') THEN
		return 16;
	ELSIF (A(14) = '1') THEN
		return 15;
	ELSIF (A(13) = '1') THEN
		return 14;
	ELSIF (A(12) = '1') THEN
		return 13;
	ELSIF (A(11) = '1') THEN
		return 12;
	ELSIF (A(10) = '1') THEN
		return 11;
	ELSIF (A(9) = '1') THEN
		return 10;
	ELSIF (A(8) = '1') THEN
		return 9;
	ELSIF (A(7) = '1') THEN
		return 8;
	ELSIF (A(6) = '1') THEN
		return 7;
	ELSIF (A(5) = '1') THEN
		return 6;
	ELSIF (A(4) = '1') THEN
		return 5;
	ELSIF (A(3) = '1') THEN
		return 4;
	ELSIF (A(2) = '1') THEN
		return 3;
	ELSIF (A(1) = '1') THEN
		return 2;
	ELSE
		return 1;
	END IF;
end Fnc_Int2Wd;

END Ethash_pkg;