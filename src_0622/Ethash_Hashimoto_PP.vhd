----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    24/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hashimoto_PP - Behavioral
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

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity Ethash_Hashimoto_PP is
generic(
	Device_Family	: string := "Cyclone V";--"Stratix 10";--"Cyclone V"
	InnerRam_Deep	: Positive := 128; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Head		: Positive := 32;
	Size_Nonce		: Positive := 8;
	Size_cMix		: Positive := 32;
	Size_HRes		: Positive := 64;
	Size_Mix		: Positive := 128;
	Mod_Lattic		: Positive := 6;
	FNV_DW			: Positive := 4; -- gcst_AW
	Hash_PPn		: Positive := 2 -- must be 1 2 3 4 6 8 12 24 
);
port (
	-- system parameter
	FNV_Prime			: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0) := x"01000193"; -- prime for FNV calc, must be hold outsider, default is x"01000193"
	AB_DAG				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- DAG memory address offset, must be hold outsider
	AB_Cache			: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- cache memory address offse, must be hold outsider
	ID_inst				: in	std_logic_vector(gcst_WW-1 downto 0); -- instant ID, must be hold outsider
	-- DAG size
	n_DAG				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- DAG number, which should be devide by 64, must be hold outsider
	n_Cache				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- cache number, which should be devide by 64, must be hold outsider
	-- control signal
	WM_Sel				: in	std_logic := '1'; -- work mode select, '0' DAG, '1' Hashimoto
	-- input for hashimoto
	Target				: in	typ_1D_Word(Size_cMix-1 downto 0); -- Hashimoto target number, must be hold outsider
	Head				: in	typ_1D_Word(Size_Head-1 downto 0); -- hashimoto head, must be hold outsider
	Nonce				: in	typ_1D_Word(Size_Nonce-1 downto 0); -- hashimoto nonce
	-- input for DAG
	Idx_j				: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0); -- DAG index (DAG address - AB_DAG), start from 0
	-- input for all process
	St					: in	std_logic; -- task start, this signal must reach while data is ready, and pulse must be hold 1clk per task
	-- output for hasimoto
	Nonce_o				: out	typ_1D_Word(Size_Nonce-1 downto 0); -- result of hashimoto, nonce
	HRes_o				: out	typ_1D_Word(Size_HRes-1 downto 0); -- result of hashimoto, Hash(s+cmix)
	cMix_o				: out typ_1D_Word(Size_cMix-1 downto 0); -- result of hashimoto, cmix
	CmpRes_o			: out	std_logic; -- result of hashimoto, compare cmix with Target (cmix < Target)
	-- output for all process;
	Ed					: out	std_logic; -- task end signal, only 1clk duration
	-- pipeline status
	PP_MaxTsk			: in	std_logic_vector(8-1 downto 0); -- the max task capability
	-- PP_MaxTsk must be less than 120, should lager than (20+Mod_Lattic+Mem_DL+4) for full power process, Mem_DL represent delay of geting memory data and is always >=1, 
	PP_CurrTskCnt		: out	std_logic_vector(8-1 downto 0); -- current task number in pipeline
	PP_Valid			: out	std_logic; -- is new task acceptable, '1' valid, '0' invalid
	PP_Bsy				: out std_logic; -- pipeline is working, regardless of target number
	-- memory port
	-- memory data request (only DAG)
	p1_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p1_Info_Req			: out typ_InfoSocket; -- id of nonce/DAG index, DAG index, instant ID
	p1_Mem_Req			: out	std_logic; -- read data request, only 1 clk
	p1_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- memory data acknowledge (only DAG)
	p1_Mem_Di			: in	typ_1D_Word(Size_HRes-1 downto 0);
	p1_Info_Ack			: in	typ_InfoSocket; -- id of nonce/DAG index, DAG index
	p1_Mem_Ack			: in	std_logic; -- must be 1 clk
	-- memory data request (DAG and hashimoto)
	p2_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p2_Info_Req			: out typ_InfoSocket; -- id of nonce/DAG index, DAG index, round of calculation, instant ID
	p2_Mem_Req			: out	std_logic; -- read data request, only 1 clk
	p2_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- memory data acknowledge (DAG and hashimoto)
	p2_Mem_Di			: in	typ_1D_Word(Size_Mix-1 downto 0);
	p2_Info_Ack			: in	typ_InfoSocket; -- id of nonce/DAG index, DAG index, round of calculation
	p2_Mem_Ack			: in	std_logic; -- must be 1 clk
	-- memory data write (only DAG)
	p3_Mem_Do			: out	typ_1D_Word(Size_HRes-1 downto 0);
	p3_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p3_Mem_Req			: out	std_logic; -- write data request, only 1 clk
	p3_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- clock and asyn-clear
	clk					: in	std_logic; -- clock
	aclr				: in	std_logic := '0' -- '1' reset
);
end Ethash_Hashimoto_PP;

architecture rtl of Ethash_Hashimoto_PP is
--============================ constant declare ============================--
constant Size_S					: Positive := Size_HRes; -- 64
constant cst_FIFO_AFNum			: Positive := 36;
constant cst_RamSize			: Positive := InnerRam_Deep;
constant cst_RamAddrWidth		: Positive := Fnc_Int2Wd(cst_RamSize-1);--(log2(128))
--======================== Altera component declare ========================--
component scfifo
generic (
	add_ram_output_register		: STRING := "ON";
	almost_full_value			: NATURAL := cst_FIFO_AFNum;
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS				: NATURAL := cst_RamSize;
	lpm_showahead				: STRING := "OFF";
	lpm_type					: STRING := "scfifo";
	lpm_width					: NATURAL;
	LPM_WIDTHU					: NATURAL := cst_RamAddrWidth; -- log2(128)
	overflow_checking			: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab						: STRING := "ON"
);
port (
	data				: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				: IN STD_LOGIC ;

	q					: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				: IN STD_LOGIC ;
	
	almost_full			: OUT STD_LOGIC ;
	empty				: OUT STD_LOGIC ;

	clock				: IN STD_LOGIC ;
	sclr				: IN STD_LOGIC ;
	aclr				: IN STD_LOGIC 
);
END component;
--===================== user-defined component declare =====================--
component Ethash_Hashimoto_PP_P1
generic(
	Device_Family	: string := Device_Family;--"Cyclone V"
	InnerRam_Deep	: Positive := InnerRam_Deep; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Head		: Positive := Size_Head;
	Size_Nonce		: Positive := Size_Nonce;
	Size_S			: Positive := Size_S;
	FIFO_AFNum		: Positive := cst_FIFO_AFNum; -- almost full value of fifo
	Hash_PPn		: Positive := Hash_PPn; -- must be 1 2 3 4 6 8 12 24 
	Mod_Lattic		: Positive := Mod_Lattic
);
port (
	n_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	-- input for hasimoto
	Head		: in	typ_1D_Word(Size_Head-1 downto 0);
	Nonce		: in	typ_1D_Word(Size_nonce-1 downto 0);
	-- input for DAG
	Idx_j		: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	-- input for all
	ID_i		: in	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	-- output for all
	S0_o		: out std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	S_o			: out	typ_1D_Word(Size_S-1 downto 0);
	ID_o		: out	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	-- controllor
	Mod_Sel		: in	std_logic; -- '0' DAG, '1' Hashimoto
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy			: out	std_logic;
	-- Mem req
	AB_Cache	: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	: in std_logic;
	Mem_Addr	: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req	: out typ_InfoSocket;
	Mem_Req		: out	std_logic; -- only 1 clk
	
	Mem_Di		: in	typ_1D_Word(Size_S-1 downto 0);
	Info_Ack	: in	typ_InfoSocket;
	Mem_Ack		: in	std_logic; -- must be 1 clk
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;

component Ethash_Hashimoto_PP_P2
generic(
	Device_Family	: string := Device_Family;--"Cyclone V"
	InnerRam_Deep	: Positive := InnerRam_Deep; -- "Cyclone V": 128, "Stratix 10": 256
	Size_S			: Positive := Size_S;
	Size_Mix		: Positive := Size_Mix; -- Size_Mix = Size_S*2
	FIFO_AFNum		: Positive := cst_FIFO_AFNum; -- almost full value of input fifo
	FNV_DW			: Positive := FNV_DW;
	Mod_Lattic		: Positive := Mod_Lattic
);
port (
	n_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	n_DAG		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = DAG size/64
	FNV_Prime	: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	
	S0_i		: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	S_i			: in	typ_1D_Word(Size_S-1 downto 0);
	ID_i		: in	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	
	Mix			: out	typ_1D_Word(Size_Mix-1 downto 0);
	ID_o		: out	std_logic_vector(gcst_IDW * gcst_WW-1 downto 0); -- id of nonce
	
	Mod_Sel		: in	std_logic; -- '0' DAG, '1' Hashimoto
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy			: out	std_logic; -- is there any task in process or in sequence
	
	AB_Cache	: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	AB_DAG		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	: in std_logic;
	Mem_Addr	: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req	: out typ_InfoSocket;
	Mem_Req		: out	std_logic; -- only 1 clk
	
	Mem_Di		: in	typ_1D_Word(Size_Mix-1 downto 0);
	Info_Ack	: in	typ_InfoSocket;
	Mem_Ack		: in	std_logic; -- must be 1 clk
		
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;

component Ethash_Hashimoto_PP_P3
generic(
	Device_Family	: string := Device_Family;--"Cyclone V"
	InnerRam_Deep	: Positive := InnerRam_Deep; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Nonce		: Positive := 8;
	Size_S			: Positive := Size_S;
	Size_cMix		: Positive := Size_cMix;
	Size_Mix		: Positive := Size_Mix; -- Size_Mix = Size_S*2
	FIFO_AFNum		: Positive := cst_FIFO_AFNum; -- almost full value of input fifo
	FNV_DW			: Positive := FNV_DW;
	Hash_PPn		: Positive := Hash_PPn -- must be 1 2 3 4 6 8 12 24 
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
	
	Mod_Sel		: in	std_logic; -- '0' DAG, '1' Hashimoto
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy			: out	std_logic; -- is there any task in process or in sequence
	
	clk			: in	std_logic;
	aclr		: in	std_logic := '0'
);
end component;
--============================= signal declare =============================--
signal 	sgn_S0_p1_p2			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal	sgn_S_p1_p2				: typ_1D_Word(Size_S-1 downto 0);
signal	sgn_ID_p1_p2			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal	sgn_St_p1_p2			: std_logic;

signal	sgn_Mix_p2_p3			: typ_1D_Word(Size_Mix-1 downto 0);
signal	sgn_ID_p2_p3			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal	sgn_St_p2_p3			: std_logic;

signal	sgn_S_i_p1_p3			: typ_1D_Word(Size_S-1 downto 0); -- S from proc1
signal	sgn_S_A_p1_p3			: std_logic_vector(gcst_IDW*gcst_WW-1 downto 0); -- nID from proc1
signal	sgn_S_wr_p1_p3			: std_logic; -- st from proc1

signal sgn_TskCnt				: Natural range 0 to cst_RamSize;
signal sgn_PPv_TskCnt			: Natural range 0 to cst_RamSize;
signal sng_PP_Valid				: std_logic;

signal sgn_Ed					: std_logic;

signal sgn_Info_p1				: typ_InfoSocket;
signal sgn_Info_p2				: typ_InfoSocket;

signal sgn_FIFO_ID_Di			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal sgn_FIFO_ID_Wr			: std_logic;
signal sgn_FIFO_ID_Do			: std_logic_vector(gcst_IDW * gcst_WW-1 downto 0);
signal sgn_FIFO_ID_Rd			: std_logic;

signal sgn_ID_i					: std_logic_vector(gcst_IDW *  gcst_WW-1 downto 0);
signal sgn_ID_o					: std_logic_vector(gcst_IDW *  gcst_WW-1 downto 0);
signal sgn_ID_Init_Sel			: std_logic; -- '0' initial ID '1' recycled ID
signal sgn_ID_Init				: std_logic_vector(gcst_IDW *  gcst_WW-1 downto 0);
signal sgn_ID_Init_Wr			: std_logic;
signal sgn_ID_Init_Cnt			: std_logic_vector(gcst_IDW * gcst_WW+1-1 downto 0);

signal sgn_St					: std_logic;
signal sgn_Nonce				: typ_1D_Word(Size_Nonce-1 downto 0);
signal sgn_Idx_j				: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_ID_En				: std_logic;

signal sgn_Nonce_o				: typ_1D_Word(Size_Nonce-1 downto 0);
signal sgn_HRes_o				: typ_1D_Word(Size_HRes-1 downto 0);
signal sgn_cMix_o				: typ_1D_Word(Size_cMix-1 downto 0);
signal sgn_CmpRes_o				: std_logic;

signal sgn_n_DAG				: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_n_Cache				: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_Target				: typ_1D_Word(Size_cMix-1 downto 0);
signal sgn_Head					: typ_1D_Word(Size_Head-1 downto 0);

signal sgn_p1_Mem_Addr			: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_p1_Info_Req			: typ_InfoSocket;
signal sgn_p1_Mem_Req			: std_logic;
signal sgn_p2_Mem_Addr			: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_p2_Info_Req			: typ_InfoSocket;
signal sgn_p2_Mem_Req			: std_logic;
signal sgn_p3_Mem_Do			: typ_1D_Word(Size_HRes-1 downto 0);
signal sgn_p3_Mem_Addr			: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_p3_Mem_Req			: std_logic;

signal sgn_p1_Mem_Valid			: std_logic;
signal sgn_p2_Mem_Valid			: std_logic;
signal sgn_p3_Mem_Valid			: std_logic;

type typ_state is (S_IDLE, S_Init);
signal state					: typ_state;
--============================ function declare ============================--

begin
sgn_Info_p1.S0 <= p1_Info_Ack.S0;
sgn_Info_p1.i <= (others => '0');
sgn_Info_p1.ID <= p1_Info_Ack.ID;
sgn_Info_p1.inst <= ID_inst; -- (io)

inst01: Ethash_Hashimoto_PP_P1
port map(
	n_Cache		=> sgn_n_Cache,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	-- input for hasimoto
	Head		=> sgn_Head,--(io): in	typ_1D_Word(Size_Head-1 downto 0);
	Nonce		=> sgn_Nonce,--: in	typ_1D_Word(Size_nonce-1 downto 0);
	-- input for DAG
	Idx_j		=> sgn_Idx_j,--: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	-- input for all
	ID_i		=> sgn_ID_i,--: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	-- output for all
	S0_o		=> sgn_S0_p1_p2,--: out std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	S_o			=> sgn_S_p1_p2,--: out	typ_1D_Word(Size_S-1 downto 0);
	ID_o		=> sgn_ID_p1_p2,--: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	-- controllor
	Mod_Sel		=> WM_Sel,--(io): in	std_logic; -- '0' DAG, '1' Hashimoto
	St			=> sgn_St,--(io): in	std_logic;
	Ed			=> sgn_St_p1_p2,--: out	std_logic;
	Bsy			=> open,--: out	std_logic;
	-- Mem req
	AB_Cache	=> AB_Cache,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	=> sgn_p1_Mem_Valid,--(io): in std_logic;
	Mem_Addr	=> sgn_p1_Mem_Addr,--(io): out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req	=> sgn_p1_Info_Req,--(io): out typ_InfoSocket;
	Mem_Req		=> sgn_p1_Mem_Req,--(io): out	std_logic; -- only 1 clk
	
	Mem_Di		=> p1_Mem_Di,--(io): in	typ_1D_Word(Size_S-1 downto 0);
	Info_Ack	=> sgn_Info_p1,--(io): in	typ_InfoSocket;
	Mem_Ack		=> p1_Mem_Ack,--(io): in	std_logic; -- must be 1 clk
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

sgn_Info_p2.S0 <= p2_Info_Ack.S0;
sgn_Info_p2.i <= p2_Info_Ack.i;
sgn_Info_p2.ID <= p2_Info_Ack.ID;
sgn_Info_p2.inst <= ID_inst; -- (io)

inst02: Ethash_Hashimoto_PP_P2
port map(
	n_Cache		=> sgn_n_Cache,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	n_DAG		=> sgn_n_DAG,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = DAG size/64
	FNV_Prime	=> FNV_Prime,--(io): in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	
	S0_i		=> sgn_S0_p1_p2,--: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	S_i			=> sgn_S_p1_p2,--: in	typ_1D_Word(Size_S-1 downto 0);
	ID_i		=> sgn_ID_p1_p2,--: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	
	Mix			=> sgn_Mix_p2_p3,--: out	typ_1D_Word(Size_Mix-1 downto 0);
	ID_o		=> sgn_ID_p2_p3,--: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	
	Mod_Sel		=> WM_Sel,--(io): in	std_logic; -- '0' DAG, '1' Hashimoto
	St			=> sgn_St_p1_p2,--: in	std_logic;
	Ed			=> sgn_St_p2_p3,--: out	std_logic;
	Bsy			=> open,--: out	std_logic; -- is there any task in process or in sequence
	
	AB_Cache	=> AB_Cache,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	AB_DAG		=> AB_DAG,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	=> sgn_p2_Mem_Valid,--(io): in std_logic;
	Mem_Addr	=> sgn_p2_Mem_Addr,--(io): out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req	=> sgn_p2_Info_Req,--(io): out typ_InfoSocket;
	Mem_Req		=> sgn_p2_Mem_Req,--(io): out	std_logic; -- only 1 clk
	
	Mem_Di		=> p2_Mem_Di,--(io): in	typ_1D_Word(Size_Mix-1 downto 0);
	Info_Ack	=> sgn_Info_p2,--(io): in	typ_InfoSocket;
	Mem_Ack		=> p2_Mem_Ack,--(io): in	std_logic; -- must be 1 clk
		
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

i0100: for i in 0 to gcst_AW-1 generate -- 0~3
	sgn_S_i_p1_p3(i) <= sgn_S0_p1_p2((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i0100;
sgn_S_i_p1_p3(Size_S-1 downto gcst_AW) <= sgn_S_p1_p2(Size_S-1 downto gcst_AW);
sgn_S_A_p1_p3 <= sgn_ID_p1_p2;
sgn_S_wr_p1_p3 <= sgn_St_p1_p2;

inst03:Ethash_Hashimoto_PP_P3
port map(
	FNV_Prime	=> FNV_Prime,--(io): in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0);
	Target		=> sgn_Target,--(io): in	typ_1D_Word(Size_cMix-1 downto 0);
	-- input form outter, nonce
	Nonce_i		=> sgn_Nonce,--: in	typ_1D_Word(Size_Nonce-1 downto 0);
	Nonce_A		=> sgn_ID_i,--: in	std_logic_vector(gcst_WW-1 downto 0); -- nID from outter
	Nonce_Wr	=> sgn_St,--: in	std_logic; -- st form outter
	-- input from proc1, S0/j
	S_i			=> sgn_S_i_p1_p3,--: in	typ_1D_Word(Size_S-1 downto 0); -- S from proc1
	S_A			=> sgn_S_A_p1_p3,--: in	std_logic_vector(gcst_WW-1 downto 0); -- nID from proc1
	S_wr		=> sgn_S_wr_p1_p3,--: in	std_logic; -- st from proc1
	-- input from proc2
	ID_i		=> sgn_ID_p2_p3,--: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	Mix_i		=> sgn_Mix_p2_p3,--: in	typ_1D_Word(Size_Mix-1 downto 0);
	-- Hashimoto result output
	Nonce_o		=> sgn_Nonce_o,--: out	typ_1D_Word(Size_Nonce-1 downto 0);
	HRes_o		=> sgn_HRes_o,--(io): out	typ_1D_Word(Size_S-1 downto 0);
	cMix_o		=> sgn_cMix_o,--(io): out typ_1D_Word(Size_cMix-1 downto 0);
	ID_o		=> sgn_ID_o,--: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	CmpRes_o	=> sgn_CmpRes_o,--(io): out	std_logic;
	-- DAG result write to memory
	AB_DAG		=> AB_DAG,--(io): in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Mem_Valid	=> sgn_p3_Mem_Valid,--(io): in	std_logic;
	
	Mem_Do		=> sgn_p3_Mem_Do,--(io): out	typ_1D_Word(Size_S-1 downto 0);
	Mem_Addr	=> sgn_p3_Mem_Addr,--(io): out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Mem_Req		=> sgn_p3_Mem_Req,--(io): out	std_logic;
	
	Mod_Sel		=> WM_Sel,--(io): in	std_logic; -- '0' DAG, '1' Hashimoto
	St			=> sgn_St_p2_p3,--: in	std_logic;
	Ed			=> sgn_Ed,--: out	std_logic;
	Bsy			=> open,--: out	std_logic; -- is there any task in process or in sequence
	
	clk			=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

process(clk,aclr)
begin
	if(aclr='1')then
		Ed <= '0';
	elsif(rising_edge(clk))then
		Ed <= sgn_Ed;
	end if;
end process;

process(clk)
begin
	if(rising_edge(clk))then
		Nonce_o <= sgn_Nonce_o;
		HRes_o <= sgn_HRes_o;
		cMix_o <= sgn_cMix_o;
		CmpRes_o <= sgn_CmpRes_o;
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		p1_Mem_Req <= '0';
		p2_Mem_Req <= '0';
		p3_Mem_Req <= '0';
	elsif(rising_edge(clk))then
		p1_Mem_Req <= sgn_p1_Mem_Req;
		p2_Mem_Req <= sgn_p2_Mem_Req;
		p3_Mem_Req <= sgn_p3_Mem_Req;
	end if;
end process;

process(clk)
begin
	if(rising_edge(clk))then
		p1_Mem_Addr <= sgn_p1_Mem_Addr;
		p1_Info_Req <= sgn_p1_Info_Req;
		
		p2_Mem_Addr <= sgn_p2_Mem_Addr;
		p2_Info_Req <= sgn_p2_Info_Req;
		
		p3_Mem_Do <= sgn_p3_Mem_Do;
		p3_Mem_Addr <= sgn_p3_Mem_Addr;
	end if;
end process;

-- ID generate
inst04: scfifo
generic map(
	add_ram_output_register		=> "ON",--: STRING := "ON";
	almost_full_value			=> cst_FIFO_AFNum,--: NATURAL := cst_FIFO_AFNum;
	intended_device_family		=> Device_Family,--: STRING := Device_Family;--"Cyclone V";
	LPM_NUMWORDS				=> cst_RamSize,--: NATURAL := cst_RamSize;
	lpm_showahead				=> "OFF",--: STRING := "OFF";
	LPM_WIDTHU					=> cst_RamAddrWidth,--: NATURAL := cst_RamAddrWidth; -- log2(128)
	lpm_width					=> gcst_IDW * gcst_WW--: NATURAL; nonce
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

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_FIFO_ID_Wr <= '0';
	elsif(rising_edge(clk))then
		if(sgn_ID_Init_Sel = '1')then
			sgn_FIFO_ID_Wr <= sgn_Ed; -- recycle ID
		else
			sgn_FIFO_ID_Wr <= sgn_ID_Init_Wr; -- initial ID
		end if;
	end if;
end process;

process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_ID_Init_Sel = '1')then
			sgn_FIFO_ID_Di <= sgn_ID_o; -- recycle ID
		else
			sgn_FIFO_ID_Di <= sgn_ID_Init; -- initial ID
		end if;
	end if;
end process;

sgn_ID_i <= sgn_FIFO_ID_Do; -- generate new ID
sgn_FIFO_ID_Rd <= St;

process(aclr,clk)
begin
	if(aclr='1')then
		sgn_ID_Init_Sel <= '0';
		state <= S_Init;
		sgn_ID_Init <= (others => '0');
		sgn_ID_Init_Cnt <= (others => '0');
		sgn_ID_Init_Wr <= '0';
		sgn_ID_En <= '0';
	elsif(rising_edge(clk))then
		sgn_ID_Init <= sgn_ID_Init_Cnt(gcst_IDW*gcst_WW-1 downto 0);
		case state is
			when S_IDLE =>
				sgn_ID_Init_Sel <= '1';
				sgn_ID_Init_Wr <= '0';
				sgn_ID_En <= '1';
			when S_Init =>
				sgn_ID_Init_Cnt <= unsigned(sgn_ID_Init_Cnt) + 1;
				if(unsigned(sgn_ID_Init_Cnt) = cst_RamSize)then
					sgn_ID_Init_Sel <= '1';
					sgn_ID_Init_Wr <= '0';
					state <= S_IDLE;
				else
					sgn_ID_Init_Sel <= '0';
					sgn_ID_Init_Wr <= '1';
					state <= S_Init;
				end if;
			when others => state <= S_IDLE;
		end case;
	end if;
end process;

-- input reg
process(clk)
begin
	if(rising_edge(clk))then
		sgn_n_DAG <= n_DAG;
		sgn_n_Cache <= n_Cache;
		sgn_Target <= Target;
		sgn_Head <= Head;
	end if;
end process;

process(clk,aclr)
begin
	if(aclr='1')then
		sgn_p1_Mem_Valid <= '0';
		sgn_p2_Mem_Valid <= '0';
		sgn_p3_Mem_Valid <= '0';
	elsif(rising_edge(clk))then
		sgn_p1_Mem_Valid <= p1_Mem_Valid;
		sgn_p2_Mem_Valid <= p2_Mem_Valid;
		sgn_p3_Mem_Valid <= p3_Mem_Valid;
	end if;
end process;

process(clk) -- input delay 1 clk wait for ID generate from fifo
begin
	if(rising_edge(clk))then
		sgn_Nonce <= Nonce;
		sgn_Idx_j <= Idx_j;
	end if;
end process;

process(clk,aclr) -- input delay 1 clk wait for ID generate from fifo
begin
	if(aclr='1')then
		sgn_St <= '0';
	elsif(rising_edge(clk))then
		sgn_St <= St;
	end if;
end process;

---- task count
PP_CurrTskCnt <= conv_std_logic_vector(sgn_TskCnt,8);

process(clk, aclr)
begin
	if(aclr='1')then
		sgn_TskCnt <= 0;
	elsif(rising_edge(clk))then
		if(St = '1' and sgn_Ed = '0')then
			sgn_TskCnt <= sgn_TskCnt + 1;
		elsif(St = '0' and sgn_Ed = '1')then
			sgn_TskCnt <= sgn_TskCnt - 1;
		else
			-- do nothing
		end if;
	end if;
end process;

process(clk, aclr)
begin
	if(aclr='1')then
		PP_Bsy <= '0';
	elsif(rising_edge(clk))then
		if(St = '1')then
			PP_Bsy <= '1'; -- unchange
		else
			if(sgn_TskCnt = 1 and sgn_Ed = '1')then -- last target
				PP_Bsy <= '0';
			end if;
		end if;
	end if;
end process;

-- pp_valid counter and logic
process(clk, aclr) -- PP_Valid should be set after process 2 finish
begin
	if(aclr='1')then
		sgn_PPv_TskCnt <= 0;
	elsif(rising_edge(clk))then
		if(St = '1' and sgn_St_p2_p3 = '0')then
			sgn_PPv_TskCnt <= sgn_PPv_TskCnt + 1;
		elsif(St = '0' and sgn_St_p2_p3 = '1')then
			sgn_PPv_TskCnt <= sgn_PPv_TskCnt - 1;
		else
			-- do nothing
		end if;
	end if;
end process;

process(clk, aclr)
begin
	if(aclr='1')then
		sng_PP_Valid <= '1';
	elsif(rising_edge(clk))then
		if(sgn_PPv_TskCnt = unsigned(PP_MaxTsk) and St = '0' and sgn_St_p2_p3 = '1')then -- task number is PP_MaxTsk and 1 task finish 
			sng_PP_Valid <= '1';
		elsif(sgn_PPv_TskCnt = unsigned(PP_MaxTsk) - 1 and St = '1' and sgn_St_p2_p3 = '0')then -- task number is PP_MaxTsk-1 and 1 task come 
			sng_PP_Valid <= '0';
		elsif(sgn_PPv_TskCnt >= unsigned(PP_MaxTsk))then -- lager than PP_MaxTsk 
			sng_PP_Valid <= '0';
		else
			sng_PP_Valid <= '1';
		end if;
	end if;
end process;

PP_Valid <= sgn_ID_En and sng_PP_Valid;

end rtl;
