
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY LogicalStep_Lab5_top IS
   PORT
	(
   clkin_50		: in	std_logic;							-- The 50 MHz FPGA Clockinput
	rst_n			: in	std_logic;							-- The RESET input (ACTIVE LOW)
	pb				: in	std_logic_vector(3 downto 0); -- The push-button inputs (ACTIVE LOW)
 	sw   			: in  std_logic_vector(7 downto 0); -- The switch inputs
   leds			: out std_logic_vector(7 downto 0);	-- for displaying the switch content
   seg7_data 	: out std_logic_vector(6 downto 0); -- 7-bit outputs to a 7-segment
	seg7_char1  : out	std_logic;							-- seg7 digi selectors
	seg7_char2  : out	std_logic							-- seg7 digi selectors
	);
END LogicalStep_Lab5_top;

ARCHITECTURE SimpleCircuit OF LogicalStep_Lab5_top IS


   component cycle_generator port (
          clkin      		: in  std_logic;
			 rst_n				: in  std_logic;
			 modulo 				: in  integer;	
			 strobe_out			: out	std_logic;
			 full_cycle_out	: out std_logic
  );
   end component;

   component segment7_mux port (
          clk        : in  std_logic := '0';
			 DIN0 		: in  std_logic_vector(6 downto 0);	
			 DIN1 		: in  std_logic_vector(6 downto 0);
			 DOUT			: out	std_logic_vector(6 downto 0);
			 DIG1			: out	std_logic;
			 DIG2			: out	std_logic
   );
   end component;
	
	-- lab5 moore SM component declaration
	component Lab5_Moore_SM port(
		clk_input			:IN std_logic;
		rst_n					:IN std_logic;
		enable							:IN std_logic;
		
		-- vehicle monitoring from synchronized latches
		NS_pedestrian					:IN std_logic;
		EW_pedestrian					:IN std_logic;
		
		--switches for special states
		NIGHT_MODE_INP					:IN std_logic;
		REDUCED_MODE_INP				:IN std_logic;
		
		--flags for special states
		NIGHT_MODE_FLAG					:out std_logic;
		REDUCED_MODE_FLAG				:OUT std_logic;

		-- clearing synchronized latches
		NS_clear						:OUT std_logic;
		EW_clear						:OUT std_logic;
		
		State_Number					:OUT std_logic_vector(3 downto 0)
	);
	end component;
	
	component basic_synchronizer port(
		clkin 		:IN std_logic;
		data_input	:IN std_logic;
		data_output 	:OUT std_logic
		--rst_n		:IN std_logic; was added for completeness, removed as it is unnecessary
	);
	end component;
	
	component synchronized_latch port(
		clkin		:IN std_logic;
		Sync_input 	:IN std_logic;
		LATCH_CLR	:IN std_logic;
		ENABLE		:IN std_logic;
		DATA_OUT	:OUT std_logic
		--rst_n 	:in std_logic; -- dont need this right?
	);
	end component;
	
	
	
----------------------------------------------------------------------------------------------------
	CONSTANT	SIM							:  boolean := FALSE;

	CONSTANT CNTR1_modulo				: 	integer := 25000000;    	-- modulo count for cycle generator 1 with 50Mhz clocking input
   CONSTANT CNTR2_modulo				: 	integer :=  5000000;    	-- modulo count for cycle generator 2 with 50Mhz clocking input
   CONSTANT CNTR1_modulo_sim			: 	integer := 199;   			-- modulo count for cycle generator 1 during simulation
   CONSTANT CNTR2_modulo_sim			: 	integer :=  39;   			-- modulo count for cycle generator 2 during simulation
	
   SIGNAL CNTR1_modulo_value			: 	integer ;   					-- modulo count for cycle generator 1 
   SIGNAL CNTR2_modulo_value			: 	integer ;   					-- modulo count for cycle generator 2 

   SIGNAL clken1,clken2					:  STD_LOGIC; 						-- clock enables 1 & 2

	SIGNAL strobe1, strobe2				:  std_logic;						-- strobes 1 & 2 with each one being 50% Duty Cycle
		

	SIGNAL seg7_A, seg7_B				:  STD_LOGIC_VECTOR(6 downto 0); -- signals for inputs into seg7_mux.
	
	-- starting states for the FSM
	constant North_South				: std_logic := '0';
	constant East_West					: std_logic := '1';
	
	-- storage for state number output of both FSM
	signal traffic_SM_output 	:std_logic_vector(3 downto 0);
	signal NS_light, EW_light	:std_logic_vector(6 downto 0);
	
	-- constants for light signals
	CONSTANT RED_LIGHT 					: STD_LOGIC_VECTOR(6 DOWNTO 0) := "0000001";
	CONSTANT AMBER_LIGHT				: STD_LOGIC_VECTOR(6 DOWNTO 0) := "1000000";
	CONSTANT GREEN_LIGHT 				: STD_LOGIC_VECTOR(6 DOWNTO 0) := "0001000";
	CONSTANT OFF_LIGHT 					: STD_LOGIC_VECTOR(6 DOWNTO 0) := "0000000";
	
	--part C, vehicle sensing output holder
	SIGNAL EW_vehicle_sensing, NS_vehicle_sensing	:std_logic;
	SIGNAL synced_EW_vehicle_sensing, synced_NS_vehicle_sensing	:std_logic;
	SIGNAL EW_V, NS_V :std_logic; -- TEST FOR ERROR CODE 12014 NET 
	-- clear signals to synched latches from the SM
	SIGNAL NS_CLR, EW_CLR		:STD_LOGIC;
	
	--part D
	SIGNAL NIGHT_MODE_ENABLE, REDUCED_MODE_ENABLE :std_logic;
	SIGNAL NIGHT_MODE_ACTIVE, REDUCED_MODE_ACTIVE :std_logic;
	

BEGIN
----------------------------------------------------------------------------------------------------


MODULO_1_SELECTION:	CnTR1_modulo_value <= CNTR1_modulo when SIM = FALSE else CNTR1_modulo_sim; 

MODULO_2_SELECTION:	CNTR2_modulo_value <= CNTR2_modulo when SIM = FALSE else CNTR2_modulo_sim; 

seg7_A <= NS_light;
seg7_B <= EW_light;

--LED OUTPUT 
-- 7 for any sensor being on
leds(7) <= synced_EW_vehicle_sensing OR synced_NS_vehicle_sensing;
--6 for any mode being on
leds(6) <= NIGHT_MODE_ACTIVE OR REDUCED_MODE_ACTIVE;

--leds 5 downto 2 is for state number
leds(5) <= traffic_SM_output(3);
leds(4) <= traffic_SM_output(2);
leds(3) <= traffic_SM_output(1);
leds(2) <= traffic_SM_output(0);

-- leds 0 to 1 for 5hz and 1hz strobes 
leds(0) <= strobe2; -- 5hz
leds(1) <= strobe1; -- 1hz


						
OUTPUT_ANALYSIS: process(clkin_50, traffic_SM_output, strobe1)
	BEGIN
	-- OUTPUT ANALYZER
	-- NS: flashing green EW: red
	IF (traffic_SM_output = "0000" OR traffic_SM_output = "0001") then
	--REDUCED MODE
		IF (REDUCED_MODE_ACTIVE = '1') THEN
			-- 1HZ FLASH
			IF (Strobe1 = '1') THEN
				NS_light <= AMBER_LIGHT;
				EW_light <= RED_LIGHT;
			ELSE
				NS_light <= OFF_LIGHT;
				EW_light <= OFF_LIGHT;
			END IF;
		
		-- NIGHT MODE
		ELSIF (NIGHT_MODE_ACTIVE = '1') THEN
			NS_light <= GREEN_LIGHT;
			EW_light <= RED_LIGHT;
		
		ELSIF (strobe2 = '1') then
			NS_light <= GREEN_LIGHT;
		
		ELSE
			NS_light <= OFF_LIGHT;
		end if;
		EW_light <= RED_LIGHT;
		
	-- NS: solid green EW:red
	ELSIF (traffic_SM_output = "0010" or traffic_SM_output = "0011" OR traffic_SM_output = "0100" or traffic_SM_output = "0101") then
		NS_light <= GREEN_LIGHT;
		EW_light <= RED_LIGHT;
		
	-- NS: Amber	EW: red
	ELSIF (traffic_SM_output = "0110" OR traffic_SM_output = "0111") then
		NS_light <= AMBER_LIGHT;
		EW_light <= RED_LIGHT;
		
	-- NS: red EW: flashing green
	ELSIF (traffic_SM_output = "1000" OR traffic_SM_output = "1001") then
		IF (strobe2 = '1') then
			EW_light <= GREEN_LIGHT;
		ELSE
			EW_light <= OFF_LIGHT;
		end if;
		NS_light <= RED_LIGHT;
		
	-- NS: red EW:solid green 
	ELSIF (traffic_SM_output = "1010" or traffic_SM_output = "1011" OR traffic_SM_output = "1100" or traffic_SM_output = "1101") then
		EW_light <= GREEN_LIGHT;
		NS_light <= RED_LIGHT;
		
	-- NS: red	EW: amber
	ELSIF (traffic_SM_output = "1110" OR traffic_SM_output = "1111") then
		EW_light <= AMBER_LIGHT;
		NS_light <= RED_LIGHT;
	END if;
END PROCESS; 
						
						
----------------------------------------------------------------------------------------------------
-- Component Hook-up:					

-- 1Hz 
GEN1: 	cycle_generator port map(clkin_50, rst_n, CnTR1_modulo_value, strobe1, clken1);	

-- 5Hz
GEN2: 	cycle_generator port map(clkin_50, rst_n, CnTR2_modulo_value, strobe2, clken2);	

SM1: Lab5_Moore_SM port map(
		clkin_50,
		rst_n,
		clken1, -- for 1Hz
		NS_vehicle_sensing,
		EW_vehicle_sensing,
		NIGHT_MODE_ENABLE,
		REDUCED_MODE_ENABLE,
		NIGHT_MODE_ACTIVE,
		REDUCED_MODE_ACTIVE,
		NS_CLR,
		EW_CLR,
		traffic_SM_output -- the output goes straight into SIGNAL A of the mux
		
	);


	
-- 7seg mux daclaration
INST4: segment7_mux port map( 
	clkin_50,
	seg7_A(6 downto 0),
	seg7_B(6 downto 0),
	seg7_data(6 downto 0),
	seg7_char1,
	seg7_char2
	
);

-- EW vehicle sensing
BSYNC1: basic_synchronizer port map(
	clkin_50,
	pb(0), -- ACTIVE LOW, so dont invert
	EW_vehicle_sensing
); 
-- NS vehicle sensing
BSYNC2: basic_synchronizer port map(
	clkin_50,
	pb(1), -- ACTIVE LOW, so dont invert
	NS_vehicle_sensing
); 

-- dunno if we need BSYNC3 and 4 or not, but in there for good measure
-- Night Mode Sensing
BSYNC3: basic_synchronizer port map(
	clkin_50,
	sw(0), -- ACTIVE LOW, so dont invert
	NIGHT_MODE_ENABLE
); 
-- Reduced Mode sensing
BSYNC4: basic_synchronizer port map(
	clkin_50,
	sw(1), -- ACTIVE LOW, so dont invert
	REDUCED_MODE_ENABLE
); 

-- EW synchronized_latch
SLATCH1: synchronized_latch port map( 
	clkin_50,
	EW_vehicle_sensing,
	EW_CLR,
	clken2, -- 5hz full cycle
	synced_EW_vehicle_sensing -- comes out synced
);

-- NS synchronized_latch
 SLATCH2: synchronized_latch port map( 
	clkin_50,
	NS_vehicle_sensing,
	NS_CLR,
	clken2, -- 5hz full cycle
	synced_NS_vehicle_sensing -- comes out synced
);



-----------------------------------------------------
	-- WARNING WARNING WARNING
	--ATTENTION ATTENTION ATTENTION
	--used in real life 
	--ENABLE THIS
	--leds(1 downto 0) <= Strobe1 & Strobe2;
	
------------------------------------------------

-- used for simulations
	--leds(0) <= clken1;
	--leds(1) <= Strobe1;
	--leds(2) <= clken2;
	--leds(3) <= Strobe2;
--	leds(7 downto 4) <= Stae Machine state numbers


END SimpleCircuit;
