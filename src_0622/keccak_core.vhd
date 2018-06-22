----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    05/04/2018 
-- Design Name: 
-- Module Name:    keccak_core - Behavioral
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
library work;
use work.keccak_globals.all;
use work.Ethash_pkg.all;
	
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;	

entity keccak_core is
generic(
	KNum		: Positive := 24;
	PP_L		: Natural := 0
);
port (
    di		: in  k_state;
    do		: out k_state;
	 
	 St		: in	std_logic;
	 Ed		: out	std_logic;
	 ppEd		: out	std_logic;
	 pEd		: out	std_logic;
	 Bsy		: out	std_logic;
	 
	 clk		: in	std_logic;
	 aclr		: in	std_logic := '0'
);
end keccak_core;

architecture rtl of keccak_core is
--============================ constant declare ============================--
constant cst_Rn0		: Natural := KNum * PP_L;
--======================== Altera component declare ========================--

--===================== user-defined component declare =====================--
component keccak_theta
port (
    theta_in    : in  k_state;
	 sum_sheet	 : in  k_plane;
    theta_out   : out k_state;
	 
	 clk			: in	std_logic
);
end component;

component keccak_rho_pi
port (
    rho_in     : in  k_state;
    pi_out    : out k_state
);
end component;

component keccak_chi_iota
port (
    chi_in		: in  k_state;
	 RC			: in std_logic_vector(N-1 downto 0);
    iota_out	: out k_state;
	 
	 clk			: in	std_logic
);
end component;

component keccak_RC_gen
port(
    Rn		: in natural range 0 to 31;
    RC		: out std_logic_vector(N-1 downto 0);
	 
	 clk		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_theta_in, sgn_theta_out, sgn_rho_in, sgn_pi_out, sgn_chi_in, sgn_iota_out		: k_state;
signal sgn_sum_sheet	 : k_plane;
signal sgn_RC		: std_logic_vector(N-1 downto 0);
signal sgn_Rn		: natural range 0 to 31;
signal sgn_RnCnt	: natural range 0 to 31;
signal sgn_sel		: std_logic;

type typ_state is (S_IDLE, S_DELAY1, S_DELAY2, S_WORK);
signal state		: typ_state;
signal sgn_St		: std_logic;

--============================ function declare ============================--

--============================ attribute declare ============================--
attribute maxfan : natural;
attribute maxfan of sgn_sel : signal is gAttribut_maxFanout;

begin
-- input select and compute sum of columns
process(clk)
begin
	if(rising_edge(clk))then
		if(sgn_sel = '1')then
			i0101: for x in 0 to 4 loop
				i0102: for i in 0 to 63 loop
					sgn_sum_sheet(x)(i)<=sgn_iota_out(0)(x)(i) xor sgn_iota_out(1)(x)(i) xor sgn_iota_out(2)(x)(i) xor sgn_iota_out(3)(x)(i) xor sgn_iota_out(4)(x)(i);
				end loop;	
			end loop;
			sgn_theta_in <= sgn_iota_out;
		else
			i0201: for x in 0 to 4 loop
				i0202: for i in 0 to 63 loop
					sgn_sum_sheet(x)(i)<=di(0)(x)(i) xor di(1)(x)(i) xor di(2)(x)(i) xor di(3)(x)(i) xor di(4)(x)(i);
				end loop;	
			end loop;
			sgn_theta_in <= di;
		end if;
	end if;
end process;

sgn_rho_in <= sgn_theta_out;
sgn_chi_in <= sgn_pi_out;

inst00: keccak_theta
port map(
    theta_in    => sgn_theta_in,--: in  k_state;
	 sum_sheet	 => sgn_sum_sheet,--: in  k_plane;
    theta_out   => sgn_theta_out,--: out k_state;
	 
	 clk			=> clk--: in	std_logic
);

inst01: keccak_rho_pi
port map(
    rho_in     => sgn_rho_in,--: in  k_state;
    pi_out    => sgn_pi_out--: out k_state
);

inst02: keccak_chi_iota
port map(
    chi_in		=> sgn_chi_in,--: in  k_state;
	 RC			=> sgn_RC,--: in std_logic_vector(N-1 downto 0);
    iota_out	=> sgn_iota_out,--: out k_state;
	 
	 clk			=> clk--: in	std_logic
);

inst03: keccak_RC_gen
port map(
    Rn		=> sgn_Rn,--: in natural range 0 to 31;
    RC		=> sgn_RC,--: out std_logic_vector(N-1 downto 0);
	 
	 clk		=> clk--: in	std_logic
);

-- sel, sgn_Rn
process(clk, aclr)
begin
	if(aclr = '1')then
		state <= S_IDLE;
		sgn_St <= '1';
		sgn_sel <= '0';
		sgn_Rn <= cst_Rn0;
		sgn_RnCnt <= 0;
		Ed <= '0';
		pEd <= '0';
		ppEd <= '0';
		Bsy <= '0';
	elsif(rising_edge(clk))then
		sgn_St <= St;
		case state is
			when S_IDLE =>
				sgn_Rn <= cst_Rn0;
				sgn_RnCnt <= 0;
				sgn_sel <= '0';
				Ed <= '0';
				if(St = '1' and sgn_St = '0')then -- rising edge
					state <= S_DELAY2;
					Bsy <= '1';
				else
					Bsy <= '0';
				end if;
				
			when S_DELAY1 =>
				sgn_sel <= '0';
				state <= S_DELAY2;
				if(sgn_RnCnt = KNum-1)then
					ppEd <= '1';
				else
					ppEd <= '0';
				end if;
			when S_DELAY2 =>
				state <= S_WORK;
				ppEd <= '0';
				if(sgn_RnCnt = KNum-1)then
					pEd <= '1';
				else
					pEd <= '0';
				end if;
				
			when S_WORK =>
				pEd <= '0';
				if(sgn_RnCnt = KNum-1)then
					state <= S_IDLE;
					sgn_RnCnt <= 0;
					sgn_sel <= '0';
					Ed <= '1';
				else
					state <= S_DELAY1;
					sgn_RnCnt <= sgn_RnCnt + 1;
					sgn_Rn <= sgn_Rn + 1;
					sgn_sel <= '1';
				end if;
				
			when others => state <= S_IDLE;
		end case;
	end if;
end process;

do <= sgn_iota_out;

end rtl;