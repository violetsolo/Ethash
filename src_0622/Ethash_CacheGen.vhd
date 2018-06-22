----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    16/04/2018 
-- Design Name: 
-- Module Name:    Ethash_CacheGen - Behavioral
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

entity Ethash_CacheGen is
generic(
	Size_Seed		: Positive := 32;
	Size_Data		: Positive := 64;
	Mod_Lattic		: Positive := 17
);
port (
	Seed			: in	typ_1D_Word(Size_Seed-1 downto 0);
	n_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outside
	AB_Cache		: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	
	Mem_Do		: out	typ_1D_Word(Size_Data-1 downto 0);
	Mem_Di		: in	typ_1D_Word(Size_Data-1 downto 0);
	Mem_Addr		: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Req_Wr		: out	std_logic;
	Req_Rd		: out	std_logic;
	Ack			: in	std_logic; -- must be hold 1 clk
	
	St			: in	std_logic;
	Ed			: out	std_logic;
	Bsy_P1	: out	std_logic;
	Bsy_P2	: out std_logic;
	Bsy		: out std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic := '0'
);
end Ethash_CacheGen;

architecture rtl of Ethash_CacheGen is
--============================ constant declare ============================--
constant cst_HashType		: typ_Hash := e_Hash512;
constant cst_Hash32_Num		: Positive := Size_Seed; -- 32
constant cst_Hash64_Num		: Positive := Size_Data; -- 64
constant cst_HashInSize		: Positive := 200;
constant cst_SRM_Round		: Positive := 3;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_Hash3
generic(
	di_Num			: Positive := cst_HashInSize;-- fixed
	do_Num			: Positive := Size_Data; -- fixed
	PP_Lattic		: Positive := 1 -- must be 1 2 3 4 6 8 12 24 
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
	aclr		: in	std_logic := '0'
);
end component;

component Ethash_Mod
generic(
	data_width		: Positive	:= gcst_AW * gcst_WW;
	sft_num			: Natural	:= Mod_Lattic
);
port (
	a		: in	std_logic_vector(data_width-1 downto 0);
	b		: in	std_logic_vector(data_width-1 downto 0);
	o		: out	std_logic_vector(data_width-1 downto 0);
	
	clk	: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_HashDi 					: typ_1D_Word(cst_HashInSize-1 downto 0);
signal sgn_HashRes					: typ_1D_Word(Size_Data-1 downto 0);
signal sgn_HashSt, sgn_HashEd		: std_logic;
signal sgn_HashNum					: Natural;

signal sgn_Xor_a, sgn_Xor_b, sgn_Xor_o		: typ_1D_Word(Size_Data-1 downto 0);

type typ_state is (S_IDLE, S_P1_Work, S_P1_Mem, 
						 S_P2_R, S_P2_GetA1, S_P2_GetO1, S_P2_GetO2, S_P2_Hash, S_P2_Mem);
signal state							: typ_state;
signal sgn_st							: std_logic;
signal sgn_Ack_o1, sgn_Ack_o2		: std_logic;
signal sgn_Ack_A1, sgn_Ack_WR		: std_logic;
signal sgn_Ack_o1_DL, sgn_Ack_WR_DL		: std_logic;

signal sgn_Ack_DL						: std_logic_vector(Mod_Lattic downto 0);
signal sgn_A1, sgn_A2				: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_idx							: std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
signal sgn_SRM_Round					: Natural range 0 to cst_SRM_Round;
signal sgn_Ack_Sel					: std_logic_vector(3 downto 0);
--============================ function declare ============================--

--============================ attribute declare ============================--
attribute maxfan : natural;
attribute maxfan of sgn_HashEd : signal is gAttribut_maxFanout;
attribute maxfan of sgn_Ack_o1 : signal is gAttribut_maxFanout;
attribute maxfan of sgn_Ack_o2 : signal is gAttribut_maxFanout;

begin

-- Hash
inst00: Ethash_Hash3
port map(
	di			=> sgn_HashDi,--: in	typ_1D_Word(di_Num-1 downto 0);
	do			=> sgn_HashRes,--: out	typ_1D_Word(do_Num-1 downto 0);
	Typ		=> cst_HashType,--: in	typ_Hash;
	Num		=> sgn_HashNum,--: in	Natural;-- range 1 to 199; -- must be less than 71 for Hash512, must be less than 135 for Hash256
	
	St			=> sgn_HashSt,--: in	std_logic;
	Ed			=> sgn_HashEd,--: out	std_logic;
	pEd		=> open,--: out	std_logic;
	ppEd		=> open,--: out	std_logic;
	Bsy		=> open,--: out	std_logic;
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- xor
sgn_Xor_a <= sgn_HashDi(Size_Data-1 downto 0);
sgn_Xor_b <= Mem_Di;
i0100: for i in 0 to Size_Data-1 generate
process(clk)
	begin
		if(rising_edge(clk))then
			sgn_Xor_o(i) <= sgn_Xor_a(i) xor sgn_Xor_b(i);
		end if;
	end process;
end generate i0100;

-- mux and latch
process(clk)
begin
	if(rising_edge(clk))then
		if(St = '1')then
			sgn_HashDi(Size_Seed-1 					downto 0) 				<= Seed; -- (io)
			sgn_HashDi(cst_HashInSize-1 			downto Size_Seed) 	<= (others => (others => '0'));
		elsif(sgn_HashEd = '1')then
			sgn_HashDi(Size_Data-1 					downto 0) 				<= sgn_HashRes;
			sgn_HashDi(cst_HashInSize-1 			downto Size_Data) 	<= (others => (others => '0'));
		elsif(sgn_Ack_o1 = '1')then
			sgn_HashDi(Size_Data-1 					downto 0) 				<= Mem_Di; -- (io)
			sgn_HashDi(cst_HashInSize-1 			downto Size_Data) 	<= (others => (others => '0'));
		elsif(sgn_Ack_o2 = '1')then
			sgn_HashDi(Size_Data-1 					downto 0) 				<= sgn_Xor_o;
			sgn_HashDi(cst_HashInSize-1 			downto Size_Data) 	<= (others => (others => '0'));
		end if;

	end if;
end process;

Mem_Do <= sgn_HashDi(Size_Data-1 downto 0); -- (io)

-- mod
inst01:Ethash_Mod
port map(
	a		=> (Mem_Di(3) & Mem_Di(2) & Mem_Di(1) & Mem_Di(0)),--(io): in	std_logic_vector(data_width-1 downto 0);
	b		=> n_Cache,--(io): in	std_logic_vector(data_width-1 downto 0);
	o		=> sgn_A1,--: out	std_logic_vector(data_width-1 downto 0);
	
	clk	=> clk--: in	std_logic;
);

-- A2 calculation
process(clk)
begin
	if(rising_edge(clk))then
		if(unsigned(sgn_idx) = 0)then
			sgn_A2 <= unsigned(n_Cache) - 1;
		else
			sgn_A2 <= unsigned(sgn_idx) - 1;
		end if;
	end if;
end process;

-- ack delay and connection
process(clk)
begin
	if(rising_edge(clk))then
		sgn_Ack_DL(0) <= Ack and sgn_Ack_Sel(1); -- (io)
		for i in 1 to Mod_Lattic loop
			sgn_Ack_DL(i) <= sgn_Ack_DL(i-1);
		end loop;
	end if;
end process;

sgn_Ack_A1 <= sgn_Ack_DL(Mod_Lattic);
sgn_Ack_WR <= Ack and sgn_Ack_Sel(0); -- (io)
sgn_Ack_o1 <= Ack and sgn_Ack_Sel(2); -- (io)

process(clk)
begin
	if(rising_edge(clk))then
		sgn_Ack_WR_DL <= sgn_Ack_WR;
		sgn_Ack_o1_DL <= sgn_Ack_o1;
		sgn_Ack_o2 <= Ack and sgn_Ack_Sel(3); -- (io)
	end if;
end process;

-- Main control
process(clk, aclr)
begin
	if(aclr='1')then
		state <= S_Idle;
		sgn_st <= '1';
		sgn_HashSt <= '0';
		sgn_idx <= (others => '0');
		Bsy_P1 <= '0'; -- (io)
		Bsy_P2 <= '0'; -- (io)
		Bsy <= '0'; -- (io)
		Mem_Addr <= (others => '0');
		Req_Wr <= '0'; --(io)
		Req_Rd <= '0'; --(io)
		sgn_SRM_Round <= 0;
		Ed <= '0'; -- (io)
		sgn_Ack_Sel <= (others => '0');
		sgn_HashNum <= cst_Hash32_Num;
	elsif(rising_edge(clk))then
		sgn_st <= St;
		case state is
			when S_IDLE =>
				Ed <= '0';
				sgn_idx <= (others => '0');
				sgn_SRM_Round <= 0;
				sgn_HashNum <= cst_Hash32_Num;
				if(sgn_st = '0' and St = '1')then -- rising edge
					sgn_HashNum <= cst_Hash32_Num;
					sgn_HashSt <= '1';
					sgn_Ack_Sel <= "0000";
					state <= S_P1_Work;
					Bsy_P1 <= '1';
					Bsy <= '1';
				end if;
			-- process 1
			when S_P1_Work =>
				sgn_HashSt <= '0';
				if(sgn_HashEd = '1')then -- hash finish
					Mem_Addr <= unsigned(sgn_idx) + unsigned(AB_Cache);
					Req_Wr <= '1';
					sgn_idx <= unsigned(sgn_idx) + 1;
					sgn_Ack_Sel <= "0001";
					state <= S_P1_Mem;
				end if;
			
			when S_P1_Mem => -- wait for write accomplish
				Req_Wr <= '0';
				if(sgn_Ack_WR = '1')then
					if(sgn_idx = n_Cache) then
						sgn_idx <= (others => '0');
						state <= S_P2_R;
						Bsy_P1 <= '0';
					else
						sgn_HashNum <= cst_Hash64_Num;
						sgn_HashSt <= '1';
						sgn_Ack_Sel <= "0000";
						state <= S_P1_Work;
					end if;
				end if;
			-- process 2
			when S_P2_R =>
				if(sgn_SRM_Round = cst_SRM_Round)then
					Bsy_P2 <= '0';
					Bsy <= '0';
					Ed <= '1';
					sgn_Ack_Sel <= "0000";
					state <= S_IDLE;
				else
					Req_Rd <= '1';
					Mem_Addr <= unsigned(sgn_idx) + unsigned(AB_Cache);
					sgn_Ack_Sel <= "0010";
					state <= S_P2_GetA1;
					Bsy_P2 <= '1';
				end if;
				
			when S_P2_GetA1 =>
				if(sgn_Ack_A1 = '1')then
					Req_Rd <= '1';
					Mem_Addr <= unsigned(sgn_A1) + unsigned(AB_Cache);
					sgn_Ack_Sel <= "0100";
					state <= S_P2_GetO1;
				else
					Req_Rd <= '0';
				end if;
			
			when S_P2_GetO1 =>
				if(sgn_Ack_o1_DL = '1')then
					Req_Rd <= '1';
					Mem_Addr <= unsigned(sgn_A2) + unsigned(AB_Cache);
					sgn_Ack_Sel <= "1000";
					state <= S_P2_GetO2;
				else
					Req_Rd <= '0';
				end if;
			
			when S_P2_GetO2 =>
				Req_Rd <= '0';
				if(sgn_Ack_o2 = '1')then
					sgn_HashNum <= cst_Hash64_Num;
					sgn_HashSt <= '1';
					sgn_Ack_Sel <= "0000";
					state <= S_P2_Hash;
				end if;
			
			when S_P2_Hash =>
				sgn_HashSt <= '0';
				if (sgn_HashEd = '1') then
					Mem_Addr <= unsigned(sgn_idx) + unsigned(AB_Cache);
					Req_Wr <= '1';
					sgn_idx <= unsigned(sgn_idx) + 1;
					sgn_Ack_Sel <= "0001";
					state <= S_P2_Mem;
				end if;
			
			when S_P2_Mem =>
				Req_Wr <= '0';
				if (sgn_Ack_WR_DL = '1') then
					if(sgn_idx = n_Cache) then
						state <= S_P2_R;
						sgn_SRM_Round <= sgn_SRM_Round + 1;
						sgn_idx <= (others => '0');
						Req_Rd <= '0';
					else
						Req_Rd <= '1';
						Mem_Addr <= unsigned(sgn_idx) + unsigned(AB_Cache);
						sgn_Ack_Sel <= "0010";
						state <= S_P2_GetA1;
					end if;
				end if;
				
			when others => state <= S_IDLE;
		end case;
		
--		if(Ack='1')then -- must be clear at the moment of ack='1'
--			Req_Wr <= '0';
--			Req_Rd <= '0';
--		end if;
	end if;
end process;

end rtl;
