----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    25/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hashimoto_PP_vShell - Behavioral
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

entity Ethash_Hashimoto_PP_vShell is
generic(
	Device_Family	: string := "Stratix 10";--"Cyclone V"
	InnerRam_Deep	: Positive := 256; -- "Cyclone V": 128, "Stratix 10": 256
	Mod_Lattic		: Positive := 6; -- less than 31
	Hash_PPn			: Positive := 3 -- must be 1 2 3 4 6 8 12 24 
);
port (
	-- system parameter
	FNV_Prime			: in	std_logic_vector(4*gcst_WW-1 downto 0) := x"01000193"; -- prime for FNV calc, must be hold outsider, default is x"01000193"
	AB_DAG				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- DAG memory address offset, must be hold outsider
	AB_Cache				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- cache memory address offse, must be hold outsider
	ID_inst				: in	std_logic_vector(gcst_WW-1 downto 0);-- instant ID, must be hold outsider
	-- DAG size
	n_DAG					: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- DAG number, which should be devide by 64, must be hold outsider
	n_Cache				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- cache number, which should be devide by 64, must be hold outsider
	-- control signal
	WM_Sel				: in	std_logic; -- work mode select, '0' DAG, '1' Hashimoto
	-- input for hashimoto
	Target				: in	std_logic_vector(32*gcst_WW-1 downto 0); -- Hashimoto target number, must be hold outsider
	Head					: in	std_logic_vector(32*gcst_WW-1 downto 0); -- hashimoto head, must be hold outsider
	Nonce					: in	std_logic_vector(8*gcst_WW-1 downto 0); -- hashimoto nonce
	-- input for DAG
	Idx_j					: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0); -- DAG index (DAG address - AB_DAG), start from 0
	-- input for all process
	St						: in	std_logic; -- task start, this signal must reach while data is ready, and pulse must be hold 1clk per task
	-- output for hasimoto
	Nonce_o				: out	std_logic_vector(8*gcst_WW-1 downto 0); -- result of hashimoto, nonce
	HRes_o				: out	std_logic_vector(64*gcst_WW-1 downto 0); -- result of hashimoto, Hash(s+cmix)
	cMix_o				: out std_logic_vector(32*gcst_WW-1 downto 0); -- result of hashimoto, cmix
	CmpRes_o				: out	std_logic; -- result of hashimoto, compare cmix with Target (cmix < Target)
	-- output for all process;
	Ed						: out	std_logic; -- task end signal, only 1clk duration
	-- pipeline status
	PP_MaxTsk			: in	std_logic_vector(8-1 downto 0); -- the max task capability
	-- PP_MaxTsk must be less than 120, should lager than (20+Mod_Lattic+Mem_DL+4) for full power process, Mem_DL represent delay of geting memory data and is always >=1, 
	PP_CurrTskCnt		: out	std_logic_vector(8-1 downto 0); -- current task number in pipeline
	PP_Valid				: out	std_logic; -- is new task acceptable, '1' valid, '0' invalid
	PP_Bsy				: out std_logic; -- pipeline is working, regardless of target number
	-- memory port
	-- memory data request (only DAG)
	p1_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p1_Info_o_ID		: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce/DAG index
	p1_Info_o_S0		: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); --  DAG index
	p1_Info_o_Inst		: out	std_logic_vector(gcst_WW-1 downto 0); -- instant ID
	p1_Mem_RdReq		: out	std_logic; -- read data request, only 1 clk
	p1_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- memory data acknowledge (only DAG)
	p1_Mem_Di			: in	std_logic_vector(64*gcst_WW-1 downto 0);
	p1_Info_i_ID		: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce/DAG index
	p1_Info_i_S0		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);--  DAG index
	p1_Mem_RdAck		: in	std_logic; -- must be 1 clk
	-- memory data request (DAG and hashimoto)
	p2_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p2_Info_o_ID		: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce/DAG index
	p2_Info_o_S0		: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- S0/ DAG index
	p2_Info_o_Round	: out	std_logic_vector(gcst_WW-1 downto 0); -- round of calculation
	p2_Info_o_Inst		: out	std_logic_vector(gcst_WW-1 downto 0); -- instant ID
	p2_Mem_RdReq		: out	std_logic; -- read data request, only 1 clk
	p2_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- memory data acknowledge (DAG and hashimoto)
	p2_Mem_Di			: in	std_logic_vector(128*gcst_WW-1 downto 0);
	p2_Info_i_ID		: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce/DAG index
	p2_Info_i_S0		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- S0/ DAG index
	p2_Info_i_Round	: in	std_logic_vector(gcst_WW-1 downto 0); -- round of calculation
	p2_Mem_RdAck			: in	std_logic; -- must be 1 clk
	-- memory data write (only DAG)
	p3_Mem_Do			: out	std_logic_vector(64*gcst_WW-1 downto 0);
	p3_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- memory addr
	p3_Mem_WrReq		: out	std_logic; -- write data request, only 1 clk
	p3_Mem_Valid		: in std_logic; -- '1' indicate memory access is valid
	-- clock and asyn-reset
	clk					: in	std_logic; -- clock
	rst					: in	std_logic -- '0' reset
);
end Ethash_Hashimoto_PP_vShell;

architecture rtl of Ethash_Hashimoto_PP_vShell is
--============================ constant declare ============================--
constant	Size_Head		: Positive := 32;
constant	Size_Nonce		: Positive := 8;
constant	Size_cMix		: Positive := 32;
constant	Size_HRes		: Positive := 64;
constant	Size_Mix			: Positive := 128;
constant	FNV_DW			: Positive := 4;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_Hashimoto_PP
generic(
	Device_Family	: string := Device_Family;--"Cyclone V"
	InnerRam_Deep	: Positive := InnerRam_Deep; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Head		: Positive := Size_Head;
	Size_Nonce		: Positive := Size_Nonce;
	Size_cMix		: Positive := Size_cMix;
	Size_HRes		: Positive := Size_HRes;
	Size_Mix			: Positive := Size_Mix;
	Mod_Lattic		: Positive := Mod_Lattic;
	FNV_DW			: Positive := FNV_DW; -- gcst_AW
	Hash_PPn			: Positive := Hash_PPn -- must be 1 2 3 4 6 8 12 24 
);
port (
	-- system parameter
	FNV_Prime			: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0) := x"01000193"; -- must be hold outsider
	AB_DAG				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	AB_Cache				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	ID_inst				: in	std_logic_vector(gcst_WW-1 downto 0);
	-- DAG size
	n_DAG					: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider
	n_Cache				: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider
	-- input for hashimoto
	Target				: in	typ_1D_Word(Size_cMix-1 downto 0); -- must be hold outsider
	Head					: in	typ_1D_Word(Size_Head-1 downto 0); -- must be hold outsider
	Nonce					: in	typ_1D_Word(Size_Nonce-1 downto 0);
	-- output for hasimoto
	Nonce_o				: out	typ_1D_Word(Size_Nonce-1 downto 0);
	HRes_o				: out	typ_1D_Word(Size_HRes-1 downto 0); -- Hash(s+cmix)
	cMix_o				: out typ_1D_Word(Size_cMix-1 downto 0); -- cmix
	CmpRes_o				: out	std_logic; -- is cmix < Target
	-- input for DAG
	Idx_j					: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	-- control signal
	WM_Sel				: in	std_logic; -- '0' DAG, '1' Hashimoto
	St						: in	std_logic; -- start
	Ed						: out	std_logic; -- end 
	-- pipeline status
	PP_MaxTsk			: in	std_logic_vector(8-1 downto 0); -- must be less than 64
	PP_CurrTskCnt		: out	std_logic_vector(8-1 downto 0);
	PP_Valid				: out	std_logic;
	PP_Bsy				: out std_logic; -- pipeline is working
	-- memory data request (only DAG)
	p1_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p1_Info_Req			: out typ_InfoSocket; -- the inst_ID must be set outside, S0 is always '0'
	p1_Mem_Req			: out	std_logic; -- only 1 clk
	p1_Mem_Valid		: in std_logic; -- is memory access valid
	-- memory data acknowledge (only DAG)
	p1_Mem_Di			: in	typ_1D_Word(Size_HRes-1 downto 0);
	p1_Info_Ack			: in	typ_InfoSocket; -- inst_ID, S0 is unused
	p1_Mem_Ack			: in	std_logic; -- must be 1 clk
	-- memory data request (DAG and hashimoto)
	p2_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p2_Info_Req			: out typ_InfoSocket; -- the inst_ID must be set outside
	p2_Mem_Req			: out	std_logic; -- only 1 clk
	p2_Mem_Valid		: in std_logic; -- is memory access valid
	-- memory data acknowledge (DAG and hashimoto)
	p2_Mem_Di			: in	typ_1D_Word(Size_Mix-1 downto 0);
	p2_Info_Ack			: in	typ_InfoSocket; -- inst_ID is unused
	p2_Mem_Ack			: in	std_logic; -- must be 1 clk
	-- memory data write (only DAG)
	p3_Mem_Do			: out	typ_1D_Word(Size_HRes-1 downto 0);
	p3_Mem_Addr			: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p3_Mem_Req			: out	std_logic;
	p3_Mem_Valid		: in std_logic; -- is memory access valid
	-- clock and asyn-clear
	clk					: in	std_logic;
	aclr					: in	std_logic
);
end component;

--============================= signal declare =============================--
signal sgn_Target			: typ_1D_Word(Size_cMix-1 downto 0); -- must be hold outsider
signal sgn_Head			: typ_1D_Word(Size_Head-1 downto 0); -- must be hold outsider
signal sgn_Nonce_i		: typ_1D_Word(Size_Nonce-1 downto 0);
signal sgn_Nonce_o		: typ_1D_Word(Size_Nonce-1 downto 0);
signal sgn_HRes_o			: typ_1D_Word(Size_HRes-1 downto 0); -- Hash(s+cmix)
signal sgn_cMix_o			: typ_1D_Word(Size_cMix-1 downto 0); -- cmix
signal sgn_p1_Mem_Di		: typ_1D_Word(Size_HRes-1 downto 0);
signal sgn_p2_Mem_Di		: typ_1D_Word(Size_Mix-1 downto 0);
signal sgn_p3_Mem_Do		: typ_1D_Word(Size_HRes-1 downto 0);
signal sgn_p1_Info_Req	: typ_InfoSocket; -- the inst_ID must be set outside
signal sgn_p1_Info_Ack	: typ_InfoSocket;
signal sgn_p2_Info_Req	: typ_InfoSocket; -- the inst_ID must be set outside
signal sgn_p2_Info_Ack	: typ_InfoSocket;
signal sgn_aclr			: std_logic;

--signal sgn_ID_i			: std_logic_vector(gcst_WW-1 downto 0);
--============================ function declare ============================--

begin

sgn_aclr <= not rst;

i0100: for i in 0 to Size_cMix-1 generate
	sgn_Target(i) <= Target(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0100;

i0200: for i in 0 to Size_Head-1 generate
	sgn_Head(i) <= Head(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0200;

i0300: for i in 0 to Size_Nonce-1 generate
	sgn_Nonce_i(i) <= Nonce(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0300;

i0400: for i in 0 to Size_HRes-1 generate
	HRes_o(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_HRes_o(i);
end generate i0400;

i0500: for i in 0 to Size_cMix-1 generate
	cMix_o(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_cMix_o(i);
end generate i0500;

i0600: for i in 0 to Size_HRes-1 generate
	sgn_p1_Mem_Di(i) <= p1_Mem_Di(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0600;

i0700: for i in 0 to Size_Mix-1 generate
	sgn_p2_Mem_Di(i) <= p2_Mem_Di(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0700;

i0800: for i in 0 to Size_HRes-1 generate
	p3_Mem_Do(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_p3_Mem_Do(i);
end generate i0800;

i0900: for i in 0 to Size_Nonce-1 generate
	Nonce_o(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_Nonce_o(i);
end generate i0900;

p1_Info_o_ID <= sgn_p1_Info_Req.ID;
p1_Info_o_S0 <= sgn_p1_Info_Req.S0;
p1_Info_o_Inst <= sgn_p1_Info_Req.inst;

sgn_p1_Info_Ack.ID <= p1_Info_i_ID;
sgn_p1_Info_Ack.S0 <= p1_Info_i_S0;
sgn_p1_Info_Ack.i <= (others => '0');
sgn_p1_Info_Ack.inst <= ID_inst;

p2_Info_o_ID <= sgn_p2_Info_Req.ID;
p2_Info_o_S0 <= sgn_p2_Info_Req.S0;
p2_Info_o_Round <= sgn_p2_Info_Req.i;
p2_Info_o_Inst <= sgn_p2_Info_Req.inst;

sgn_p2_Info_Ack.ID <= p2_Info_i_ID;
sgn_p2_Info_Ack.S0 <= p2_Info_i_S0;
sgn_p2_Info_Ack.i <= p2_Info_i_Round;
sgn_p2_Info_Ack.inst <= ID_inst;

inst00: Ethash_Hashimoto_PP
port map(
	-- system parameter
	FNV_Prime			=> FNV_Prime,--: in	std_logic_vector(FNV_DW*gcst_WW-1 downto 0) := x"01000193"; -- must be hold outsider
	AB_DAG				=> AB_DAG,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	AB_Cache				=> AB_Cache,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	ID_inst				=> ID_inst,--: in	std_logic_vector(gcst_WW-1 downto 0);
	-- DAG size
	n_DAG					=> n_DAG,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider
	n_Cache				=> n_Cache,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider
	-- input for hashimoto
	Target				=> sgn_Target,--: in	typ_1D_Word(Size_cMix-1 downto 0); -- must be hold outsider
	Head					=> sgn_Head,--: in	typ_1D_Word(Size_Head-1 downto 0); -- must be hold outsider
	Nonce					=> sgn_Nonce_i,--: in	typ_1D_Word(Size_Nonce-1 downto 0);
	-- output for hasimoto
	Nonce_o				=> sgn_Nonce_o,--: out	typ_1D_Word(Size_Nonce-1 downto 0);
	HRes_o				=> sgn_HRes_o,--: out	typ_1D_Word(Size_HRes-1 downto 0); -- Hash(s+cmix)
	cMix_o				=> sgn_cMix_o,--: out typ_1D_Word(Size_cMix-1 downto 0); -- cmix
	CmpRes_o				=> CmpRes_o,--: out	std_logic; -- is cmix < Target
	-- input for DAG
	Idx_j					=> Idx_j,--: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	-- control signal
	WM_Sel				=> WM_Sel,--: in	std_logic; -- '0' DAG, '1' Hashimoto
	St						=> St,--: in	std_logic; -- start
	Ed						=> Ed,--: out	std_logic; -- end 
	-- pipeline status
	PP_MaxTsk			=> PP_MaxTsk,--: in	std_logic_vector(8-1 downto 0); -- must be less than 32
	PP_CurrTskCnt		=> PP_CurrTskCnt,--: out	std_logic_vector(8-1 downto 0);
	PP_Valid				=> PP_Valid,--: out	std_logic;
	PP_Bsy				=> PP_Bsy,--: out std_logic; -- pipeline is working
	-- memory data request (only DAG)
	p1_Mem_Addr			=> p1_Mem_Addr,--: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p1_Info_Req			=> sgn_p1_Info_Req,--: out typ_InfoSocket; -- the inst_ID must be set outside, i is always '0'
	p1_Mem_Req			=> p1_Mem_RdReq,--: out	std_logic; -- only 1 clk
	p1_Mem_Valid		=> p1_Mem_Valid,--: in std_logic; -- is memory access valid
	-- memory data acknowledge (only DAG)
	p1_Mem_Di			=> sgn_p1_Mem_Di,--: in	typ_1D_Word(Size_HRes-1 downto 0);
	p1_Info_Ack			=> sgn_p1_Info_Ack,--: in	typ_InfoSocket; -- inst_ID, i is unused
	p1_Mem_Ack			=> p1_Mem_RdAck,--: in	std_logic; -- must be 1 clk
	-- memory data request (DAG and hashimoto)
	p2_Mem_Addr			=> p2_Mem_Addr,--: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p2_Info_Req			=> sgn_p2_Info_Req,--: out typ_InfoSocket; -- the inst_ID must be set outside
	p2_Mem_Req			=> p2_Mem_RdReq,--: out	std_logic; -- only 1 clk
	p2_Mem_Valid		=> p2_Mem_Valid,--: in std_logic; -- is memory access valid
	-- memory data acknowledge (DAG and hashimoto)
	p2_Mem_Di			=> sgn_p2_Mem_Di,--: in	typ_1D_Word(Size_Mix-1 downto 0);
	p2_Info_Ack			=> sgn_p2_Info_Ack,--: in	typ_InfoSocket; -- inst_ID is unused
	p2_Mem_Ack			=> p2_Mem_RdAck,--: in	std_logic; -- must be 1 clk
	-- memory data write (only DAG)
	p3_Mem_Do			=> sgn_p3_Mem_Do,--: out	typ_1D_Word(Size_HRes-1 downto 0);
	p3_Mem_Addr			=> p3_Mem_Addr,--: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	p3_Mem_Req			=> p3_Mem_WrReq,--: out	std_logic;
	p3_Mem_Valid		=> p3_Mem_Valid,--: in std_logic; -- is memory access valid
	-- clock and asyn-clear
	clk					=> clk,--: in	std_logic;
	aclr					=> sgn_aclr--: in	std_logic
);

end rtl;
