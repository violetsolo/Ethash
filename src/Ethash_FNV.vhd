----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    02/04/2018 
-- Design Name: 
-- Module Name:    Ethash_FNV - Behavioral
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

LIBRARY lpm; 
USE lpm.lpm_components.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity Ethash_FNV is
generic(
	data_width		: Positive := 32
);
port (
	Prime	: in	std_logic_vector(data_width-1 downto 0) := x"01000193";
	
	v1		: in	std_logic_vector(data_width-1 downto 0);
	v2		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic;
	aclr	: in	std_logic
);
end Ethash_FNV;

architecture rtl of Ethash_FNV is
--============================ constant declare ============================--
constant cst_FNV_prime	: std_logic_vector(data_width-1 downto 0) := x"01000193";
constant cst_mult_dw		: Positive	:= data_width / 2;
--constant	cst_pAdd_ChNum	: Positive	:= 3;

--======================== Altera component declare ========================--
--component LPM_MULT
--generic ( 
--	LPM_WIDTHA				: natural := cst_mult_dw; 
--	LPM_WIDTHB				: natural := cst_mult_dw;
--	LPM_WIDTHP				: natural := data_width;
--	LPM_REPRESENTATION	: string := "UNSIGNED";
--	LPM_PIPELINE			: natural := 1;
--	LPM_TYPE					: string := "LPM_MULT";
--	LPM_HINT					: string := "UNUSED"
--);
--port ( 
--	DATAA		: in std_logic_vector(LPM_WIDTHA-1 downto 0);
--	DATAB		: in std_logic_vector(LPM_WIDTHB-1 downto 0);
--	RESULT	: out std_logic_vector(LPM_WIDTHP-1 downto 0);
--	CLOCK		: in std_logic := '0';
--	ACLR		: in std_logic := '0'
--);
--end component;
--
--component parallel_add 
--generic (
--	width					: natural := cst_mult_dw;    
--	size					: natural := cst_pAdd_ChNum;    
--	widthr				: natural := cst_mult_dw;    
--	shift					: natural := 0;    
--	msw_subtract		: string  := "NO";    
--	representation		: string  := "UNSIGNED";    
--	pipeline				: natural := 1;    
--	result_alignment	: string  := "LSB";
--	lpm_hint				: string  := "UNUSED";    
--	lpm_type 			: string  := "parallel_add"
--);
--port (
--	data		: in altera_mf_logic_2D(size - 1 downto 0,width- 1 downto 0);   
--	result	: out std_logic_vector(widthr - 1 downto 0);
--	clock		: in std_logic := '1';
--	aclr		: in std_logic := '0'
--);
--end component;
--===================== user-defined component declare =====================--


--============================= signal declare =============================--
signal sgn_ah, sgn_al, sgn_bh, sgn_bl	:	std_logic_vector(cst_mult_dw-1 downto 0);
signal sgn_ahbl, sgn_albh, sgn_albl		:	std_logic_vector(data_width-1 downto 0);
signal sgn_albl_l_d1							:	std_logic_vector(cst_mult_dw-1 downto 0);
signal sgn_v2_d1, sgn_v2_d2				:	std_logic_vector(data_width-1 downto 0);
--signal sgn_pAdd_in							:	altera_mf_logic_2D(cst_pAdd_ChNum-1 downto 0, cst_mult_dw-1 downto 0); -- 3*16
signal sgn_pAdd_out							:	std_logic_vector(cst_mult_dw-1 downto 0);
signal sgn_xor_ina, sgn_xor_inb			:	std_logic_vector(data_width-1 downto 0);

begin
-- multiply
sgn_ah <= v1(data_width-1 downto cst_mult_dw);
sgn_al <= v1(cst_mult_dw-1 downto 0);
--sgn_bh <= cst_FNV_prime(data_width-1 downto cst_mult_dw);
--sgn_bl <= cst_FNV_prime(cst_mult_dw-1 downto 0);
sgn_bh <= Prime(data_width-1 downto cst_mult_dw);
sgn_bl <= Prime(cst_mult_dw-1 downto 0);

--inst00: LPM_MULT
--port map (
--	DATAA		=> sgn_ah,--: in std_logic_vector(LPM_WIDTHA-1 downto 0);
--	DATAB		=> sgn_bl,--: in std_logic_vector(LPM_WIDTHB-1 downto 0);
--	RESULT	=> sgn_ahbl,--: out std_logic_vector(LPM_WIDTHP-1 downto 0);
--	CLOCK		=> clk,--: in std_logic := '0';
--	ACLR		=> aclr--: in std_logic := '0'
--);
--
--inst01: LPM_MULT
--port map (
--	DATAA		=> sgn_al,--: in std_logic_vector(LPM_WIDTHA-1 downto 0);
--	DATAB		=> sgn_bh,--: in std_logic_vector(LPM_WIDTHB-1 downto 0);
--	RESULT	=> sgn_albh,--: out std_logic_vector(LPM_WIDTHP-1 downto 0);
--	CLOCK		=> clk,--: in std_logic := '0';
--	ACLR		=> aclr--: in std_logic := '0'
--);
--
--inst02: LPM_MULT
--port map (
--	DATAA		=> sgn_al,--: in std_logic_vector(LPM_WIDTHA-1 downto 0);
--	DATAB		=> sgn_bl,--: in std_logic_vector(LPM_WIDTHB-1 downto 0);
--	RESULT	=> sgn_albl,--: out std_logic_vector(LPM_WIDTHP-1 downto 0);
--	CLOCK		=> clk,--: in std_logic := '0';
--	ACLR		=> aclr--: in std_logic := '0'
--);
process(clk)
begin
	if (rising_edge(clk)) then
		sgn_ahbl <= unsigned(sgn_ah) * unsigned(sgn_bl);
		sgn_albh <= unsigned(sgn_al) * unsigned(sgn_bh);
		sgn_albl <= unsigned(sgn_al) * unsigned(sgn_bl);
	end if;
end process;


-- add
--L000: for i in cst_mult_dw-1 downto 0 generate
--	sgn_pAdd_in(0,i) <= sgn_ahbl(i);
--	sgn_pAdd_in(1,i) <= sgn_albh(i);
--	sgn_pAdd_in(2,i) <= sgn_albl(i+cst_mult_dw);
--end generate;
--	
--inst03: parallel_add
--port map (
--	data		=> sgn_pAdd_in,--: in altera_mf_logic_2D(size - 1 downto 0,width- 1 downto 0);   
--	result	=> sgn_pAdd_out,--: out std_logic_vector(widthr - 1 downto 0);
--	clock		=> clk,--: in std_logic := '1';
--	aclr		=> aclr--: in std_logic := '0'
--);

process(clk)
begin
	if (rising_edge(clk)) then
		sgn_pAdd_out <= unsigned(sgn_ahbl(cst_mult_dw-1 downto 0)) + 
							 unsigned(sgn_albh(cst_mult_dw-1 downto 0)) + 
							 unsigned(sgn_albl(data_width-1 downto cst_mult_dw));
	end if;
end process;

-- delay
process(clk)
begin
	if (rising_edge(clk)) then
		sgn_albl_l_d1 <= sgn_albl(cst_mult_dw-1 downto 0);
		sgn_v2_d2 <= sgn_v2_d1;
		sgn_v2_d1 <= v2;
	end if;
end process;

sgn_xor_ina(cst_mult_dw-1 downto 0) <= sgn_albl_l_d1;
sgn_xor_ina(data_width-1 downto cst_mult_dw) <= sgn_pAdd_out;
sgn_xor_inb <= sgn_v2_d2;

-- xor
process(clk, aclr)
begin
	if (aclr = '1') then
		o <= (others => '0');
	elsif (rising_edge(clk)) then
		o <= sgn_xor_ina xor sgn_xor_inb;
	end if;
end process;

end rtl;