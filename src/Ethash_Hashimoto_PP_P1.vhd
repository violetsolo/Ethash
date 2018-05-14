----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    20/04/2018 
-- Design Name: 
-- Module Name:    Ethash_Hashimoto_PP_P1 - Behavioral
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

entity Ethash_Hashimoto_PP_P1 is
generic(
	Device_Family	: string := "Stratix 10";--"Cyclone V"
	InnerRam_Deep	: Positive := 128; -- "Cyclone V": 128, "Stratix 10": 256
	Size_Head		: Positive := 32;
	Size_nonce		: Positive := 8;
	Size_S			: Positive := 64;
	FIFO_AFNum		: Positive := 22; -- almost full value of fifo
	Hash_PPn			: Positive := 4; -- must be 1 2 3 4 6 8 12 24 
	Mod_Lattic		: Positive := 6
);
port (
	n_Cache	: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outsider = cache size/64
	-- input for hasimoto
	Head		: in	typ_1D_Word(Size_Head-1 downto 0);
	Nonce		: in	typ_1D_Word(Size_nonce-1 downto 0);
	-- input for DAG
	Idx_j		: in	std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	-- input for all
	ID_i		: in	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	-- output for all
	S0_o		: out std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
	S_o		: out	typ_1D_Word(Size_S-1 downto 0);
	ID_o		: out	std_logic_vector(gcst_WW-1 downto 0); -- id of nonce
	-- controllor
	Mod_Sel	: in	std_logic; -- '0' DAG, '1' Hashimoto
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy		: out	std_logic;
	-- Mem req
	AB_Cache	: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);-- must be hold outsider
	
	Mem_Valid	: in std_logic;
	Mem_Addr	: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Info_Req	: out typ_InfoSocket;
	Mem_Req	: out	std_logic; -- only 1 clk
	
	Mem_Di	: in	typ_1D_Word(Size_S-1 downto 0);
	Info_Ack	: in	typ_InfoSocket;
	Mem_Ack	: in	std_logic; -- must be 1 clk
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_Hashimoto_PP_P1;

architecture rtl of Ethash_Hashimoto_PP_P1 is
--============================ constant declare ============================--
constant cst_RamSize			: Positive := InnerRam_Deep;
constant cst_RamAddrWidth	: Positive := Fnc_Int2Wd(cst_RamSize-1);--7; --(log2(128))
constant cst_HashNum_H		: Positive := Size_Head + Size_Nonce; -- 40
constant cst_HashNum_DAG	: Positive := Size_S; --64
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

--===================== user-defined component declare =====================--
component Ethash_Hash3
generic(
	di_Num			: Positive := 200;-- fixed
	do_Num			: Positive := Size_S; -- fixed
	PP_Lattic		: Positive := Hash_PPn -- must be 1 2 3 4 6 8 12 24 
);
port (
	di			: in	typ_1D_Word(di_Num-1 downto 0);
	do			: out	typ_1D_Word(do_Num-1 downto 0);
	Typ		: in	typ_Hash;
	Num		: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			: in	std_logic;
	Ed			: out	std_logic;
	pEd		: out	std_logic;
	ppEd		: out	std_logic;
	Bsy		: out	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Ethash_Mod
generic(
	data_width		: Positive	:= gcst_AW * gcst_WW;--32
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
--============================= signal declare =============================--
signal sgn_FIFO_Nonce_Di		: std_logic_vector(Size_nonce * gcst_WW-1 downto 0);
signal sgn_FIFO_Nonce_Wr		: std_logic;
signal sgn_FIFO_Nonce_Do		: std_logic_vector(Size_nonce * gcst_WW-1 downto 0);
signal sgn_FIFO_Nonce_Rd		: std_logic;
signal sgn_FIFO_Nonce_Emp		: std_logic;

signal sgn_FIFO_ID_Di			: std_logic_vector(1 * gcst_WW-1 downto 0);
signal sgn_FIFO_ID_Wr			: std_logic;
signal sgn_FIFO_ID_Do			: std_logic_vector(1 * gcst_WW-1 downto 0);
signal sgn_FIFO_ID_Rd			: std_logic;

signal sgn_FIFO_S0_Di			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_S0_Wr			: std_logic;
signal sgn_FIFO_S0_Do			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_S0_Rd			: std_logic;

signal sgn_FIFO_Idxj_Di			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_Idxj_Wr			: std_logic;
signal sgn_FIFO_Idxj_Do			: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_Idxj_Rd			: std_logic;

signal sgn_FIFO_Mix_Di			: std_logic_vector(Size_S * gcst_WW-1 downto 0);
signal sgn_FIFO_Mix_Wr			: std_logic;
signal sgn_FIFO_Mix_Do			: std_logic_vector(Size_S * gcst_WW-1 downto 0);
signal sgn_FIFO_Mix_Rd			: std_logic;
signal sgn_FIFO_Mix_Emp			: std_logic;

signal sgn_FIFO_DAG_ID_Di		: std_logic_vector(1 * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_ID_Wr		: std_logic;
signal sgn_FIFO_DAG_ID_Do		: std_logic_vector(1 * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_ID_Rd		: std_logic;

signal sgn_FIFO_DAG_Idxj_Di	: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_Idxj_Wr	: std_logic;
signal sgn_FIFO_DAG_Idxj_Do	: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_Idxj_Rd	: std_logic;

signal sgn_FIFO_DAG_A_Di		: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_A_Wr		: std_logic;
signal sgn_FIFO_DAG_A_Do		: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_FIFO_DAG_A_Rd		: std_logic;
signal sgn_FIFO_DAG_A_Emp		: std_logic;

signal sgn_Mod_o					: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_MemAddr				: std_logic_vector(gcst_AW * gcst_WW-1 downto 0);
signal sgn_MemReq					: std_logic;

signal sgn_Trg_H					: std_logic;
signal sgn_Trg_DAG				: std_logic;

signal sgn_HashDi_a				: typ_1D_Word(Size_S-1 downto 0);
signal sgn_HashDi_b				: typ_1D_Word(Size_S-1 downto 0);
signal sgn_HashSt_a				: std_logic;
signal sgn_HashSt_b				: std_logic;

signal sgn_HashDi					: typ_1D_Word(200-1 downto 0);
signal sgn_HashDo					: typ_1D_Word(Size_S-1 downto 0);
signal sgn_HashSt,sgn_HashEd, sgn_HashBsy		: std_logic;
signal sgn_HashpEd				: std_logic;

signal sgn_HashNum				: Natural;

signal sgn_Idxj					: typ_1D_Word(gcst_AW-1 downto 0);
signal sgn_Mix						: typ_1D_Word(Size_S-1 downto 0);

constant cst_St_DL				: Positive := (Mod_Lattic + 1) + 1;
signal sgn_St_DL					: std_logic_vector(cst_St_DL-1 downto 0);
constant cst_TrgDAG_DL			: Positive := 1 + 1;
signal sgn_TrgDAG_DL				: std_logic_vector(cst_TrgDAG_DL-1 downto 0);

type typ_state is (S_Idle, S_W);
signal state_H,state_DAG 		: typ_state;

signal sgn_TskCnt					: Natural range 0 to cst_RamSize;

signal sgn_St						: std_logic;

--============================ function declare ============================--

begin

-- fifo
inst00: scfifo
generic map(
	lpm_width		=> Size_nonce * gcst_WW--: NATURAL; nonce
)
port map(
	data				=> sgn_FIFO_Nonce_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_Nonce_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_Nonce_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_Nonce_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> sgn_FIFO_Nonce_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst01: scfifo
generic map(
	lpm_width		=> 1 * gcst_WW--: NATURAL; ID
)
port map(
	data				=> sgn_FIFO_ID_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_ID_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_ID_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_ID_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst02: scfifo
generic map(
	lpm_width		=> gcst_AW * gcst_WW--: NATURAL; S0/j inner
)
port map(
	data				=> sgn_FIFO_S0_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_S0_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_S0_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_S0_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst03: scfifo
generic map(
	lpm_width		=> gcst_AW * gcst_WW--: NATURAL; Info_S0/j
)
port map(
	data				=> sgn_FIFO_Idxj_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_Idxj_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_Idxj_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_Idxj_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst04: scfifo
generic map(
	lpm_width		=> Size_S * gcst_WW--: NATURAL; Mix from memory
)
port map(
	data				=> sgn_FIFO_Mix_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_Mix_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_Mix_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_Mix_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> sgn_FIFO_Mix_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst05: scfifo
generic map(
	lpm_width		=> 1 * gcst_WW--: NATURAL; ID for DAG input
)
port map(
	data				=> sgn_FIFO_DAG_ID_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_DAG_ID_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_DAG_ID_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_DAG_ID_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst06: scfifo
generic map(
	lpm_width		=> gcst_AW * gcst_WW--: NATURAL; j for DAG input
)
port map(
	data				=> sgn_FIFO_DAG_Idxj_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_DAG_Idxj_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_DAG_Idxj_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_DAG_Idxj_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

inst07: scfifo
generic map(
	lpm_width		=> gcst_AW * gcst_WW--: NATURAL; Addr for DAG input
)
port map(
	data				=> sgn_FIFO_DAG_A_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_DAG_A_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_DAG_A_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_DAG_A_Rd,--: IN STD_LOGIC ;
	
	almost_full		=> open,--: OUT STD_LOGIC ;
	empty				=> sgn_FIFO_DAG_A_Emp,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

-- DAG cache access
-- j mod n_Cache
inst08: Ethash_Mod
port map(
	a		=> Idx_j,--(IO): in	std_logic_vector(data_width-1 downto 0);
	b		=> n_Cache,--: in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_Mod_o,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk,--: in	std_logic;
	aclr	=> aclr--: in	std_logic
);

-- connect Idx_j to fifo
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_MemAddr <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_MemAddr <= unsigned(sgn_Mod_o) + unsigned(AB_Cache);
	end if;
end process;

sgn_FIFO_DAG_A_Di <= sgn_MemAddr;
sgn_FIFO_DAG_A_Wr <= sgn_St_DL(cst_St_DL-1) and (not Mod_Sel);

-- connect ID idx_j to fifo
sgn_FIFO_DAG_ID_Di <= ID_i; -- (io)
sgn_FIFO_DAG_ID_Wr <= St and (not Mod_Sel); -- (io)
sgn_FIFO_DAG_Idxj_Di <= Idx_j; -- (io)
sgn_FIFO_DAG_Idxj_Wr <= St and (not Mod_Sel); -- (io)

-- Logic1
sgn_MemReq <= Mem_Valid and (not sgn_FIFO_DAG_A_Emp);

-- connect Info_o and Addr from fifo
Info_Req.ID <= sgn_FIFO_DAG_ID_Do; -- (io)
sgn_FIFO_DAG_ID_Rd <= sgn_MemReq;
Info_Req.S0 <= sgn_FIFO_DAG_Idxj_Do; -- (io)
sgn_FIFO_DAG_Idxj_Rd <= sgn_MemReq;

Info_Req.inst <= Info_Ack.inst;
Info_Req.i <= (others => '0');

Mem_Addr <= sgn_FIFO_DAG_A_Do; -- (io)
sgn_FIFO_DAG_A_Rd <= sgn_MemReq;

process(clk,aclr)
begin
	if(aclr='1')then
		Mem_Req <= '0';
	elsif(rising_edge(clk))then
		Mem_Req <= sgn_MemReq; -- (io)
	end if;
end process;

-- hashimoto process
-- connect nonce to fifo
i0100: for i in 0 to Size_nonce-1 generate
	sgn_FIFO_Nonce_Di((i+1)*gcst_WW-1 downto i*gcst_WW) <= Nonce(i);
end generate i0100;
sgn_FIFO_Nonce_Wr <= St and Mod_Sel;

-- connect ID to fifo
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_FIFO_ID_Di <= (others => '0');
		sgn_FIFO_ID_Wr <= '0';
	elsif(rising_edge(clk))then
		if(Mod_Sel = '1')then -- hashimoto
			sgn_FIFO_ID_Di <= ID_i;
			sgn_FIFO_ID_Wr <= St;
		else-- DAG
			sgn_FIFO_ID_Di <= Info_Ack.ID;
			sgn_FIFO_ID_Wr <= Mem_Ack;
		end if;
	end if;
end process;

-- logic3
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_Trg_H <= '0';
		state_H <= S_IDLE;
	elsif(rising_edge(clk))then
		case state_H is
			when S_IDLE =>
				if(sgn_HashBsy = '0' and sgn_FIFO_Nonce_Emp = '0')then
					sgn_Trg_H <= '1';
					state_H <= S_W;
				else
					sgn_Trg_H <= '0';
				end if;
			when S_W =>
				sgn_Trg_H <= '0';
				if(sgn_HashBsy = '1')then
					state_H <= S_Idle;
				end if;
		end case;
	end if;
end process;

-- connect read nonce data from fifo
sgn_HashDi_a(Size_Head-1 downto 0) <= Head;
i0200: for i in 0 to Size_nonce-1 generate
	sgn_HashDi_a(i+Size_Head) <= sgn_FIFO_Nonce_Do((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i0200;
sgn_HashDi_a(Size_S-1 downto Size_Head+Size_nonce) <= (others => (others => '0'));
sgn_FIFO_Nonce_Rd <= sgn_Trg_H;

-- hash st delay
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_HashSt_a <= '0';
	elsif(rising_edge(clk))then
		sgn_HashSt_a <= sgn_Trg_H;
	end if;
end process;

-- DAG process
-- conncet Info_So/j to fifo
sgn_FIFO_Idxj_Di <= Info_Ack.S0;
sgn_FIFO_Idxj_Wr <= Mem_Ack and (not Mod_Sel);

-- connect Mix to fifo
i0300: for i in 0 to Size_S-1 generate
	sgn_FIFO_Mix_Di((i+1)*gcst_WW-1 downto i*gcst_WW) <= Mem_Di(i);
end generate i0300;
sgn_FIFO_Mix_Wr <= Mem_Ack and (not Mod_Sel);

-- logic2
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_Trg_DAG <= '0';
		state_DAG <= S_IDLE;
	elsif(rising_edge(clk))then
		case state_DAG is
			when S_IDLE =>
				if(sgn_HashBsy = '0' and sgn_FIFO_Mix_Emp = '0')then
					sgn_Trg_DAG <= '1';
					state_DAG <= S_W;
				else
					sgn_Trg_DAG <= '0';
				end if;
			when S_W =>
				sgn_Trg_DAG <= '0';
				if(sgn_HashBsy = '1')then
					state_DAG <= S_Idle;
				end if;
		end case;
	end if;
end process;

-- conncet get mix and j from fifo
i0400: for i in 0 to gcst_AW-1 generate
	sgn_Idxj(i) <= sgn_FIFO_Idxj_Do((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i0400;
sgn_FIFO_Idxj_Rd <= sgn_Trg_DAG;

i0500: for i in 0 to Size_S-1 generate
	sgn_Mix(i) <= sgn_FIFO_Mix_Do((i+1)*gcst_WW-1 downto i*gcst_WW);
end generate i0500;
sgn_FIFO_Mix_Rd <= sgn_Trg_DAG;

-- connect j to fifo
sgn_FIFO_S0_Di <= sgn_FIFO_Idxj_Do;
sgn_FIFO_S0_Wr <= sgn_TrgDAG_DL(0); -- DL1

-- xor
i0600: for i in 0 to gcst_AW-1 generate
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_HashDi_b(i) <= (others => '0');
		elsif(rising_edge(clk))then
			sgn_HashDi_b(i) <= sgn_Mix(i) xor sgn_Idxj(i);
		end if;
	end process;
end generate i0600;

-- Mix delay
i0700: for i in gcst_AW to Size_S-1 generate
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_HashDi_b(i) <= (others => '0');
		elsif(rising_edge(clk))then
			sgn_HashDi_b(i) <= sgn_Mix(i);
		end if;
	end process;
end generate i0700;

-- hash
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_HashDi(SIze_S-1 downto 0) <= (others => (others => '0'));
		sgn_HashSt <= '0';
	elsif(rising_edge(clk))then
		if(Mod_Sel = '1')then -- hashimoto
			sgn_HashDi(SIze_S-1 downto 0) <= sgn_HashDi_a;
			sgn_HashSt <= sgn_HashSt_a;
		else-- DAG
			sgn_HashDi(SIze_S-1 downto 0) <= sgn_HashDi_b;
			sgn_HashSt <= sgn_HashSt_b;
		end if;
	end if;
end process;
sgn_HashDi(200-1 downto Size_S) <= (others => (others => '0'));
sgn_HashSt_b <= sgn_TrgDAG_DL(cst_TrgDAG_DL-1);

process(aclr,clk)
begin
	if(aclr='1')then
		sgn_HashNum	<= cst_HashNum_H;
	elsif(rising_edge(clk))then
		if(Mod_Sel = '1')then -- hashimoto
			sgn_HashNum	<= cst_HashNum_H;
		else -- DAG
			sgn_HashNum	<= cst_HashNum_DAG;
		end if;
	end if;
end process;

inst09: Ethash_Hash3
port map(
	di			=> sgn_HashDi,--: in	typ_1D_Word(di_Num-1 downto 0);
	do			=> sgn_HashDo,--: out	typ_1D_Word(do_Num-1 downto 0);
	Typ		=> e_Hash512,--: in	typ_Hash;
	Num		=> sgn_HashNum,--: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			=> sgn_HashSt,--: in	std_logic;
	pEd		=> sgn_HashpEd,--: out	std_logic;
	ppEd		=> open,--: out	std_logic;
	Ed			=> sgn_HashEd,--: out	std_logic;
	
	Bsy		=> sgn_HashBsy,--: out	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- connect get ID and j from fifo 
--sgn_FIFO_ID_Do
sgn_FIFO_ID_Rd <= sgn_HashpEd;
--sgn_FIFO_S0_Do
sgn_FIFO_S0_Rd <= sgn_HashpEd;

-- output
process(clk,aclr)
begin
	if(aclr='1')then
		ID_o <= (others=>'0');
		S0_o <= (others=>'0');
		S_o <= (others => (others => '0'));
		Ed <= '0';
	elsif(rising_edge(clk))then
		ID_o <= sgn_FIFO_ID_Do;
		if(Mod_Sel='1')then-- hashimoto
			S0_o <= sgn_HashDo(3) & sgn_HashDo(2) & sgn_HashDo(1) & sgn_HashDo(0);
		else-- DAG
			S0_o <= sgn_FIFO_S0_Do;
		end if;
		S_o <= sgn_HashDo;
		Ed <= sgn_HashEd;
	end if;
end process;

-- delay
sgn_St <= St;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_St_DL <= (others => '0');
		sgn_TrgDAG_DL <= (others => '0');
	elsif(rising_edge(clk))then
		sgn_St_DL(0) <= sgn_St; -- (io)
		for i in 1 to cst_St_DL-1 loop -- 9
			sgn_St_DL(i) <= sgn_St_DL(i-1);
		end loop;
		sgn_TrgDAG_DL(0) <= sgn_Trg_DAG; -- (io)
		for i in 1 to cst_TrgDAG_DL-1 loop -- 9
			sgn_TrgDAG_DL(i) <= sgn_TrgDAG_DL(i-1);
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
		if(St = '1' and sgn_HashEd = '1')then
--			sgn_TskCnt <= sgn_TskCnt;
			Bsy <= '1'; -- unchange
		elsif(St = '1' and sgn_HashEd = '0')then
			sgn_TskCnt <= sgn_TskCnt + 1;
			Bsy <= '1';
		elsif(St = '0' and sgn_HashEd = '1')then
			sgn_TskCnt <= sgn_TskCnt - 1;
			if(sgn_TskCnt = 1)then -- last target
				Bsy <= '0';
			end if;
		else
		end if;
	end if;
end process;

end rtl;
