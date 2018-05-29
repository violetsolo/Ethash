----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Logotorix
-- 
-- Create Date:    21/05/2018 
-- Design Name: 
-- Module Name:    Ethash_AcsMid_Cell - Behavioral
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
use work.Ethash_AcsMid_pkg.all;

entity Ethash_AcsMid_Cell is
generic(
	Device_Family			: string := "Cyclone V"; --"Stratix 10";--"Cyclone V"
	Width_Data				: Positive := gcst_AM_WidthData;
	Num_Ch					: Positive := 32;
	DeepthExpo_iRam		: Positive := 6;
	DeepthExpo_oRam		: Positive := 8
);
port (
	Data_i	: in	std_logic_vector(Width_Data-1 downto 0);
	Ch_i		: in	std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Wr			: in	std_logic;
	Valid		: out	std_logic;
	
	Data_o	: out	std_logic_vector(Width_Data-1 downto 0);
	Ch_o		: out std_logic_vector(gcst_WW-1 downto 0); -- 0 to Num_Ch-1
	Flag_o	: out std_logic;
	
	oRam_AddrWr	: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	oRam_AddrRd	: in	std_logic_vector(DeepthExpo_oRam-1 downto 0); -- 0 to Deepth_oRam-1
	
	Msk_Clr	: in	std_logic;
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	Msk_o		: out	std_logic_vector(Num_Ch-1 downto 0);
	
	AcsMid_Valid	: out std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end Ethash_AcsMid_Cell;

architecture rtl of Ethash_AcsMid_Cell is
--============================ constant declare ============================--
constant Deepth_iRam					: Positive := 2**DeepthExpo_iRam;
constant Deepth_oRam					: Positive := 2**DeepthExpo_oRam;
constant cst_IDGen_Size				: Positive := 2**DeepthExpo_iRam*2;
--======================== Altera component declare ========================--
component scfifo
generic (
	add_ram_output_register		: STRING := "ON";
	intended_device_family		: STRING := Device_Family;--"Cyclone V";
	lpm_numwords					: NATURAL := cst_IDGen_Size;
	lpm_showahead					: STRING := "OFF";
	lpm_type							: STRING := "scfifo";
	lpm_width						: NATURAL := DeepthExpo_iRam;
	lpm_widthu						: NATURAL := Fnc_Int2Wd(cst_IDGen_Size-1); -- log2(128)
	overflow_checking				: STRING := "ON";
	underflow_checking			: STRING := "ON";
	use_eab							: STRING := "ON"
);
port (
	data				: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				: IN STD_LOGIC ;

	q					: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				: IN STD_LOGIC ;
	
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
	numwords_a						:	natural;
	numwords_b						:	natural;
	width_a							:	natural;
	width_b							:	natural;
	widthad_a						:	natural; -- log2(128)
	widthad_b						:	natural; -- log2(128)
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
component Ethash_AcsMid_ChSel
generic(
	Num_Ch			: Positive := Num_Ch;
	Size_Ram_Expo	: Positive := DeepthExpo_iRam
);
port (
	Flag_i	: in	std_logic_vector(2**Size_Ram_Expo-1 downto 0);
	Ch_i		: in	typ_1D_Word(2**Size_Ram_Expo-1 downto 0);
	Msk_i		: in	std_logic_vector(Num_Ch-1 downto 0);
	
	Flag_Clr	: out	std_logic_vector(2**Size_Ram_Expo-1 downto 0);
	
	Flag_o	: out	std_logic;
	Ch_o		: out	std_logic_vector(gcst_WW-1 downto 0);
	Msk_o		: out	std_logic_vector(Num_Ch-1 downto 0);
	Addr_o	: out	std_logic_vector(DeepthExpo_iRam-1 downto 0);
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;

component Lg_Latch
generic(
	d_width			: Positive
);
port (
	di			: in	std_logic_vector(d_width-1 downto 0);
	do			: out	std_logic_vector(d_width-1 downto 0);
	Latch		: in	std_logic;
	
	clk		: in	std_logic;
	aclr		: in	std_logic
);
end component;
--============================= signal declare =============================--
signal sgn_flag			: std_logic_vector(Deepth_iRam-1 downto 0);
signal sgn_flag_set		: std_logic_vector(Deepth_iRam-1 downto 0);
signal sgn_flag_clr		: std_logic_vector(Deepth_iRam-1 downto 0);

signal sgn_Msk				: std_logic_vector(Num_Ch-1 downto 0);
signal sgn_Ch				: typ_1D_Word(Deepth_iRam-1 downto 0);

signal sgn_iRam_AddrRd	: std_logic_vector(DeepthExpo_iRam-1 downto 0);

signal sgn_oRam_Data_i	: std_logic_vector(Width_Data-1 downto 0);
signal sgn_oRam_flag_i	: std_logic;
signal sgn_oRam_Ch_i		: std_logic_vector(gcst_WW-1 downto 0);

signal sgn_oRam_Di		: std_logic_vector(gcst_WW downto 0);
signal sgn_oRam_Do		: std_logic_vector(gcst_WW downto 0);

signal sgn_FIFO_ID_Di	: std_logic_vector(DeepthExpo_iRam -1 downto 0);
signal sgn_FIFO_ID_Wr	: std_logic;
signal sgn_FIFO_ID_Do	: std_logic_vector(DeepthExpo_iRam -1 downto 0);
signal sgn_FIFO_ID_Rd	: std_logic;

signal sgn_ID_Init_Sel	: std_logic; -- '0' initial ID '1' recycled ID
signal sgn_ID_Init		: std_logic_vector(DeepthExpo_iRam+1-1 downto 0);
signal sgn_ID_Init_Wr	: std_logic;
signal sgn_ID_Init_Cnt	: Natural range 0 to Deepth_iRam+1;
signal sgn_ID_En			: std_logic;

signal sgn_iRam_AddrWr	: std_logic_vector(DeepthExpo_iRam-1 downto 0);

type typ_state is (S_IDLE, S_Init);
signal state				: typ_state;

-- delay
signal sgn_oRam_Flag_i_DL	: std_logic;
signal sgn_oRam_Ch_i_DL		: std_logic_vector(gcst_WW-1 downto 0);
--
signal sgn_iRam_AddrWr_DL	: std_logic_vector(DeepthExpo_iRam-1 downto 0);
--
constant cst_iRam_Wr_DL		: Positive := 2;
signal sgn_iRam_Wr			: std_logic;
signal sgn_iRam_Wr_DL		: std_logic_vector(cst_iRam_Wr_DL-1 downto 0);
--
constant cst_iRam_Data_DL	: Positive := 2;
type typ_iRamDataDL is array (natural range<>) of std_logic_vector(Width_Data-1 downto 0);
signal sgn_Data_i				: std_logic_vector(Width_Data-1 downto 0);
signal sgn_iRam_Data_DL		: typ_iRamDataDL(cst_iRam_Data_DL-1 downto 0);
--
constant cst_iRam_Ch_DL		: Positive := 2;
type typ_iRamChDL is array (natural range<>) of std_logic_vector(gcst_WW-1 downto 0);
signal sgn_Ch_i				: std_logic_vector(gcst_WW-1 downto 0);
signal sgn_iRam_Ch_DL		: typ_iRamChDL(cst_iRam_Ch_DL-1 downto 0);

signal sgn_TskCnt					: Natural range 0 to Deepth_iRam;
--============================ function declare ============================--

begin

-- store data to iRam
inst01: altsyncram
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
	width_byteena_a				=> 1,--:	natural := 1
	
	
	numwords_a						=> Deepth_iRam,--:	natural;
	numwords_b						=> Deepth_iRam,--:	natural;
	width_a							=> Width_Data,--:	natural;
	width_b							=> Width_Data,--:	natural;
	widthad_a						=> DeepthExpo_iRam,--:	natural; -- log2(128)
	widthad_b						=> DeepthExpo_iRam--:	natural; -- log2(128)
)
port map(
	address_a	=> sgn_iRam_AddrWr_DL,--(io):	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_iRam_Data_DL(cst_iRam_Data_DL-1),--(io):	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> sgn_iRam_Wr_DL(cst_iRam_Wr_DL-1),--(io):	in std_logic;
	
	address_b	=> sgn_iRam_AddrRd,--:	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_oRam_Data_i,--:	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

-- flag set generate(decode)
i0300: for i in 0 to Deepth_iRam-1 generate
	process(clk,aclr)
	begin
		if(aclr='1')then
			sgn_flag_set(i) <= '0';
		elsif(rising_edge(clk))then
			if(i=unsigned(sgn_iRam_AddrWr) and sgn_iRam_Wr_DL(0)='1')then
				sgn_flag_set(i) <= '1';
			else
				sgn_flag_set(i) <= '0';
			end if;
		end if;
	end process;
end generate i0300;

-- store ch
i0100: for i in 0 to Deepth_iRam-1 generate
	inst02: Lg_Latch
	generic map(
		d_width			=> gcst_WW--: Positive;
	)
	port map(
		di			=> sgn_iRam_Ch_DL(cst_iRam_Ch_DL-1),--: in	std_logic_vector(d_width-1 downto 0);
		do			=> sgn_Ch(i),--: out	std_logic_vector(d_width-1 downto 0);
		Latch		=> sgn_flag_set(i),--: in	std_logic;
		
		clk		=> clk,--: in	std_logic;
		aclr		=> aclr--: in	std_logic
	);
end generate i0100;

-- set/clear flag
i0200: for i in 0 to Deepth_iRam-1 generate
	process(clk,aclr)
	begin
		if(aclr = '1')then
			sgn_flag(i) <= '0';
		elsif(rising_edge(clk))then
			sgn_flag(i) <= ((not sgn_flag(i)) and sgn_flag_set(i)) or 
								(sgn_flag(i) and (not sgn_flag_clr(i)));
		end if;
	end process;
end generate i0200;

-- channel select
sgn_Msk <= (others => '0') when Msk_Clr = '1' else
			  Msk_i;
inst03: Ethash_AcsMid_ChSel
port map(
	Flag_i	=> sgn_flag,--: in	std_logic_vector(Size_Ram-1 downto 0);
	Ch_i		=> sgn_Ch,--: in	typ_1D_Word(Size_Ram-1 downto 0);
	Msk_i		=> sgn_Msk,--: in	std_logic_vector(Num_Ch-1 downto 0);
	
	Flag_Clr	=> sgn_flag_clr,--: out	std_logic_vector(Size_Ram-1 downto 0);
	
	Flag_o	=> sgn_oRam_flag_i,--: out	std_logic;
	Ch_o		=> sgn_oRam_Ch_i,--: out	std_logic_vector(gcst_WW-1 downto 0);
	Msk_o		=> Msk_o,--(io): out	std_logic_vector(Num_Ch-1 downto 0);
	Addr_o	=> sgn_iRam_AddrRd,--: out	std_logic_vector(gcst_WW-1 downto 0);
	
	clk		=> clk,--: in	std_logic;
	aclr		=> aclr--: in	std_logic
);

-- store data to oRam
inst04: altsyncram
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
	width_byteena_a				=> 1,--:	natural := 1
	
	
	numwords_a						=> Deepth_oRam,--:	natural;
	numwords_b						=> Deepth_oRam,--:	natural;
	width_a							=> Width_Data,--:	natural;
	width_b							=> Width_Data,--:	natural;
	widthad_a						=> DeepthExpo_oRam,--:	natural; -- log2(128)
	widthad_b						=> DeepthExpo_oRam--:	natural; -- log2(128)
)
port map(
	address_a	=> oRam_AddrWr,--(io):	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_oRam_Data_i,--(io):	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> '1',--(io):	in std_logic;
	
	address_b	=> oRam_AddrRd,--(io):	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> Data_o,--(io):	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

inst05: altsyncram
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
	width_byteena_a				=> 1,--:	natural := 1
	
	numwords_a						=> Deepth_oRam,--:	natural;
	numwords_b						=> Deepth_oRam,--:	natural;
	width_a							=> gcst_WW + 1,--:	natural;
	width_b							=> gcst_WW + 1,--:	natural;
	widthad_a						=> DeepthExpo_oRam,--:	natural; -- log2(128)
	widthad_b						=> DeepthExpo_oRam--:	natural; -- log2(128)
)
port map(
	address_a	=> oRam_AddrWr,--(io):	in std_logic_vector(widthad_a-1 downto 0);
	data_a		=> sgn_oRam_Di,--(io):	in std_logic_vector(width_a-1 downto 0);
	wren_a		=> '1',--(io):	in std_logic;
	
	address_b	=> oRam_AddrRd,--(io):	in std_logic_vector(widthad_b-1 downto 0);
	q_b			=> sgn_oRam_Do,--(io):	out std_logic_vector(width_b-1 downto 0);
	
	clock0		=> clk--:	in std_logic
);

sgn_oRam_Di(gcst_WW) <= sgn_oRam_flag_i_DL;
sgn_oRam_Di(gcst_WW-1 downto 0) <= sgn_oRam_Ch_i_DL;

Flag_o <= sgn_oRam_Do(gcst_WW);
Ch_o <= sgn_oRam_Do(gcst_WW-1 downto 0);

-- ID generate
inst06: scfifo
port map(
	data				=> sgn_FIFO_ID_Di,--: IN STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	wrreq				=> sgn_FIFO_ID_Wr,--: IN STD_LOGIC ;

	q					=> sgn_FIFO_ID_Do,--: OUT STD_LOGIC_VECTOR (lpm_width-1 DOWNTO 0);
	rdreq				=> sgn_FIFO_ID_Rd,--: IN STD_LOGIC ;
	
	empty				=> open,--: OUT STD_LOGIC ;

	clock				=> clk,--: IN STD_LOGIC ;
	aclr				=> aclr--: IN STD_LOGIC 
);

sgn_FIFO_ID_Di <= 
	sgn_iRam_AddrRd when (sgn_ID_Init_Sel = '1') else -- recycle ID
	sgn_ID_Init(DeepthExpo_iRam-1 downto 0); -- initial ID
sgn_FIFO_ID_Wr <= 
	sgn_oRam_flag_i when (sgn_ID_Init_Sel = '1') else -- recycle ID
	sgn_ID_Init_Wr; -- initial ID

sgn_FIFO_ID_Rd <= sgn_iRam_Wr;
sgn_iRam_AddrWr <= sgn_FIFO_ID_Do;
	
process(aclr,clk)
begin
	if(aclr='1')then
		sgn_ID_Init_Sel <= '0';
		state <= S_Init;
		sgn_ID_Init <= (others => '0');
		sgn_ID_Init_Cnt <= 0;
		sgn_ID_Init_Wr <= '0';
		sgn_ID_En <= '0';
	elsif(rising_edge(clk))then
		sgn_ID_Init <= conv_std_logic_vector(sgn_ID_Init_Cnt, DeepthExpo_iRam+1);
		case state is
			when S_IDLE =>
				sgn_ID_Init_Sel <= '1';
				sgn_ID_Init_Wr <= '0';
				sgn_ID_En <= '1';
			when S_Init =>
				sgn_ID_Init_Cnt <= sgn_ID_Init_Cnt + 1;
				if(sgn_ID_Init_Cnt = Deepth_iRam)then
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

AcsMid_Valid <= sgn_ID_En;

-- delay
sgn_iRam_Wr <= Wr;
sgn_Data_i <= Data_i;
sgn_Ch_i <= Ch_i;
process(clk,aclr)
begin
	if(aclr='1')then
		sgn_oRam_flag_i_DL <= '0';
		sgn_oRam_Ch_i_DL <= (others => '0');
		sgn_iRam_Wr_DL <= (others => '0');
		sgn_iRam_AddrWr_DL <= (others => '0');
		sgn_iRam_Data_DL <= (others => (others => '0'));
		sgn_iRam_Ch_DL <= (others => (others => '0'));
	elsif(rising_edge(clk))then
		sgn_oRam_flag_i_DL <= sgn_oRam_flag_i;--1
		sgn_oRam_Ch_i_DL <= sgn_oRam_Ch_i;--1
		sgn_iRam_AddrWr_DL <= sgn_iRam_AddrWr; -- 1
		--
		sgn_iRam_Wr_DL(0) <= sgn_iRam_Wr; -- (io)
		for i in 1 to cst_iRam_Wr_DL-1 loop -- 2
			sgn_iRam_Wr_DL(i) <= sgn_iRam_Wr_DL(i-1);
		end loop;
		--
		sgn_iRam_Data_DL(0) <= sgn_Data_i; -- (io)
		for i in 1 to cst_iRam_Data_DL-1 loop -- 2
			sgn_iRam_Data_DL(i) <= sgn_iRam_Data_DL(i-1);
		end loop;
		--
		sgn_iRam_Ch_DL(0) <= sgn_Ch_i; -- (io)
		for i in 1 to cst_iRam_Ch_DL-1 loop -- 2
			sgn_iRam_Ch_DL(i) <= sgn_iRam_Ch_DL(i-1);
		end loop;
	end if;
end process;

-- task statistics
process(clk, aclr)
begin
	if(aclr='1')then
		sgn_TskCnt <= 0;
		Valid <= '1';
	elsif(rising_edge(clk))then
		if(Wr = '1' and sgn_oRam_flag_i = '0')then
			sgn_TskCnt <= sgn_TskCnt + 1;
		elsif(Wr = '0' and sgn_oRam_flag_i = '1')then
			sgn_TskCnt <= sgn_TskCnt - 1;
		else
			-- do nothing
		end if;
		if(sgn_TskCnt > Deepth_iRam - 8)then -- must reserve 4 tasks
			Valid <= '0';
		else
			Valid <= '1';
		end if;
	end if;
end process;

end rtl;
