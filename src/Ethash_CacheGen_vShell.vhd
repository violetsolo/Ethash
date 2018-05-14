----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    16/04/2018 
-- Design Name: 
-- Module Name:    Ethash_CacheGen_vShell - Behavioral
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

entity Ethash_CacheGen_vShell is
generic(
	Mod_Lattic		: Positive := 17
);
port (
	Seed			: in	std_logic_vector(32*gcst_WW-1 downto 0); -- cache seed, must be hold outsider
	n_Cache		: in	std_logic_vector(4*gcst_WW-1 downto 0); -- cache number, which should be devide by 64, must be hold outsider
	AB_Cache		: in	std_logic_vector(4*gcst_WW-1 downto 0); -- cache memory address offse, must be hold outsider
	
	Mem_Do		: out	std_logic_vector(64*gcst_WW-1 downto 0);
	Mem_Di		: in	std_logic_vector(64*gcst_WW-1 downto 0);
	Mem_Addr		: out	std_logic_vector(4*gcst_WW-1 downto 0);
	Mem_Req_Wr	: out	std_logic; -- Write data request, only 1 clk
	Mem_Req_Rd	: out	std_logic; -- read data request, only 1 clk
	Mem_Ack		: in	std_logic; -- must be 1 clk
	
	St			: in	std_logic; -- task start, this signal must reach while data is ready, and pulse must be hold 1clk per task
	Ed			: out	std_logic; -- task end signal, only 1clk duration
	Bsy		: out std_logic; -- indicate process is working
	
	clk		: in	std_logic; -- clock
	rst		: in	std_logic -- '0' reset
);
end Ethash_CacheGen_vShell;

architecture rtl of Ethash_CacheGen_vShell is
--============================ constant declare ============================--
constant	Size_Seed		: Positive := 32;
constant	Size_Data		: Positive := 64;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component Ethash_CacheGen_vShell
generic(
	Size_Seed		: Positive := Size_Seed;
	Size_Data		: Positive := Size_Data;
	Mod_Lattic		: Positive := Mod_Lattic
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
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_Seed			: typ_1D_Word(Size_Seed-1 downto 0);
signal sgn_Mem_Do			: typ_1D_Word(Size_Data-1 downto 0);
signal sgn_Mem_Di			: typ_1D_Word(Size_Data-1 downto 0);
signal sgn_aclr			: std_logic;
--============================ function declare ============================--

begin

sgn_aclr <= not rst;
i0100: for i in 0 to Size_Seed-1 generate
	sgn_Seed(i) <= Seed(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0100;

i0200: for i in 0 to Size_Data-1 generate
	sgn_Mem_Di(i) <= Mem_Di(gcst_WW*(i+1)-1 downto gcst_WW*i);
end generate i0200;

i0300: for i in 0 to Size_Data-1 generate
	Mem_Do(gcst_WW*(i+1)-1 downto gcst_WW*i) <= sgn_Mem_Do(i);
end generate i0300;

inst00: Ethash_CacheGen_vShell
port map(
	Seed			=> sgn_Seed,--: in	typ_1D_Word(Size_Seed-1 downto 0);
	n_Cache		=> n_Cache,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0); -- must be hold outside
	AB_Cache		=> AB_Cache,--: in	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	
	Mem_Do		=> sgn_Mem_Do,--: out	typ_1D_Word(Size_Data-1 downto 0);
	Mem_Di		=> sgn_Mem_Di,--: in	typ_1D_Word(Size_Data-1 downto 0);
	Mem_Addr		=> Mem_Addr,--: out	std_logic_vector(gcst_AW*gcst_WW-1 downto 0);
	Req_Wr		=> Mem_Req_Rd,--: out	std_logic;
	Req_Rd		=> Mem_Req_Wr,--: out	std_logic;
	Ack			=> Mem_Ack,--: in	std_logic; -- must be hold 1 clk
	
	St				=> St,--: in	std_logic;
	Ed				=> Ed,--: out	std_logic;
	Bsy_P1		=> open,--: out	std_logic;
	Bsy_P2		=> open,--: out std_logic;
	Bsy			=> Bsy,--: out std_logic;
	
	clk			=> clk,--: in	std_logic;
	aclr			=> sgn_aclr--: in	std_logic
);

end rtl;
