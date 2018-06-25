----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    23/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hashimoto_PP_P3 - Behavioral
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

--LIBRARY altera_mf;
--USE altera_mf.all;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

library work;
use work.Ethash_pkg.all;

entity Ethash_Hashimoto_PP_P3 is
generic(
	Device_Family	: string := "Stratix 10";--"Cyclone V"
	InnerRam_Deep	: Positive := 128; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Nonce		: Positive := 8;
	Size_S			: Positive := 64;
	Size_cMix		: Positive := 32;
	Size_Mix		: Positive := 128; -- Size_Mix = Size_S*2
	FIFO_AFNum		: Positive := 22; -- almost full value of input fifo
	FNV_DW			: Positive := 4;
	Hash_PPn		: Positive := 4 -- must be 1 2 3 4 6 8 12 24 
);
port (
	FNV_Prime	: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	Target		: in	typ_1D_Word(Size_cMix-1 downto 0);
	-- input form outter, nonce
	Nonce_i		: in	typ_1D_Word(Size_Nonce-1 downto 0);
	Nonce_A		: in	std_logic_vector(gcst_IDW*gcst_WW-1 downto 0); -- nID from outter
	Nonce_Wr	: in	std_logic; -- st form outter
	-- input from proc1, S0/j
	S_i			: in	typ_1D_Word(Size_S-1 downto 0); -- S from proc1
	S_A			: in	std_logic_vector(gcst_IDW*gcst_WW-1 downto 0); -- nID from proc1
	S_wr		: in	std_logic; -- st from proc1
	-- input from proc2
	ID_i		: in	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	Mix_i		: in	typ_1D_Word(Size_Mix-1 downto 0);
	-- Hashimoto result output
	Nonce_o		: out	typ_1D_Word(Size_Nonce-1 downto 0);
	HRes_o		: out	typ_1D_Word(Size_S-1 downto 0);
	cMix_o		: out typ_1D_Word(Size_cMix-1 downto 0);
	ID_o		: out	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	CmpRes_o	: out	std_logic;
	-- DAG result write to memory
	AB_DAG		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Mem_Valid	: in	std_logic;
	
	Mem_Do		: out	typ_1D_Word(Size_S-1 downto 0);
	Mem_Addr	: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Mem_Req		: out	std_logic;
	
	Mod_Sel		: in	std_logic := '1'; -- '0' DAG, '1' Hashimoto
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy			: out	std_logic; -- is there any task in process or in sequence
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Ethash_Hashimoto_PP_P3;

architecture rtl of Ethash_Hashimoto_PP_P3 is
--============================ constant declare ============================--
constant cst_RamSize		: Positive := InnerRam_Deep;
constant cst_RamAddrWidth	: Positive := Fnc_Int2Wd(cst_RamSize-1);--(log2(128))
constant cst_HashInSize		: Positive := 200;
constant cst_HashNum_H		: Positive := Size_S + Size_cMix; -- 96
constant cst_HashNum_DAG	: Positive := Size_cMix*2; --64
constant cst_HashTyp_H		: typ_Hash := e_Hash256;
constant cst_HashTyp_DAG	: typ_Hash := e_Hash512;

constant cst_FIFOcMix_RegDupNum		: Positive := 2*Size_cMix * gcst_WW/gcst_MaxWidth_RamPort;
constant cst_RamS_RegDupNum			: Positive := Size_S*gcst_WW/gcst_MaxWidth_RamPort;
--======================== Altera component declare ========================--
component scfifo
generic (
	ram_block_type				: string := "AUTO";
	add_ram_output_register		: STRING := "ON";
	almost_full_value			: NATURAL := FIFO_AFNum;
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords				: NATURAL := cst_RamSize;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL;
	lpm_widthu					: NATURAL := cst_RamAddrWidth; -- log2(128)
	overflow_checking			: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab						: STRING := "ON"
);
port (
	data			: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq			: IN STD_LOGIC ;

	q				: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq			: IN STD_LOGIC ;

	almost_full		: OUT STD_LOGIC ;
	empty			: OUT STD_LOGIC ;

	clock			: IN STD_LOGIC ;
	sclr			: IN STD_LOGIC ;
	aclr			: IN STD_LOGIC 
);
END component;

component altsyncram
generic (
	ram_block_type				: string := "AUTO";
	address_aclr_b				:	string := "NONE";
	address_reg_b				:	string := "CLOCK0";
	clock_enable_input_a		:	string := "BYPASS";
	clock_enable_input_b		:	string := "BYPASS";
	clock_enable_output_b		:	string := "BYPASS";
	intended_device_family		:	string := Device_Family;--"Cyclone V";
	lpm_type					:	string := "altsyncram";
	operation_mode				:	string := "DUAL_PORT";
	outdata_aclr_b				:	string := "NONE";
	outdata_reg_b				:	string := "UNREGISTERED";
	power_up_uninitialized		:	string := "FALSE";
	read_during_write_mode_mixed_ports	:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a					:	natural := cst_RamSize;
	numwords_b					:	natural := cst_RamSize;
	width_a						:	natural;
	width_b						:	natural;
	widthad_a					:	natural := cst_RamAddrWidth; -- log2(128)
	widthad_b					:	natural := cst_RamAddrWidth; -- log2(128)
	width_byteena_a				:	natural := 1
);
port(
	address_a	:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		:	in std_logic_vector(width_a-1 downto 0);
	wren_a		:	in std_logic;
	
	address_b	:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		:	in std_logic
);
end component;

--===================== user-defined component declare =====================--
component Ethash_FNV_Array8
generic(
	di_Num			: Positive := Size_Mix; -- fixed
	do_Num			: Positive := Size_cMix; -- fixed
	FNV_DW			: Positive := FNV_DW
);
port (
	Prime		: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	di			: in	typ_1D_Word(di_Num-1 downto 0); -- must be hold outside
	do			: out	typ_1D_Word(do_Num-1 downto 0);
	
	clk		: in	std_logic
);
end component;

component Ethash_Hash3
generic(
	di_Num			: Positive := cst_HashInSize;-- fixed
	do_Num			: Positive := Size_S; -- fixed
	PP_Lattic		: Positive := Hash_PPn -- must be 1 2 3 4 6 8 12 24 
);
port (
	di			: in	typ_1D_Word(di_Num-1 downto 0);
	do			: out	typ_1D_Word(do_Num-1 downto 0);
	Typ			: in	typ_Hash;
	Num			: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			: in	std_logic;
	Ed			: out	std_logic;
	pEd			: out	std_logic;
	ppEd		: out	std_logic;
	Bsy			: out	std_logic;
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;

component Lg_Cmp_Mw
generic(
	d_Num		: Positive := Size_cMix;
	Typ_Cmp		: string := "S" -- "Larger"="L", "Larger equal"="LE", "Small"="S", "Small equal"="SE", "equal"="E"
);
port (
	a			: in	typ_1D_Word(d_Num-1 downto 0);
	b			: in	typ_1D_Word(d_Num-1 downto 0);
	Res			: out	std_logic;
	
	clk			: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Ram_S_Di				: std_logic_vector(Size_S*gcst_WW-1 downto 0);
signal sgn_Ram_S_Do				: std_logic_vector(Size_S*gcst_WW-1 downto 0);
--signal sgn_Ram_S_rd_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
--signal sgn_Ram_S_wr_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
--signal sgn_Ram_S_wr				: std_logic;
type typ_Rdup_RamAddr is array (natural range<>) of std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_S_rd_Addr		: typ_Rdup_RamAddr(cst_RamS_RegDupNum-1 downto 0);
signal sgn_Ram_S_wr_Addr		: typ_Rdup_RamAddr(cst_RamS_RegDupNum-1 downto 0);
signal sgn_Ram_S_wr				: std_logic_vector(cst_RamS_RegDupNum-1 downto 0);

signal sgn_Ram_N_wr_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_N_Di				: std_logic_vector(Size_Nonce*gcst_WW-1 downto 0);
signal sgn_Ram_N_wr				: std_logic;
signal sgn_Ram_N_rd_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_N_Do				: std_logic_vector(Size_Nonce*gcst_WW-1 downto 0);

signal sgn_cMix					: typ_1D_Word(Size_cMix-1 downto 0);

signal sgn_FIFO_cMix_Di			: std_logic_vector(2*Size_cMix * gcst_WW-1 downto 0); -- S0 + idx_n
signal sgn_FIFO_cMix_Do			: std_logic_vector(2*Size_cMix * gcst_WW-1 downto 0);
--signal sgn_FIFO_cMix_Wr			: std_logic;
--signal sgn_FIFO_cMix_Rd			: std_logic;
--signal sgn_FIFO_cMix_Emp		: std_logic;
signal sgn_FIFO_cMix_Wr			: std_logic_vector(cst_FIFOcMix_RegDupNum-1 downto 0);
signal sgn_FIFO_cMix_Rd			: std_logic_vector(cst_FIFOcMix_RegDupNum-1 downto 0);
signal sgn_FIFO_cMix_Emp		: std_logic_vector(cst_FIFOcMix_RegDupNum-1 downto 0);

signal sgn_FIFO_ID_Di			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- 
signal sgn_FIFO_ID_Wr			: std_logic;
signal sgn_FIFO_ID_Do			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal sgn_FIFO_ID_Rd			: std_logic;

signal sgn_FIFOo_cMix_Di		: std_logic_vector(Size_cMix * gcst_WW-1 downto 0); -- 
signal sgn_FIFOo_cMix_Wr		: std_logic;
signal sgn_FIFOo_cMix_Do		: std_logic_vector(Size_cMix * gcst_WW-1 downto 0);
signal sgn_FIFOo_cMix_Rd		: std_logic;

signal sgn_FIFOo_ID_Di			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- 
signal sgn_FIFOo_ID_Wr			: std_logic;
signal sgn_FIFOo_ID_Do			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal sgn_FIFOo_ID_Rd			: std_logic;

signal sgn_FIFOo_Cmp_Di			: std_logic_vector(1-1 downto 0); -- 
signal sgn_FIFOo_Cmp_Wr			: std_logic;
signal sgn_FIFOo_Cmp_Do			: std_logic_vector(1-1 downto 0);
signal sgn_FIFOo_Cmp_Rd			: std_logic;

signal sgn_FIFOo_S0_Di			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0); -- 
signal sgn_FIFOo_S0_Wr			: std_logic;
signal sgn_FIFOo_S0_Do			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFOo_S0_Rd			: std_logic;

signal sgn_Mux_cMix_a			: typ_1D_Word(2*Size_cMix-1 downto 0);
signal sgn_Mux_cMix_b			: typ_1D_Word(2*Size_cMix-1 downto 0);
signal sgn_Mux_cMix_o			: typ_1D_Word(2*Size_cMix-1 downto 0);

signal sgn_Mux_St_a				: std_logic;
signal sgn_Mux_St_b				: std_logic;
--signal sgn_Mux_St_o				: std_logic;

signal sgn_Lo1					: std_logic;
signal sgn_HashBsy				: std_logic;
signal sgn_S_Addr				: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);

signal sgn_Mux_HashDi_a			: typ_1D_Word(Size_S+Size_cMix-1 downto 0);
signal sgn_Mux_HashDi_b			: typ_1D_Word(Size_S+Size_cMix-1 downto 0);
signal sgn_Mux_HashDi_o			: typ_1D_Word(Size_S+Size_cMix-1 downto 0);

signal sgn_HashTyp				: typ_Hash := cst_HashTyp_H;
signal sgn_HashNum				: Natural := cst_HashNum_H;
signal sgn_HashDi				: typ_1D_Word(cst_HashInSize-1 downto 0);
signal sgn_HashRes				: typ_1D_Word(Size_S-1 downto 0);
signal sgn_HashSt, sgn_HashEd, sgn_HashpEd,sgn_HashppEd	: std_logic;

signal sgn_cmp_a				: typ_1D_Word(Size_cMix-1 downto 0);
signal sgn_cmp_b				: typ_1D_Word(Size_cMix-1 downto 0);
signal sgn_cmp_o				: std_logic;

signal sgn_ID_o					: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce

constant cst_St_DL				: Positive := gcst_FNVDL*3;
signal sgn_St_DL				: std_logic_vector(cst_St_DL-1 downto 0);
signal sgn_St					: std_logic;
constant cst_Lo1_DL				: Positive := 6; -- fifo(1) + reg duplicate(1) + ram(1) + cmp(3) = 6
signal sgn_Lo1_DL				: std_logic_vector(cst_Lo1_DL-1 downto 0);

type typ_state is (S_Idle, S_W);
signal state 					: typ_state;

signal sgn_TskCnt				: Natural range 0 to cst_RamSize;

signal sgn_ModSel				: std_logic;

-- input delay
signal sgn_S_i		: typ_1D_Word(Size_S-1 downto 0); -- S from proc1
--signal sgn_S_A		: std_logic_vector(gcst_IDW*gcst_WW-1 downto 0); -- nID from proc1
--signal sgn_S_wr		: std_logic; -- st from proc1
--============================ function declare ============================--

--============================ attribute declare ============================--
attribute maxfan : natural;
attribute maxfan of sgn_ModSel : signal is gAttribut_maxFanout;

--attribute maxfan of sgn_Ram_S_wr_Addr : signal is gAttribut_maxFanout;
--attribute maxfan of sgn_Ram_S_wr : signal is gAttribut_maxFanout;
--attribute maxfan of sgn_Ram_S_rd_Addr : signal is gAttribut_maxFanout;

--attribute maxfan of sgn_FIFO_cMix_Wr : signal is gAttribut_maxFanout;
--attribute maxfan of sgn_FIFO_cMix_Rd : signal is gAttribut_maxFanout;

attribute maxfan of sgn_FIFOo_cMix_Wr : signal is gAttribut_maxFanout;
attribute maxfan of sgn_FIFOo_cMix_Rd : signal is gAttribut_maxFanout;

attribute keep : Boolean;
attribute keep of sgn_FIFO_cMix_Wr : signal is true;
attribute keep of sgn_FIFO_cMix_Rd : signal is true;

attribute keep of sgn_Ram_S_rd_Addr : signal is true;
attribute keep of sgn_Ram_S_wr_Addr : signal is true;
attribute keep of sgn_Ram_S_wr : signal is true;

begin

--process(clk,aclr)
--begin
--	if(aclr = '1')then
--		sgn_S_wr <= '0';
--	elsif(rising_edge(clk))then
--		sgn_S_wr <= S_wr;
--	end if;
--end process;

process(clk)
begin
	if(rising_edge(clk))then
		sgn_ModSel <= Mod_Sel;
		sgn_S_i <= S_i;
--		sgn_S_A <= S_A;
	end if;
end process;

-- ram and fifo
r0100: for i in 0 to cst_RamS_RegDupNum-1 generate
	ins00: altsyncram -- S form proc1
	generic map(
		ram_block_type					=> "AUTO",--:	string := "AUTO";
		address_aclr_b					=> "NONE",--:	string := "NONE";
		address_reg_b					=> "CLOCK0",--:	string := "CLOCK0";
		clock_enable_input_a			=> "BYPASS",--:	string := "BYPASS";
		clock_enable_input_b			=> "BYPASS",--:	string := "BYPASS";
		clock_enable_output_b			=> "BYPASS",--:	string := "BYPASS";
		intended_device_family			=> Device_Family,--:	string := Device_Family;--"Cyclone V";
		lpm_type						=> "altsyncram",--:	string := "altsyncram";
		operation_mode					=> "DUAL_PORT",--:	string := "DUAL_PORT";
		outdata_aclr_b					=> "NONE",--:	string := "NONE";
		outdata_reg_b					=> "UNREGISTERED",--:	string := "UNREGISTERED";
		power_up_uninitialized			=> "FALSE",--:	string := "FALSE";
		read_during_write_mode_mixed_ports	=> "OLD_DATA",--:	string := "OLD_DATA";--"DONT_CARE";
		numwords_a						=> cst_RamSize,--:	natural := cst_RamSize;
		numwords_b						=> cst_RamSize,--:	natural := cst_RamSize;
		widthad_a						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
		widthad_b						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
		width_byteena_a					=> 1,--:	natural := 1

		width_a							=> gcst_MaxWidth_RamPort,--:	natural;
		width_b							=> gcst_MaxWidth_RamPort--:	natural;
	)
	port map(
		address_a	=> sgn_Ram_S_wr_Addr(i),--:	in std_logic_vector(widthad_a-1 downto 0);
		data_a		=> sgn_Ram_S_Di((i+1)*gcst_MaxWidth_RamPort-1 downto i*gcst_MaxWidth_RamPort),--:	in std_logic_vector(width_a-1 downto 0);
		wren_a		=> sgn_Ram_S_wr(i),--:	in std_logic;
		
		address_b	=> sgn_Ram_S_rd_Addr(i),--:	in std_logic_vector(widthad_b-1 downto 0);
		q_b			=> sgn_Ram_S_Do((i+1)*gcst_MaxWidth_RamPort-1 downto i*gcst_MaxWidth_RamPort),--:	out std_logic_vector(width_b-1 downto 0);
		
		clock0		=> clk--:	in std_logic
	);
end generate r0100;
	
ins10: altsyncram -- Nonce form outter
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	address_aclr_b					=> "NONE",--:	string := "NONE";
	address_reg_b					=> "CLOCK0",--:	string := "CLOCK0";
	clock_enable_input_a			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_input_b			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_output_b			=> "BYPASS",--:	string := "BYPASS";
	intended_device_family			=> Device_Family,--:	string := Device_Family;--"Cyclone V";
	lpm_type						=> "altsyncram",--:	string := "altsyncram";
	operation_mode					=> "DUAL_PORT",--:	string := "DUAL_PORT";
	outdata_aclr_b					=> "NONE",--:	string := "NONE";
	outdata_reg_b					=> "UNREGISTERED",--:	string := "UNREGISTERED";
	power_up_uninitialized			=> "FALSE",--:	string := "FALSE";
	read_during_write_mode_mixed_ports	=> "OLD_DATA",--:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a						=> cst_RamSize,--:	natural := cst_RamSize;
	numwords_b						=> cst_RamSize,--:	natural := cst_RamSize;
	widthad_a						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	widthad_b						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	width_byteena_a					=> 1,--:	natural := 1

	width_a							=> Size_Nonce*gcst_WW,--:	natural;
	width_b							=> Size_Nonce*gcst_WW--:	natural;
)
port map(
	address_a	=> sgn_Ram_N_wr_Addr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_Ram_N_Di,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Ram_N_wr,--:	in std_logic;
	
	address_b	=> sgn_Ram_N_rd_Addr,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Ram_N_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

r0200: for i in 0 to cst_FIFOcMix_RegDupNum-1 generate
	inst01: scfifo -- cMix from FNV
	generic map(
		ram_block_type					=> "AUTO",--:	string := "AUTO";
		add_ram_output_register			=> "ON",--: STRING := "ON";
		almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
		intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
		LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
		lpm_showahead					=> "OFF",--: STRING := "OFF";
		LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
		lpm_width						=> gcst_MaxWidth_RamPort--: NATURAL;
	)
	port map(
		data				=> sgn_FIFO_cMix_Di((i+1)*gcst_MaxWidth_RamPort-1 downto i*gcst_MaxWidth_RamPort),--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
		wrreq				=> sgn_FIFO_cMix_Wr(i),--: IN STD_LOGIC ;

		q					=> sgn_FIFO_cMix_Do((i+1)*gcst_MaxWidth_RamPort-1 downto i*gcst_MaxWidth_RamPort),--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
		rdreq				=> sgn_FIFO_cMix_Rd(i),--: IN STD_LOGIC ;

		almost_full			=> open,--: OUT STD_LOGIC ;
		empty				=> sgn_FIFO_cMix_Emp(i),--: OUT STD_LOGIC ;

		clock				=> clk,--: IN STD_LOGIC ;
		sclr				=> '0',
		aclr				=> aclr--: IN STD_LOGIC 
	);
end generate r0200;
	
inst02: scfifo -- ID from proc2
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	add_ram_output_register			=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width						=> gcst_IDW * gcst_WW--: NATURAL;
)
port map(
	data				=> sgn_FIFO_ID_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_ID_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_ID_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_ID_Rd,--: IN STD_LOGIC ;

	almost_full			=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	sclr				=> '0',
	aclr				=> aclr--: IN STD_LOGIC 
);

inst03: scfifo -- output fifo cMix
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	add_ram_output_register			=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width						=> Size_cMix * gcst_WW--: NATURAL;
)
port map(
	data				=> sgn_FIFOo_cMix_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFOo_cMix_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFOo_cMix_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFOo_cMix_Rd,--: IN STD_LOGIC ;

	almost_full			=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	sclr				=> '0',
	aclr				=> aclr--: IN STD_LOGIC 
);

inst04: scfifo -- output fifo ID
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	add_ram_output_register			=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width						=> gcst_IDW * gcst_WW--: NATURAL;
)
port map(
	data				=> sgn_FIFOo_ID_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFOo_ID_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFOo_ID_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFOo_ID_Rd,--: IN STD_LOGIC ;

	almost_full			=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	sclr				=> '0',
	aclr				=> aclr--: IN STD_LOGIC 
);

inst05: scfifo -- output fifo compare result
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	add_ram_output_register			=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width						=> 1--: NATURAL;
)
port map(
	data				=> sgn_FIFOo_Cmp_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFOo_Cmp_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFOo_Cmp_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFOo_Cmp_Rd,--: IN STD_LOGIC ;

	almost_full			=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	sclr				=> '0',
	aclr				=> aclr--: IN STD_LOGIC 
);

inst06: scfifo -- output fifo S0/j
generic map(
	ram_block_type					=> "AUTO",--:	string := "AUTO";
	add_ram_output_register			=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family			=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width						=> gcst_AW * gcst_WW--: NATURAL;
)
port map(
	data				=> sgn_FIFOo_S0_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFOo_S0_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFOo_S0_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFOo_S0_Rd,--: IN STD_LOGIC ;

	almost_full			=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	sclr				=> '0',
	aclr				=> aclr--: IN STD_LOGIC 
);

-- connect store S from proc1
--sgn_Ram_S_wr_Addr <= sgn_S_A(cst_RamAddrWidth-1 downto 0);
process(clk)-- duplicate
begin
	if(rising_edge(clk))then
		for i in 0 to cst_RamS_RegDupNum-1 loop
			sgn_Ram_S_wr_Addr(i) <= S_A(cst_RamAddrWidth-1 downto 0);
		end loop;
	end if;
end process;
i0100: for i in 0 to Size_S-1 generate
	sgn_Ram_S_Di(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_S_i(i);
end generate i0100;
--sgn_Ram_S_wr <= sgn_S_wr;
process(clk,aclr) -- duplicate
begin
	if(aclr = '1')then
		sgn_Ram_S_wr <= (others => '0');
	elsif(rising_edge(clk))then
		for i in 0 to cst_RamS_RegDupNum-1 loop
			sgn_Ram_S_wr(i) <= S_wr;
		end loop;
	end if;
end process;

-- connect store nonce form outter
sgn_Ram_N_wr_Addr <= Nonce_A(cst_RamAddrWidth-1 downto 0);
i0800: for i in 0 to Size_Nonce-1 generate
	sgn_Ram_N_Di(gcst_WW*(i+1)-1 downto gcst_WW*i) <= Nonce_i(i);
end generate i0800;
sgn_Ram_N_wr <= Nonce_Wr;

-- FNV
inst07: Ethash_FNV_Array8
port map(
	Prime		=> FNV_Prime,--: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	di			=> Mix_i,--(io): in	typ_1D_Word(di_Num-1 downto 0); -- must be hold outside
	do			=> sgn_cMix,--: out	typ_1D_Word(do_Num-1 downto 0);
	
	clk			=> clk--: in	std_logic;
);

-- cMix mux
sgn_Mux_cMix_a(Size_cMix-1 downto 0) <= sgn_cMix;
sgn_Mux_cMix_a(2*Size_cMix-1 downto Size_cMix) <= (others => (others => '0'));
sgn_Mux_cMix_b <= Mix_i(2*Size_cMix-1 downto 0); -- (io)

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_ModSel = '1')then -- Hashimoto
			sgn_Mux_cMix_o <= sgn_Mux_cMix_a;
		else -- DAG
			sgn_Mux_cMix_o <= sgn_Mux_cMix_b;
		end if;
	end if;
end process;

sgn_Mux_St_a <= sgn_St_DL(cst_St_DL-1); -- DL 9
sgn_Mux_St_b <= sgn_St and (not sgn_ModSel);

--process(aclr,clk)
--begin
--	if(aclr='1')then
--		sgn_Mux_St_o <= '0';
--	elsif(rising_edge(clk))then
--		if(sgn_ModSel = '1')then -- Hashimoto
--			sgn_Mux_St_o <= sgn_Mux_St_a;
--		else -- DAG
--			sgn_Mux_St_o <= sgn_Mux_St_b;
--		end if;
--	end if;
--end process;

-- connect push cmix to fifo
i0200: for i in 0 to 2*Size_cMix-1 generate
	sgn_FIFO_cMix_Di(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_Mux_cMix_o(i);
end generate i0200;
--sgn_FIFO_cMix_Wr <= sgn_Mux_St_o;
process(aclr,clk)-- duplicate
begin
	if(aclr='1')then
		sgn_FIFO_cMix_Wr <= (others => '0');
	elsif(rising_edge(clk))then
		if(sgn_ModSel = '1')then -- Hashimoto
			sgn_FIFO_cMix_Wr <= (others => sgn_Mux_St_a);
		else -- DAG
			sgn_FIFO_cMix_Wr <= (others => sgn_Mux_St_b);
		end if;
	end if;
end process;

-- connect push ID to fifo
sgn_FIFO_ID_Di <= ID_i; -- (io)
sgn_FIFO_ID_Wr <= sgn_St; --(io)

-- logic
--sgn_Lo1 <= (not sgn_FIFO_cMix_Emp) and (not sgn_HashBsy);
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_Lo1 <= '0';
		state <= S_IDLE;
	elsif(rising_edge(clk))then
		case state is
			when S_IDLE =>
				if(sgn_HashBsy = '0' and sgn_FIFO_cMix_Emp(0) = '0' and sgn_ModSel = '1')then
					sgn_Lo1 <= '1';
					state <= S_W;
				elsif(sgn_HashBsy = '0' and sgn_FIFO_cMix_Emp(0) = '0' and (sgn_ModSel = '0' and Mem_Valid = '1'))then
					sgn_Lo1 <= '1';
					state <= S_W;
				else
					sgn_Lo1 <= '0';
				end if;
			when S_W =>
				sgn_Lo1 <= '0';
				if(sgn_HashBsy = '1')then
					state <= S_Idle;
				end if;
			when others => 
				state <= S_IDLE;
				sgn_Lo1 <= '0';
		end case;
	end if;
end process;

-- connect get ID from fifo
sgn_S_Addr <= sgn_FIFO_ID_Do;
sgn_FIFO_ID_Rd <= sgn_Lo1;

-- connect get S from ram
--sgn_Ram_S_rd_Addr <= sgn_S_Addr(cst_RamAddrWidth-1 downto 0);
process(clk) -- duplicate
begin
	if(rising_edge(clk))then
		for i in 0 to  cst_RamS_RegDupNum-1 loop
			sgn_Ram_S_rd_Addr(i) <= sgn_S_Addr(cst_RamAddrWidth-1 downto 0);
		end loop;
	end if;
end process;

i0300: for i in 0 to Size_S-1 generate
	sgn_Mux_HashDi_a(i) <= sgn_Ram_S_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0300;

-- connect get cMix from fifo
i0400: for i in 0 to Size_cMix-1 generate
	sgn_Mux_HashDi_a(i+Size_S) <= sgn_FIFO_cMix_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0400;
i0500: for i in 0 to 2*Size_cMix-1 generate
	sgn_Mux_HashDi_b(i) <= sgn_FIFO_cMix_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0500;
sgn_Mux_HashDi_b(Size_S+Size_cMix-1 downto 2*Size_cMix) <= (others => (others => '0'));
--sgn_FIFO_cMix_Rd <= sgn_Lo1_DL(1); -- DL2
process(clk,aclr)-- duplicate
begin
	if(aclr='1')then
		sgn_FIFO_cMix_Rd <= (others => '0');
	elsif(rising_edge(clk))then
		for i in 0 to cst_FIFOcMix_RegDupNum-1 loop
			sgn_FIFO_cMix_Rd(i) <= sgn_Lo1_DL(0); -- DL1+1 = DL2
		end loop;
	end if;
end process;

-- Mux S+cMix
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_ModSel = '1')then -- hashimoto
			sgn_Mux_HashDi_o <= sgn_Mux_HashDi_a;
		else-- DAG
			sgn_Mux_HashDi_o <= sgn_Mux_HashDi_b;
		end if;
	end if;
end process;

-- Hash
inst08: Ethash_Hash3
port map(
	di			=> sgn_HashDi,--: in	typ_1D_Word(di_Num-1 downto 0);
	do			=> sgn_HashRes,--: out	typ_1D_Word(do_Num-1 downto 0);
	Typ			=> sgn_HashTyp,--: in	typ_Hash;
	Num			=> sgn_HashNum,--: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			=> sgn_HashSt,--: in	std_logic;
	Ed			=> sgn_HashEd,--: out	std_logic;
	pEd			=> sgn_HashpEd,--: out	std_logic;
	ppEd		=> sgn_HashppEd,--: out	std_logic;
	Bsy			=> sgn_HashBsy,--: out	std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);
sgn_HashDi(Size_S+Size_cMix-1 downto 0) <= sgn_Mux_HashDi_o;
sgn_HashDi(cst_HashInSize-1 downto Size_S+Size_cMix) <= (others => (others => '0'));
sgn_HashSt <= sgn_Lo1_DL(3); -- DL4

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_ModSel = '1')then -- hashimoto
			sgn_HashTyp <= cst_HashTyp_H;
			sgn_HashNum	<= cst_HashNum_H;
		else -- DAG
			sgn_HashTyp <= cst_HashTyp_DAG;
			sgn_HashNum	<= cst_HashNum_DAG;
		end if;
	end if;
end process;

-- connect push cmix to output fifo (only hashimoto)
sgn_FIFOo_cMix_Di <= sgn_FIFO_cMix_Do(Size_cMix*gcst_WW-1 downto 0);
sgn_FIFOo_cMix_Wr <= sgn_Lo1_DL(2) and sgn_ModSel; -- DL3

-- connect push ID to output fifo (always)
sgn_FIFOo_ID_Di <= sgn_FIFO_ID_Do;
sgn_FIFOo_ID_Wr <= sgn_Lo1_DL(0); -- DL1

-- connect push S0/j to output fifo (only DAG)
process(clk)
begin
	if(rising_edge(clk))then
		sgn_FIFOo_S0_Di <= unsigned(sgn_Ram_S_Do(gcst_AW*gcst_WW-1 downto 0)) + unsigned(AB_DAG);
	end if;
end process;
sgn_FIFOo_S0_Wr <= sgn_Lo1_DL(3) and (not sgn_ModSel); -- DL4

-- cmp target and cmix
inst09: Lg_Cmp_Mw
port map(
	a			=> sgn_cmp_a,--: in	typ_1D_Word(d_Num-1 downto 0);
	b			=> sgn_cmp_b,--: in	typ_1D_Word(d_Num-1 downto 0);
	Res			=> sgn_cmp_o,--: out	std_logic;
	
	clk			=> clk--: in	std_logic;
);

i0600: for i in 0 to Size_cMix-1 generate
	sgn_cmp_a(i) <= sgn_FIFO_cMix_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0600;
sgn_cmp_b <= Target;

-- connect push cmp result to 1bit fifo (only hasimoto)
sgn_FIFOo_Cmp_Di(0) <= sgn_cmp_o;
sgn_FIFOo_Cmp_Wr <= sgn_Lo1_DL(cst_Lo1_DL-1) and sgn_ModSel; -- DL6

-- connect output fifo for Hashimoto
i0700: for i in 0 to Size_cMix-1 generate
	cMix_o(i) <= sgn_FIFOo_cMix_Do(gcst_WW*(i+1)-1 downto gcst_WW*i); --(io)
end generate i0700;
sgn_FIFOo_cMix_Rd <= sgn_HashpEd and sgn_ModSel;

CmpRes_o <= sgn_FIFOo_Cmp_Do(0); --(io)
sgn_FIFOo_Cmp_Rd <= sgn_HashpEd and sgn_ModSel;

-- connect output for DAG
Mem_Do <= sgn_HashRes;
Mem_Addr <= sgn_FIFOo_S0_Do;
Mem_Req <= sgn_HashEd and (not sgn_ModSel);
sgn_FIFOo_S0_Rd <= sgn_HashpEd and (not sgn_ModSel);

-- output for Hasimoto
HRes_o <= sgn_HashRes; -- (io)

-- output for MC
Ed <= sgn_HashEd; -- always notify MC (io)
sgn_ID_o <= sgn_FIFOo_ID_Do; --(io)
sgn_FIFOo_ID_Rd <= sgn_HashppEd; -- ID always output

process(clk)
begin
	if(rising_edge(clk))then
		ID_o <= sgn_ID_o; -- 1clk delay
	end if;
end process;

i0900: for i in 0 to Size_Nonce-1 generate
	Nonce_o(i) <= sgn_Ram_N_Do(gcst_WW*(i+1)-1 downto gcst_WW*i); --(io)
end generate i0900;
sgn_Ram_N_rd_Addr <= sgn_ID_o(cst_RamAddrWidth-1 downto 0);

-- delay
sgn_St <= St;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_St_DL <= (others => '0');
		sgn_Lo1_DL <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_St_DL(0) <= sgn_St and sgn_ModSel; -- (io)
		for i in 1 to cst_St_DL-1 loop -- 9
			sgn_St_DL(i) <= sgn_St_DL(i-1);
		end loop;
		sgn_Lo1_DL(0) <= sgn_Lo1;
		for i in 1 to cst_Lo1_DL-1 loop -- 5
			sgn_Lo1_DL(i) <= sgn_Lo1_DL(i-1);
		end loop;
	end if;
end process;

-- task count
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_TskCnt <= 0;
	elsif(rising_edge(clk))then
		if(St = '1' and sgn_HashEd = '0')then
			sgn_TskCnt <= sgn_TskCnt + 1;
		elsif(St = '0' and sgn_HashEd = '1')then
			sgn_TskCnt <= sgn_TskCnt - 1;
		end if;
	end if;
end process;

process(clk, aclr)
begin
	if(aclr='1')then
		Bsy <= '0';
	elsif(rising_edge(clk))then
		if(St = '1')then
			Bsy <= '1'; -- unchange
		else
			if(sgn_TskCnt = 1 and sgn_HashEd = '1')then -- last target
				Bsy <= '0';
			end if;
		end if;
	end if;
end process;

end rtl;
