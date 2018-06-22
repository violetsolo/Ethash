----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    22/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid_oRamAddrGen - Behavioral
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

entity Ethash_AcsMid_oRamAddrGen is
generic(
	WrGen_N			: Positive := 32;
	WrGen_P			: Positive := 2;
	WrGen_L			: Positive := 4;
	RdRam_N			: Positive := 32;
	RdRam_P			: Positive := 8;
	WrGen_DL			: Positive := 4;
	RdGen_DL			: Positive := 32*4+4
);
port (
	Addr_Wr		: out	Natural;
	Addr_Rd		: out	typ_1D_Nat(RdRam_N-1 downto 0);
	Msk_clr		: out	std_logic;
	
	En				: in	std_logic;

	clk			: in	std_logic;
	aclr			: in	std_logic
);
end Ethash_AcsMid_oRamAddrGen;

architecture rtl of Ethash_AcsMid_oRamAddrGen is
--============================ constant declare ============================--
constant cst_WrGen_NL		: Positive := WrGen_N*WrGen_L;
constant cst_WrGen_PNL		: Positive := WrGen_P*WrGen_N*WrGen_L;
constant cst_RdGen_NP		: Positive := RdRam_N*RdRam_P;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--

--============================= signal declare =============================--
signal sgn_WrGen_cnt_p	: Natural;
signal sgn_WrGen_cnt_n	: Natural;
signal sgn_WrGen_cnt_l	: Natural;

signal sgn_RdGen_cnt_p	: Natural;
signal sgn_RdGen_cnt_n	: Natural;
signal sgn_RdGen_l		: typ_1D_Nat(RdRam_N-1 downto 0);

signal sgn_MskGen_cnt_n	: Natural;
signal sgn_MskGen_cnt_l	: Natural;

signal sgn_WrGen_En		: std_logic;
signal sgn_RdGen_En		: std_logic;
signal sgn_WrGen_Cnt		: Natural;
signal sgn_RdGen_Cnt		: Natural;

signal sgn_Msk_Clr		: std_logic;
--============================ function declare ============================--

begin
-- attention: all counter must synchronistical start and reset
-- Msk clear gen
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_MskGen_cnt_n <= WrGen_N-1;
		sgn_MskGen_cnt_l <= cst_WrGen_NL-WrGen_N;
		Msk_clr <= '0';
		sgn_Msk_Clr <= '0';
	elsif(rising_edge(clk))then
		if(En = '0')then
			sgn_MskGen_cnt_n <= WrGen_N-1;
			sgn_MskGen_cnt_l <= cst_WrGen_NL-WrGen_N;
			Msk_clr <= '0';
			sgn_Msk_Clr <= '0';
		else
			Msk_Clr <= sgn_Msk_Clr;
			if(sgn_MskGen_cnt_n = 0)then
				sgn_Msk_Clr <= '1';
			else
				sgn_Msk_Clr <= '0';
			end if;
			if(sgn_MskGen_cnt_l = cst_WrGen_NL-WrGen_N)then
				sgn_MskGen_cnt_l <= 0;
			else
				sgn_MskGen_cnt_l <= sgn_MskGen_cnt_l + WrGen_N;
			end if;
			if(sgn_MskGen_cnt_l = cst_WrGen_NL-WrGen_N)then
				if(sgn_MskGen_cnt_n = WrGen_N-1)then
					sgn_MskGen_cnt_n <= 0;
				else
					sgn_MskGen_cnt_n <= sgn_MskGen_cnt_n + 1;
				end if;
			end if;
		end if;
	end if;
end process;

-- Wr addr gen
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_WrGen_En <= '0';
		sgn_WrGen_Cnt <= 0;
	elsif(rising_edge(clk))then
		if(En = '0')then
			sgn_WrGen_En <= '0';
			sgn_WrGen_Cnt <= 0;
		else
			if(sgn_WrGen_Cnt = WrGen_DL)then
				sgn_WrGen_En <= '1';
			else
				sgn_WrGen_En <= '0';
				sgn_WrGen_Cnt <= sgn_WrGen_Cnt + 1;
			end if;
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		sgn_WrGen_cnt_p <= cst_WrGen_PNL-cst_WrGen_NL;
		sgn_WrGen_cnt_n <= WrGen_N-1;
		sgn_WrGen_cnt_l <= cst_WrGen_NL-WrGen_N;
	elsif(rising_edge(clk))then
		if(sgn_WrGen_En = '0')then
			sgn_WrGen_cnt_p <= cst_WrGen_PNL-cst_WrGen_NL;
			sgn_WrGen_cnt_n <= WrGen_N-1;
			sgn_WrGen_cnt_l <= cst_WrGen_NL-WrGen_N;
		else
			if(sgn_WrGen_cnt_l = cst_WrGen_NL-WrGen_N)then
				sgn_WrGen_cnt_l <= 0;
			else
				sgn_WrGen_cnt_l <= sgn_WrGen_cnt_l + WrGen_N;
			end if;
			if(sgn_WrGen_cnt_l = cst_WrGen_NL-WrGen_N)then
				if(sgn_WrGen_cnt_n = WrGen_N-1)then
					sgn_WrGen_cnt_n <= 0;
				else
					sgn_WrGen_cnt_n <= sgn_WrGen_cnt_n + 1;
				end if;
			end if;
			if(sgn_WrGen_cnt_l = cst_WrGen_NL-WrGen_N and sgn_WrGen_cnt_n = WrGen_N-1)then
				if(sgn_WrGen_cnt_P = cst_WrGen_PNL-cst_WrGen_NL)then
					sgn_WrGen_cnt_P <= 0;
				else
					sgn_WrGen_cnt_P <= sgn_WrGen_cnt_P + cst_WrGen_NL;
				end if;
			end if;
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		Addr_Wr <= 0;
	elsif(rising_edge(clk))then
		Addr_Wr <= sgn_WrGen_cnt_n + sgn_WrGen_cnt_P + sgn_WrGen_cnt_l;
	end if;
end process;

-- rd addr gen
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_RdGen_En <= '0';
		sgn_RdGen_Cnt <= 0;
	elsif(rising_edge(clk))then
		if (En = '0') then
			sgn_RdGen_En <= '0';
			sgn_RdGen_Cnt <= 0;
		else
			if(sgn_RdGen_Cnt = RdGen_DL)then
				sgn_RdGen_En <= '1';
			else
				sgn_RdGen_En <= '0';
				sgn_RdGen_Cnt <= sgn_RdGen_Cnt + 1;
			end if;
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		sgn_RdGen_cnt_p <= cst_RdGen_NP-RdRam_N;
		sgn_RdGen_cnt_n <= RdRam_N-1;
	elsif(rising_edge(clk))then
		if(sgn_RdGen_En = '0')then
			sgn_RdGen_cnt_p <= cst_RdGen_NP-RdRam_N;
			sgn_RdGen_cnt_n <= RdRam_N-1;
		else
			if(sgn_RdGen_cnt_n = RdRam_N-1)then
				sgn_RdGen_cnt_n <= 0;
			else
				sgn_RdGen_cnt_n <= sgn_RdGen_cnt_n + 1;
			end if;
			if(sgn_RdGen_cnt_n = RdRam_N-1)then
				if(sgn_RdGen_cnt_p = cst_RdGen_NP-RdRam_N)then
					sgn_RdGen_cnt_p <= 0;
				else
					sgn_RdGen_cnt_p <= sgn_RdGen_cnt_p + RdRam_N;
				end if;
			end if;
		end if;
	end if;
end process;

process(aclr,clk)
begin
	if(aclr='1')then
		for i in 0 to RdRam_N-2 loop
			sgn_RdGen_l(i) <= i+1;
		end loop;
		sgn_RdGen_l(RdRam_N-1) <= 0;
	elsif(rising_edge(clk))then
		if(sgn_RdGen_En = '0')then
			for i in 0 to RdRam_N-2 loop
				sgn_RdGen_l(i) <= i+1;
			end loop;
			sgn_RdGen_l(RdRam_N-1) <= 0;
		else
			sgn_RdGen_l(0) <= sgn_RdGen_l(RdRam_N-1);
			for i in 1 to RdRam_N-1 loop
				sgn_RdGen_l(i) <= sgn_RdGen_l(i-1);
			end loop;
		end if;
	end if;
end process;

i0100: for i in 0 to RdRam_N-1 generate
	process(aclr,clk)
	begin
		if(aclr='1')then
			Addr_Rd(i) <= 0;
		elsif(rising_edge(clk))then
			Addr_Rd(i) <= sgn_RdGen_l(i) + sgn_RdGen_cnt_p;
		end if;
	end process;
end generate i0100;

end rtl;
