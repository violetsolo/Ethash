----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    20/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hashimoto_PP_P2 - Behavioral
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

entity Ethash_Hashimoto_PP_P2 is
generic(
	Device_Family	: string := "Stratix 10";--"Cyclone V"
	InnerRam_Deep	: Positive := 128; -- "Cyclone V": 128, "Stratix 10": 256
	Size_S			: Positive := 64;
	Size_Mix			: Positive := 128; -- Size_Mix = Size_S*2
	FIFO_AFNum		: Positive := 22; -- almost full value of input fifo
	FNV_DW			: Positive := 4;
	Mod_Lattic		: Positive := 6
);
port (
	n_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	n_DAG			: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = DAG size/64
	FNV_Prime	: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	
	S0_i			: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	S_i			: in	typ_1D_Word(Size_S-1 downto 0);
	ID_i			: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	
	Mix			: out	typ_1D_Word(Size_Mix-1 downto 0);
	ID_o			: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	
	Mod_Sel		: in	std_logic; -- '0' DAG, '1' Hashimoto
	St				: in	std_logic;
	Ed				: out	std_logic;
	Bsy			: out	std_logic; -- is there any task in process or in sequence
	
	AB_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	AB_DAG		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	: in std_logic;
	Mem_Addr		: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req		: out typ_InfoSocket;
	Mem_Req		: out	std_logic; -- only 1 clk
	
	Mem_Di		: in	typ_1D_Word(Size_Mix-1 downto 0);
	Info_Ack		: in	typ_InfoSocket;
	Mem_Ack		: in	std_logic; -- must be 1 clk
		
	clk			: in	std_logic;
	aclr			: in	std_logic
);
end Ethash_Hashimoto_PP_P2;

architecture rtl of Ethash_Hashimoto_PP_P2 is
--============================ constant declare ============================--
constant cst_FNV_DW				: Positive := gcst_AW; -- 4
constant cst_RamSize				: Positive := InnerRam_Deep;
constant cst_RamAddrWidth		: Positive := Fnc_Int2Wd(cst_RamSize-1);--(log2(128))
constant cst_AccessNum_DAG		: Positive := 256; --DAG
constant cst_AccessNum_H		: Positive := 64; -- hashimoto
constant cst_Mux_nL				: Positive := 5; -- 32=2^5
--======================== Altera component declare ========================--
component scfifo
generic (
	add_ram_output_register		: STRING := "ON";
	almost_full_value				: NATURAL := FIFO_AFNum;
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords					: NATURAL := cst_RamSize;
	lpm_showahead					: STRING := "OFF";
	lpm_type							: STRING := "scfifo";
	lpm_width						: NATURAL;
	lpm_widthu						: NATURAL := cst_RamAddrWidth; -- log2(128)
	overflow_checking				: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab							: STRING := "ON"
);
port (
	data				: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				: IN STD_LOGIC ;

	q					: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				: IN STD_LOGIC ;

	almost_full		: OUT STD_LOGIC ;
	empty				: OUT STD_LOGIC ;

	clock				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;

component altsyncram
generic (
	address_aclr_b					:	string := "NONE";
	address_reg_b					:	string := "CLOCK0";
	clock_enable_input_a			:	string := "BYPASS";
	clock_enable_input_b			:	string := "BYPASS";
	clock_enable_output_b		:	string := "BYPASS";
	intended_device_family		:	string := Device_Family;--"Cyclone V";
	lpm_type							:	string := "altsyncram";
	operation_mode					:	string := "DUAL_PORT";
	outdata_aclr_b					:	string := "NONE";
	outdata_reg_b					:	string := "UNREGISTERED";
	power_up_uninitialized		:	string := "FALSE";
	read_during_write_mode_mixed_ports	:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a						:	natural := cst_RamSize;
	numwords_b						:	natural := cst_RamSize;
	width_a							:	natural;
	width_b							:	natural;
	widthad_a						:	natural := cst_RamAddrWidth; -- log2(128)
	widthad_b						:	natural := cst_RamAddrWidth; -- log2(128)
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
component Ethash_FNV
generic(
	data_width		: Positive := cst_FNV_DW * gcst_WW
);
port (
	Prime	: in	std_logic_vector(data_width-1 downto 0);
	
	v1		: in	std_logic_vector(data_width-1 downto 0);
	v2		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic;
	aclr	: in	std_logic
);
end component;

component Ethash_Mod
generic(
	data_width		: Positive	:= cst_FNV_DW * gcst_WW;
	sft_num			: Natural	:= Mod_Lattic
);
port (
	a		: in	std_logic_vector(data_width-1 downto 0);
	b		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic;
	aclr	: in	std_logic
);
end component;

component Lg_Mux_nL1w
generic(
	nL					: Positive := cst_Mux_nL -- 32=2^5
);
port (
	Di			: in	typ_1D_Word(2**nL-1 downto 0);
	Do			: out	std_logic_vector(gcst_WW-1 downto 0);
	Sel		: in	std_logic_vector(nL-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Ram_Mix_wr_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_Mix_Di			: std_logic_vector(Size_Mix*gcst_WW-1 downto 0);
signal sgn_Ram_Mix_wr			: std_logic;
signal sgn_Ram_Mix_rd_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_Mix_Do			: std_logic_vector(Size_Mix*gcst_WW-1 downto 0);

signal sgn_Ram_S0_wr_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_S0_Di				: std_logic_vector(Size_S*gcst_WW-1 downto 0);
signal sgn_Ram_S0_wr				: std_logic;
signal sgn_Ram_S0_rd_Addr		: std_logic_vector(cst_RamAddrWidth-1 downto 0);
signal sgn_Ram_S0_Do				: std_logic_vector(Size_S*gcst_WW-1 downto 0);

signal sgn_FIFO_Si_Di	: std_logic_vector((gcst_AW + gcst_AW + 1) * gcst_WW-1 downto 0); -- S0 S0/j ID
signal sgn_FIFO_Si_Wr	: std_logic;
signal sgn_FIFO_Si_Do	: std_logic_vector((gcst_AW + gcst_AW + 1) * gcst_WW-1 downto 0);
signal sgn_FIFO_Si_Rd	: std_logic;
signal sgn_FIFO_Si_Emp	: std_logic;

signal sgn_FIFO_Mix0_Di	: std_logic_vector((gcst_AW + 1) * gcst_WW-1 downto 0); -- Mix0 i
signal sgn_FIFO_Mix0_Wr	: std_logic;
signal sgn_FIFO_Mix0_Do	: std_logic_vector((gcst_AW + 1) * gcst_WW-1 downto 0);
signal sgn_FIFO_Mix0_Rd	: std_logic;
signal sgn_FIFO_Mix0_Emp	: std_logic;

signal sgn_FIFO_S0_Di	: std_logic_vector((gcst_AW + 1) * gcst_WW-1 downto 0); -- S0/j ID
signal sgn_FIFO_S0_Wr	: std_logic;
signal sgn_FIFO_S0_Do	: std_logic_vector((gcst_AW + 1) * gcst_WW-1 downto 0);
signal sgn_FIFO_S0_Rd	: std_logic;
--signal sgn_FIFO_S0_Emp	: std_logic;

signal sgn_Mux_Mix_Sel		: std_logic;-- 0 sel S0, 1 sel mix(n-1)
signal sgn_Mux_Mix_a			: typ_1D_Word(Size_Mix-1 downto 0);
signal sgn_Mux_Mix_b			: typ_1D_Word(Size_Mix-1 downto 0);
signal sgn_Mux_Mix_o			: typ_1D_Word(Size_Mix-1 downto 0);

signal sgn_Mem_Di_DL1		: typ_1D_Word(Size_Mix-1 downto 0);
signal sgn_Mem_Di_DL2		: typ_1D_Word(Size_Mix-1 downto 0);

type typ_1D_4Word is array (natural range <>) of std_logic_vector(cst_FNV_DW * gcst_WW-1 downto 0);
signal sgn_FNV_v1, sgn_FNV_v2, sgn_FNV_o		: typ_1D_4Word(Size_Mix/cst_FNV_DW-1 downto 0);
signal sgn_FNV_Res			: typ_1D_Word(Size_Mix-1 downto 0);

signal sgn_idx_Mix_std		: std_logic_vector(gcst_WW-1 downto 0);
--signal sgn_idx_Mix			: Natural range 0 to Size_Mix-1; -- range 0~31
type typ_SubMux_i is array (natural range <>) of typ_1D_Word(Size_Mix/cst_FNV_DW-1 downto 0); -- 32
signal sgn_SubMux_i			: typ_SubMux_i(cst_FNV_DW-1 downto 0);
signal sgn_SubMux_o				: std_logic_vector(cst_FNV_DW * gcst_WW-1 downto 0);

signal sgn_MemReq				: std_logic;
signal sgn_ChSel				: std_logic; -- 0 sel S0, 1 sel mix
signal sgn_ChSel_DL			: std_logic; -- 0 sel S0, 1 sel mix
signal sgn_Ch_a_S0			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_a_Mix			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_a_i				: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Ch_a_ID			: std_logic_vector(gcst_WW-1 downto 0);

signal sgn_Ch_b_S0			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_b_Mix			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_b_i				: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Ch_b_ID			: std_logic_vector(gcst_WW-1 downto 0);

signal sgn_Ch_o_S0			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_o_Mix			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_Ch_o_i				: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Ch_o_ID			: std_logic_vector(gcst_WW-1 downto 0);

signal sgn_FIFO_nr_Di		: std_logic_vector((gcst_AW + 1 + 1) * gcst_WW-1 downto 0); -- S0/j ID i
signal sgn_FIFO_nr_Wr		: std_logic;
signal sgn_FIFO_nr_Do		: std_logic_vector((gcst_AW + 1 + 1) * gcst_WW-1 downto 0);
signal sgn_FIFO_nr_Rd		: std_logic;

signal sgn_aFNV_v1, sgn_aFNV_v2, sgn_aFNV_o	: std_logic_vector(cst_FNV_DW * gcst_WW-1 downto 0);

signal sgn_Mod_b				: std_logic_vector(cst_FNV_DW * gcst_WW-1 downto 0);
signal sgn_Addr				: std_logic_vector(cst_FNV_DW * gcst_WW-1 downto 0);

constant cst_MemAck_DL		: Positive := 1 + gcst_FNVDL + cst_Mux_nL; -- 9
signal sgn_MemAck_DL			: std_logic_vector(cst_MemAck_DL-1 downto 0);
signal sgn_MemAck				: std_logic;
constant cst_Fin_DL			: Positive := 1 + gcst_FNVDL; -- 4
signal sgn_Fin_DL				: std_logic_vector(cst_Fin_DL-1 downto 0);
signal sgn_Fin					: std_logic;
constant cst_Info_ID_DL			: Positive := 1 + gcst_FNVDL + 1; -- 5
signal sgn_Info_ID_DL			: typ_1D_Word(cst_Info_ID_DL-1 downto 0);
constant cst_Info_i_DL			: Positive := 1 + gcst_FNVDL + cst_Mux_nL; -- 9
signal sgn_Info_i_DL			: typ_1D_Word(cst_Info_i_DL-1 downto 0);
signal sgn_Info_i				: std_logic_vector(gcst_WW-1 downto 0);
constant cst_MemReq_DL		: Positive := 2 + 1 + gcst_FNVDL + (Mod_Lattic + 1) + 1; -- 14
signal sgn_MemReq_DL			: std_logic_vector(cst_MemReq_DL-1 downto 0);

signal sgn_TskCnt			: Natural range 0 to cst_RamSize;
--============================ function declare ============================--

begin

-- ram for mix(n-1)
inst00:altsyncram
generic map(
	address_aclr_b					=> "NONE",--:	string := "NONE";
	address_reg_b					=> "CLOCK0",--:	string := "CLOCK0";
	clock_enable_input_a			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_input_b			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_output_b		=> "BYPASS",--:	string := "BYPASS";
	intended_device_family		=> Device_Family,--:	string := Device_Family;--"Cyclone V";
	lpm_type							=> "altsyncram",--:	string := "altsyncram";
	operation_mode					=> "DUAL_PORT",--:	string := "DUAL_PORT";
	outdata_aclr_b					=> "NONE",--:	string := "NONE";
	outdata_reg_b					=> "UNREGISTERED",--:	string := "UNREGISTERED";
	power_up_uninitialized		=> "FALSE",--:	string := "FALSE";
	read_during_write_mode_mixed_ports	=> "OLD_DATA",--:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a						=> cst_RamSize,--:	natural := cst_RamSize;
	numwords_b						=> cst_RamSize,--:	natural := cst_RamSize;
	widthad_a						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	widthad_b						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	width_byteena_a				=> 1,--:	natural := 1

	width_a		=> Size_Mix*gcst_WW,--:	natural; -- 128
	width_b		=> Size_Mix*gcst_WW--:	natural;
)
port map(
	address_a	=> sgn_Ram_Mix_wr_Addr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_Ram_Mix_Di,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Ram_Mix_wr,--:	in std_logic;
	
	address_b	=> sgn_Ram_Mix_rd_Addr,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Ram_Mix_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- ram for S0
inst02:altsyncram
generic map(
	address_aclr_b					=> "NONE",--:	string := "NONE";
	address_reg_b					=> "CLOCK0",--:	string := "CLOCK0";
	clock_enable_input_a			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_input_b			=> "BYPASS",--:	string := "BYPASS";
	clock_enable_output_b		=> "BYPASS",--:	string := "BYPASS";
	intended_device_family		=> Device_Family,--:	string := Device_Family;--"Cyclone V";
	lpm_type							=> "altsyncram",--:	string := "altsyncram";
	operation_mode					=> "DUAL_PORT",--:	string := "DUAL_PORT";
	outdata_aclr_b					=> "NONE",--:	string := "NONE";
	outdata_reg_b					=> "UNREGISTERED",--:	string := "UNREGISTERED";
	power_up_uninitialized		=> "FALSE",--:	string := "FALSE";
	read_during_write_mode_mixed_ports	=> "OLD_DATA",--:	string := "OLD_DATA";--"DONT_CARE";
	numwords_a						=> cst_RamSize,--:	natural := cst_RamSize;
	numwords_b						=> cst_RamSize,--:	natural := cst_RamSize;
	widthad_a						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	widthad_b						=> cst_RamAddrWidth,--:	natural := cst_RamAddrWidth; -- log2(128)
	width_byteena_a				=> 1,--:	natural := 1

	width_a		=> Size_S*gcst_WW,--:	natural; -- 32
	width_b		=> Size_S*gcst_WW--:	natural;
)
port map(
	address_a	=> sgn_Ram_S0_wr_Addr,--:	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_Ram_S0_Di,--:	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_Ram_S0_wr,--:	in std_logic;
	
	address_b	=> sgn_Ram_S0_rd_Addr,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_Ram_S0_Do,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- FIFO for S_input
inst03: scfifo
generic map(
	add_ram_output_register		=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family		=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width		=> (gcst_AW + gcst_AW + 1) * gcst_WW--: NATURAL; S0 S0/j ID
)
port map(
	data				=> sgn_FIFO_Si_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_Si_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_Si_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_Si_Rd,--: IN STD_LOGIC ;

	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> sgn_FIFO_Si_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

-- FIFO for Mix(n)(i%32) and S_input(0)
inst04: scfifo
generic map(
	add_ram_output_register		=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family		=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width		=> (gcst_AW + 1) * gcst_WW--: NATURAL; Mix0 i
)
port map(
	data				=> sgn_FIFO_Mix0_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_Mix0_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_Mix0_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_Mix0_Rd,--: IN STD_LOGIC ;

	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> sgn_FIFO_Mix0_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst05: scfifo
generic map(
	add_ram_output_register		=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family		=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width		=> (gcst_AW + 1) * gcst_WW--: NATURAL; S0/j ID
)
port map(
	data				=> sgn_FIFO_S0_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_S0_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_S0_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_S0_Rd,--: IN STD_LOGIC ;

	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--sgn_FIFO_S0_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

-- Logic1 Mux sel gen
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_Mux_Mix_Sel <= '0';
	elsif(rising_edge(clk))then
		if(Mem_Ack='1')then
			if(unsigned(Info_Ack.i)=0)then
				sgn_Mux_Mix_Sel <= '0'; -- select S0
			else
				sgn_Mux_Mix_Sel <= '1'; -- select mix(n-1)
			end if;
		end if;
	end if;
end process;

-- Logic3 ram and fifo wr gen
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_MemAck <= '0';
		sgn_Fin	<= '0';
	elsif(rising_edge(clk))then
		if(Mem_Ack='1')then
			if((unsigned(Info_Ack.i) = cst_AccessNum_DAG-1 	and 	Mod_Sel = '0') or -- DAG
			   (unsigned(Info_Ack.i) = cst_AccessNum_H-1 	and 	Mod_Sel = '1') -- hashimoto
			  )then
				sgn_Fin <= '1';
				sgn_MemAck <= '0';
			else
				sgn_Fin <= '0';
				sgn_MemAck <= '1';
			end if;
		else
			sgn_Fin <= '0';
			sgn_MemAck <= '0';
		end if;
	end if;
end process;

-- i increase
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_Info_i <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_Info_i <= unsigned(Info_Ack.i) + 1;
	end if;
end process;

-- connect read Mix(n-1) from ram
sgn_Ram_Mix_rd_Addr <= Info_Ack.ID(cst_RamAddrWidth-1 downto 0);
i0100: for i in 0 to Size_Mix-1 generate
	sgn_Mux_Mix_b(i) <= sgn_Ram_Mix_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0100;

-- connect read S0 from ram
sgn_Ram_S0_rd_Addr <= Info_Ack.ID(cst_RamAddrWidth-1 downto 0);
i0200: for i in 0 to Size_Mix/2-1 generate
	sgn_Mux_Mix_a(i) <= sgn_Ram_S0_Do(gcst_WW*(i+1)-1 downto gcst_WW*i);
	sgn_Mux_Mix_a(i + Size_Mix/2) <= sgn_Ram_S0_Do(gcst_WW*(i+1)-1 downto gcst_WW*i); -- duplicate
end generate i0200;

-- connect store S0/j and ID from Info to fifo
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_FIFO_S0_Di(gcst_AW*gcst_WW-1 downto 0) <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_FIFO_S0_Di(gcst_AW*gcst_WW-1 downto 0) <= Info_Ack.S0;--(IO) 1clk delay
	end if;
end process;
sgn_FIFO_S0_Di((gcst_AW+1)*gcst_WW-1 downto gcst_AW*gcst_WW) <= sgn_Info_ID_DL(0); -- delay 1 clk
sgn_FIFO_S0_Wr <= sgn_MemAck; -- have delayed 1 clk from Mem_Ack

-- Mux S0 and mix(n-1)
i0400: for i in 0 to Size_Mix-1 generate
	process(clk, aclr)
	begin
		if(aclr='1')then
			sgn_Mux_Mix_o(i) <= (others => '0');
		elsif(rising_edge(clk))then
			if(sgn_Mux_Mix_Sel='0')then
				sgn_Mux_Mix_o(i) <= sgn_Mux_Mix_a(i); -- select S0
			else
				sgn_Mux_Mix_o(i) <= sgn_Mux_Mix_b(i); -- select mix(n-1)
			end if;
		end if;
	end process;
end generate i0400;

-- Mem_Di delay 2clk
i0500: for i in 0 to Size_Mix-1 generate
	process(clk,aclr)
	begin
		if(aclr = '1')then
			sgn_Mem_Di_DL1(i) <= (others => '0');
			sgn_Mem_Di_DL2(i) <= (others => '0');
		elsif(rising_edge(clk))then
			sgn_Mem_Di_DL1(i) <= Mem_Di(i); --(IO)
			sgn_Mem_Di_DL2(i) <= sgn_Mem_Di_DL1(i);
		end if;
	end process;
end generate i0500;

-- FNV
i0600: for i in 0 to Size_Mix/cst_FNV_DW-1 generate -- 32
	sgn_FNV_v1(i) <= sgn_Mux_Mix_o(cst_FNV_DW*i+3) & 
						  sgn_Mux_Mix_o(cst_FNV_DW*i+2) & 
						  sgn_Mux_Mix_o(cst_FNV_DW*i+1) & 
						  sgn_Mux_Mix_o(cst_FNV_DW*i+0);
	sgn_FNV_v2(i) <= sgn_Mem_Di_DL2(cst_FNV_DW*i+3) &
						  sgn_Mem_Di_DL2(cst_FNV_DW*i+2) &
						  sgn_Mem_Di_DL2(cst_FNV_DW*i+1) &
						  sgn_Mem_Di_DL2(cst_FNV_DW*i+0); -- (io)
	inst06: Ethash_FNV
	port map(
		Prime	=> FNV_Prime,--: in	std_logic_vector(data_width-1 downto 0);
		v1		=> sgn_FNV_v1(i),--: in	std_logic_vector(data_width-1 downto 0);
		v2		=> sgn_FNV_v2(i),--: in	std_logic_vector(data_width-1 downto 0);
		o		=> sgn_FNV_o(i),--: out	std_logic_vector(data_width-1 downto 0);
		
		clk	=> clk,--: in	std_logic;
		aclr	=> aclr--: in	std_logic
	);
	sgn_FNV_Res(cst_FNV_DW*i+3) <= sgn_FNV_o(i)(gcst_WW*4-1 downto gcst_WW*3);
	sgn_FNV_Res(cst_FNV_DW*i+2) <= sgn_FNV_o(i)(gcst_WW*3-1 downto gcst_WW*2);
	sgn_FNV_Res(cst_FNV_DW*i+1) <= sgn_FNV_o(i)(gcst_WW*2-1 downto gcst_WW*1);
	sgn_FNV_Res(cst_FNV_DW*i+0) <= sgn_FNV_o(i)(gcst_WW*1-1 downto gcst_WW*0);
	
	sgn_SubMux_i(3)(i) <= sgn_FNV_o(i)(gcst_WW*4-1 downto gcst_WW*3);
	sgn_SubMux_i(2)(i) <= sgn_FNV_o(i)(gcst_WW*3-1 downto gcst_WW*2);
	sgn_SubMux_i(1)(i) <= sgn_FNV_o(i)(gcst_WW*2-1 downto gcst_WW*1);
	sgn_SubMux_i(0)(i) <= sgn_FNV_o(i)(gcst_WW*1-1 downto gcst_WW*0);
end generate i0600;

-- connect store sgn_FNV_Res to ram
sgn_Ram_Mix_wr_Addr <= sgn_Info_ID_DL(cst_Info_ID_DL-1)(cst_RamAddrWidth-1 downto 0); -- DL5
i0700: for i in 0 to Size_Mix-1 generate
	sgn_Ram_Mix_Di(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_FNV_Res(i);
end generate i0700;
sgn_Ram_Mix_wr <= sgn_MemAck_DL(1 + gcst_FNVDL - 1); -- DL4

-- Mix output
ID_o <= sgn_Info_ID_DL(cst_Info_ID_DL-1); -- DL5
Mix <= sgn_FNV_Res;
Ed <= sgn_Fin_DL(cst_Fin_DL-1); -- DL4

-- sub words select
--sgn_idx_Mix_std(6 downto 2) <= sgn_Info_i_DL(cst_Info_i_DL-2)(5-1 downto 0); -- DL4
--sgn_idx_Mix_std(1 downto 0) <= (others => '0');
--sgn_idx_Mix_std(7 downto 7) <= (others => '0');
--sgn_idx_Mix <= conv_integer(unsigned(sgn_idx_Mix_std)); -- i%32 (0~31) multiply cst_FNV_DW = 4

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_idx_Mix_std <= (others => '0');
	elsif(rising_edge(clk))then
		if(Mod_Sel = '0')then -- DAG-- i%16 (0~15) multiply cst_FNV_DW = 4
			sgn_idx_Mix_std(5 downto 2) <= sgn_Info_i_DL(1 + gcst_FNVDL - 1 - 1)(4-1 downto 0); -- DL3
			sgn_idx_Mix_std(1 downto 0) <= (others => '0');
			sgn_idx_Mix_std(7 downto 6) <= (others => '0');
		else -- Hashimoto -- i%32 (0~31) multiply cst_FNV_DW = 4
			sgn_idx_Mix_std(6 downto 2) <= sgn_Info_i_DL(1 + gcst_FNVDL - 1 - 1)(5-1 downto 0); -- DL3
			sgn_idx_Mix_std(1 downto 0) <= (others => '0');
			sgn_idx_Mix_std(7 downto 7) <= (others => '0');
		end if;
	end if;
end process;
--sgn_idx_Mix <= conv_integer(unsigned(sgn_idx_Mix_std)); 
--
--process(clk, aclr)
--begin
--	if(aclr = '1')then
--		sgn_SubMux_o <= (others => '0');
--	elsif(rising_edge(clk))then
--		for i in 0 to cst_FNV_DW-1 Loop
--			sgn_SubMux_o(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_FNV_Res(sgn_idx_Mix + i);
--		end Loop;
--	end if;
--end process;

i1200: for i in 0 to cst_FNV_DW-1 generate
	inst10: Lg_Mux_nL1w
	port map(
		Di			=> sgn_SubMux_i(i),--: in	typ_1D_Word(2**nL-1 downto 0);
		Do			=> sgn_SubMux_o(gcst_WW*(i+1)-1 downto gcst_WW*i),--: out	std_logic_vector(gcst_WW-1 downto 0);
		Sel		=> sgn_idx_Mix_std(6 downto 2),--: in	std_logic_vector(nL-1 downto 0);
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i1200;

-- connect store sgn_SubMux_o(Mix(i%32)) and i to fifo
sgn_FIFO_Mix0_Di(cst_FNV_DW*gcst_WW-1 downto 0) <= sgn_SubMux_o;
sgn_FIFO_Mix0_Di((cst_FNV_DW+1)*gcst_WW-1 downto cst_FNV_DW*gcst_WW) <= sgn_Info_i_DL(cst_Info_i_DL-1); -- DL9
sgn_FIFO_Mix0_Wr <= sgn_MemAck_DL(cst_MemAck_DL-1); -- DL9

-- connect store input S to Ram
sgn_Ram_S0_wr_Addr <= ID_i(cst_RamAddrWidth-1 downto 0);
i1000: for i in 0 to Size_S-1 generate
	sgn_Ram_S0_Di(gcst_WW*(i+1)-1 downto gcst_WW*i) <= S_i(i);
end generate i1000;
sgn_Ram_S0_wr <= St;

-- connect push input S0 ID S0/j to fifo
i1100: for i in 0 to gcst_AW-1 generate
	sgn_FIFO_Si_Di((i+1)*gcst_WW-1 downto i*gcst_WW) <= S_i(i);
end generate i1100;
sgn_FIFO_Si_Di((gcst_AW + 1)*gcst_WW-1 downto gcst_AW*gcst_WW) <= ID_i;
sgn_FIFO_Si_Di((gcst_AW + gcst_AW + 1) * gcst_WW-1 downto (gcst_AW + 1) * gcst_WW) <= S0_i;
sgn_FIFO_Si_Wr <= St;

-- Logic2 FIFO read and channel selection gen
sgn_ChSel <= Mem_Valid and (not sgn_FIFO_Mix0_Emp);
sgn_FIFO_Si_Rd <= Mem_Valid and sgn_FIFO_Mix0_Emp and (not sgn_FIFO_Si_Emp);
sgn_FIFO_S0_Rd <= Mem_Valid and (not sgn_FIFO_Mix0_Emp);
sgn_FIFO_Mix0_Rd <= Mem_Valid and (not sgn_FIFO_Mix0_Emp);
sgn_MemReq <= Mem_Valid and (not (sgn_FIFO_Mix0_Emp and sgn_FIFO_Si_Emp));

--process(aclr,Mem_Valid, sgn_FIFO_Mix0_Emp, sgn_FIFO_Si_Emp)
--begin
--	if(aclr='1')then
--		sgn_ChSel <= '0';
--		sgn_FIFO_Si_Rd <= '0';
--		sgn_FIFO_S0_Rd <= '0';
--		sgn_FIFO_Mix0_Rd <= '0';
--		sgn_MemReq <= '0';
--	else
--		if(Mem_Valid = '1')then
--			if(sgn_FIFO_Mix0_Emp='0' and sgn_FIFO_Si_Emp = '0')then
--				sgn_FIFO_Si_Rd <= '0';
--				sgn_FIFO_S0_Rd <= '1';
--				sgn_FIFO_Mix0_Rd <= '1';
--				sgn_ChSel <= '1';
--				sgn_MemReq <= '1';
--			elsif(sgn_FIFO_Mix0_Emp='0' and sgn_FIFO_Si_Emp = '1')then
--				sgn_FIFO_Si_Rd <= '0';
--				sgn_FIFO_S0_Rd <= '1';
--				sgn_FIFO_Mix0_Rd <= '1';
--				sgn_ChSel <= '1';
--				sgn_MemReq <= '1';
--			elsif(sgn_FIFO_Mix0_Emp='1' and sgn_FIFO_Si_Emp = '0')then
--				sgn_FIFO_Si_Rd <= '1';
--				sgn_FIFO_S0_Rd <= '0';
--				sgn_FIFO_Mix0_Rd <= '0';
--				sgn_ChSel <= '0';
--				sgn_MemReq <= '1';
--			elsif(sgn_FIFO_Mix0_Emp='1' and sgn_FIFO_Si_Emp = '1')then
--				sgn_FIFO_Si_Rd <= '0';
--				sgn_FIFO_S0_Rd <= '0';
--				sgn_FIFO_Mix0_Rd <= '0';
--				sgn_MemReq <= '0';
--			end if;
--		else
--			sgn_FIFO_Si_Rd <= '0';
--			sgn_FIFO_S0_Rd <= '0';
--			sgn_FIFO_Mix0_Rd <= '0';
--			sgn_MemReq <= '0';
--		end if;
--	end if;
--end process;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_ChSel_DL <= '0';
	elsif(rising_edge(clk))then
		sgn_ChSel_DL <= sgn_ChSel; -- delay 1clk
	end if;
end process;

-- Channel select
sgn_Ch_a_S0 <= sgn_FIFO_Si_Do((gcst_AW + gcst_AW + 1) * gcst_WW-1 downto (gcst_AW + 1) * gcst_WW); -- S0/j
sgn_Ch_a_Mix <= sgn_FIFO_Si_Do(gcst_AW*gcst_WW-1 downto 0);
sgn_Ch_a_i <= (others => '0');
sgn_Ch_a_ID <= sgn_FIFO_Si_Do((gcst_AW+1)*gcst_WW-1 downto gcst_AW*gcst_WW);

sgn_Ch_b_S0 <= sgn_FIFO_S0_Do(gcst_AW*gcst_WW-1 downto 0); -- S0/j
sgn_Ch_b_Mix <= sgn_FIFO_Mix0_Do(gcst_AW*gcst_WW-1 downto 0);
sgn_Ch_b_i <= sgn_FIFO_Mix0_Do((gcst_AW+1)*gcst_WW-1 downto gcst_AW*gcst_WW);
sgn_Ch_b_ID <= sgn_FIFO_S0_Do((gcst_AW+1)*gcst_WW-1 downto gcst_AW*gcst_WW);

process(clk, aclr)
begin
 if(aclr='1')then
	sgn_Ch_o_S0 <= (others => '0');
	sgn_Ch_o_Mix <= (others => '0');
	sgn_Ch_o_i <= (others => '0');
	sgn_Ch_o_ID <= (others => '0');
 elsif(rising_edge(clk))then
	if(sgn_ChSel_DL = '0')then
		sgn_Ch_o_S0 <= sgn_Ch_a_S0;
		sgn_Ch_o_Mix <= sgn_Ch_a_Mix;
		sgn_Ch_o_i <= sgn_Ch_a_i;
		sgn_Ch_o_ID <= sgn_Ch_a_ID;
	else
		sgn_Ch_o_S0 <= sgn_Ch_b_S0;
		sgn_Ch_o_Mix <= sgn_Ch_b_Mix;
		sgn_Ch_o_i <= sgn_Ch_b_i;
		sgn_Ch_o_ID <= sgn_Ch_b_ID;
	end if;
 end if;
end process;

-- push i and ID_i to FIFO
inst07: scfifo
generic map(
	add_ram_output_register		=> "ON",--: STRING := "ON";
	almost_full_value				=> FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family		=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS					=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead					=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU						=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width		=> (gcst_AW + 1 + 1) * gcst_WW--: NATURAL; S0 + ID_i
)
port map(
	data				=> sgn_FIFO_nr_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_nr_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_nr_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_nr_Rd,--: IN STD_LOGIC ;

	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_FIFO_nr_Di(gcst_WW-1 							downto 0) <= sgn_Ch_o_i;
sgn_FIFO_nr_Di((1+1) * gcst_WW-1 				downto gcst_WW) <= sgn_Ch_o_ID;
sgn_FIFO_nr_Di((gcst_AW+1+1) * gcst_WW-1 		downto (1+1) * gcst_WW) <= sgn_Ch_o_S0;
sgn_FIFO_nr_Wr <= sgn_MemReq_DL(1); -- delay 2 clk

-- Xor S0 and i
process(clk,aclr)
begin
	if(aclr = '1')then
		sgn_aFNV_v1 <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_aFNV_v1 <= sgn_Ch_o_S0 xor (x"000000" & sgn_Ch_o_i);
	end if;
end process;

-- FNV
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_aFNV_v2 <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_aFNV_v2 <= sgn_Ch_o_Mix;
	end if;
end process;

inst08: Ethash_FNV
port map(
	Prime	=> FNV_Prime,--: in	std_logic_vector(data_width-1 downto 0);
	
	v1		=> sgn_aFNV_v1,--: in	std_logic_vector(data_width-1 downto 0);
	v2		=> sgn_aFNV_v2,--: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_aFNV_o,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

-- Mod
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_Mod_b <= (others => '0');
	elsif(rising_edge(clk))then
		if(Mod_Sel = '1') then -- hashimoto
			sgn_Mod_b <= ('0' & n_DAG(gcst_AW*gcst_WW-1 downto 1)); -- /2
		else -- DAG
			sgn_Mod_b <= n_Cache;
		end if;
	end if;
end process;

inst09: Ethash_Mod
port map(
	a		=> sgn_aFNV_o,--: in	std_logic_vector(data_width-1 downto 0);
	b		=> sgn_Mod_b,-- >> 1: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_Addr,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

process(clk,aclr)
begin
	if(aclr='1')then
		Mem_Addr <= (others => '0');
	elsif(rising_edge(clk))then
		if(Mod_Sel = '1')then -- hashimoto
			Mem_Addr <= unsigned(sgn_Addr(gcst_AW*gcst_WW-2 downto 0) & '0') + unsigned(AB_DAG); -- sgn_Addr*2 + AB_DAG (IO)
		else -- DAG
			Mem_Addr <= unsigned(sgn_Addr)  + unsigned(AB_Cache); -- sgn_Addr + AB_DAG
		end if;
	end if;
end process;

-- connect get idx_i and ID_i from FIFO
Info_Req.inst <= Info_Ack.inst;-- fixed outside
Info_Req.i <= sgn_FIFO_nr_Do(gcst_WW-1 downto 0);
Info_Req.ID <= sgn_FIFO_nr_Do(gcst_WW*2-1 downto gcst_WW);
Info_Req.S0 <= sgn_FIFO_nr_Do((gcst_AW+1+1) * gcst_WW-1 downto (1+1) * gcst_WW);
sgn_FIFO_nr_Rd <= sgn_MemReq_DL(cst_MemReq_DL-2); -- DL11 (IO)

Mem_Req <= sgn_MemReq_DL(cst_MemReq_DL-1); -- DL12 (IO)

-- delay
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_MemAck_DL <= (others => '0');
		sgn_Fin_DL <= (others => '0');
		sgn_Info_ID_DL <= (others => (others => '0'));
		sgn_Info_i_DL <= (others => (others => '0'));
		sgn_MemReq_DL <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_MemAck_DL(0) <= sgn_MemAck;
		for i in 1 to cst_MemAck_DL-1 loop -- 5
			sgn_MemAck_DL(i) <= sgn_MemAck_DL(i-1);
		end loop;
		sgn_Fin_DL(0) <= sgn_Fin;
		for i in 1 to cst_Fin_DL-1 loop -- 4
			sgn_Fin_DL(i) <= sgn_Fin_DL(i-1);
		end loop;
		sgn_Info_ID_DL(0) <= Info_Ack.ID; -- 5
		for i in 1 to cst_Info_ID_DL-1 loop
			sgn_Info_ID_DL(i) <= sgn_Info_ID_DL(i-1);
		end loop;
		sgn_Info_i_DL(0) <= sgn_Info_i;
		for i in 1 to cst_Info_i_DL-1 loop -- 5
			sgn_Info_i_DL(i) <= sgn_Info_i_DL(i-1);
		end loop;
		sgn_MemReq_DL(0) <= sgn_MemReq;
		for i in 1 to cst_MemReq_DL-1 loop -- 12
			sgn_MemReq_DL(i) <= sgn_MemReq_DL(i-1);
		end loop;
	end if;
end process;

-- task count
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_TskCnt <= 0;
		Bsy <= '0';
	elsif(rising_edge(clk))then
		if(St = '1' and sgn_Fin_DL(cst_Fin_DL-1) = '1')then
--			sgn_TskCnt <= sgn_TskCnt;
			Bsy <= '1'; -- unchange
		elsif(St = '1' and sgn_Fin_DL(cst_Fin_DL-1) = '0')then
			sgn_TskCnt <= sgn_TskCnt + 1;
			Bsy <= '1';
		elsif(St = '0' and sgn_Fin_DL(cst_Fin_DL-1) = '1')then
			sgn_TskCnt <= sgn_TskCnt - 1;
			if(sgn_TskCnt = 1)then -- last target
				Bsy <= '0';
			end if;
		else
		end if;
	end if;
end process;

end rtl;
