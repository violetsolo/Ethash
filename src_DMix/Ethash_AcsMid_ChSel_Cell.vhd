----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    21/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid_ChSel_Cell - Behavioral
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

entity Ethash_AcsMid_ChSel_Cell is
generic(
	Num_Ch			: Positive := 32;
	Size_Ram			: Positive := 64;
	Idx_M				: Natural := 10 -- from 0 to Size_Ram-1
);
port (
	Flag		: in	std_logic;
	Ch			: in	std_logic_vector(gcst_WW-1 downto 0);
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	
	V_Mi		: in	std_logic_vector(Size_Ram-1 downto 0);
	V_Mo		: out	std_logic;
	
	Flag_Clr	: out	std_logic;
	Sel		: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_AcsMid_ChSel_Cell;

architecture rtl of Ethash_AcsMid_ChSel_Cell is
--============================ constant declare ============================--

--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Lg_BoolOpt
generic(
	nL					: Positive := Fnc_Int2Wd(Size_Ram-1);
	Typ				: string	:= "and"; -- "or" "and" "xor" "nor" "nand" "xnor"
	Syn				: string := "false" -- "true" "false"
);
port (
	Di			: in	std_logic_vector(2**nL-1 downto 0);
	Do			: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Mux_o		: std_logic;
signal sgn_Flag_DL	: std_logic;
signal sgn_Flag		: std_logic;
signal sgn_VM			: std_logic;

signal sgn_SelDL		: std_logic; -- delay 1 clk
signal sgn_Sel			: std_logic;

signal sgn_VMi			: std_logic_vector(Size_Ram-1 downto 0);
signal sgn_VM_res		: std_logic;
--============================ function declare ============================--

--=========================== attribute declare ============================--
attribute keep : boolean;
attribute keep of sgn_VMi : signal is true;
begin

-- Msk mux
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Mux_o <= '0';
	elsif(rising_edge(clk))then
		sgn_Mux_o <= Msk_i(conv_integer(unsigned(Ch)));
	end if;
end process;

-- flag delay
sgn_Flag <= Flag;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_Flag_DL <= '0';
	elsif(rising_edge(clk))then
		sgn_Flag_DL <= sgn_Flag;
	end if;
end process;

-- and operat
sgn_VM <= (not sgn_Mux_o) and sgn_Flag_DL and (not sgn_Sel) and (not sgn_SelDL);
V_Mo <= sgn_VM;

-- Logic
i0100: if(Idx_M = 0) generate
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_Sel <= '0';
		elsif(rising_edge(clk))then
			sgn_Sel <= V_Mi(Idx_M);
		end if;
	end process;
end generate i0100;

i0200: if(Idx_M /= 0 and Idx_M /= Size_Ram-1) generate
	sgn_VMi(Idx_M-1 downto 0) <= not V_Mi(Idx_M-1 downto 0);
	sgn_VMi(Size_Ram-1 downto Idx_M+1) <= (others => '1');
	sgn_VMi(Idx_M) <= V_Mi(Idx_M);
	
	inst01: Lg_BoolOpt
	port map(
		Di			=> sgn_VMi,--: in	std_logic_vector(2**nL-1 downto 0);
		Do			=> sgn_VM_res,--: out	std_logic;
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
	
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_Sel <= '0';
		elsif(rising_edge(clk))then
			sgn_Sel <= sgn_VM_res;
		end if;
	end process;
end generate i0200;

i0300: if(Idx_M = Size_Ram-1) generate
	sgn_VMi(Idx_M-1 downto 0) <= not V_Mi(Idx_M-1 downto 0);
	sgn_VMi(Idx_M) <= V_Mi(Idx_M);
	
	inst01: Lg_BoolOpt
	port map(
		Di			=> sgn_VMi,--: in	std_logic_vector(2**nL-1 downto 0);
		Do			=> sgn_VM_res,--: out	std_logic;
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
	
	process(clk, aclr)
	begin
		if(aclr = '1')then
			sgn_Sel <= '0';
		elsif(rising_edge(clk))then
			sgn_Sel <= sgn_VM_res;
		end if;
	end process;
end generate i0300;

Flag_Clr <= sgn_Sel;
Sel <= sgn_Sel;

-- res delay
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_SelDL <= '0';
	elsif(rising_edge(clk))then
		sgn_SelDL <= sgn_Sel;
	end if;
end process;

end rtl;
