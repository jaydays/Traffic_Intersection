LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

Entity cycle_generator IS port (
          clkin      		: in  std_logic;
			 rst_n				: in  std_logic;
			 modulo 				: in  integer;	
			 strobe_out			: out	std_logic;
			 full_cycle_out	: out std_logic
   );
end entity;

ARCHITECTURE counter OF cycle_generator IS

	SIGNAL bin_counter					: UNSIGNED(31 DOWNTO 0);
	SIGNAL terminal_count				: std_logic;
	SIGNAL half_cycle, full_cycle		: std_logic;
	SIGNAL strobe							: std_logic;
	
	-- added new signal
	SIGNAL toggle_next 					: boolean := TRUE;

	BEGIN

	half_cycle <= terminal_count;
	full_cycle_out <= full_cycle;
	strobe_out <= strobe;

	
MODULO_COUNTING: PROCESS(clkin, rst_n) IS
   BEGIN

	  IF (rst_n = '0') THEN
		  bin_counter <= to_unsigned(modulo,32);
		  terminal_count <= '0';
	
	  ELSIF (rising_edge(clkin)) THEN					-- binary counter decrements on rising clock edge.
		
			IF(bin_counter = 0) THEN 						 
																	-- when bin_counter reaches 0 
				bin_counter <= to_unsigned(modulo,32); -- reload the (converted integer to 32 bit unsigned signal type) modulo value 
				terminal_count <= '1';						-- and output a terminal_count signal
			ELSE
				bin_counter <= bin_counter - 1;
				terminal_count <= '0';
			END IF;
	  ELSE
			bin_counter <= bin_counter;
			terminal_count <= terminal_count;
			
	  END IF;
   END PROCESS;
	

Strobe_gen: PROCESS(clkin, rst_n) IS			-- Strobe is with 50% duty cycle
   BEGIN
		IF (rst_n = '0') Then
			strobe <= '0';
		-- on active clock
		ELSIF (rising_edge(clkin)) THEN
			If (half_cycle = '1') THEN
				strobe <= NOT strobe;
				--termincal_count <= '0'; maybe add this??? 
			ELSE
				strobe <= strobe;
			END IF ; 
		-- not active clock
		ELSE
			strobe <= strobe;
		END IF;
	END PROCESS;

	
CLKEN_GEN: PROCESS(clkin, rst_n) IS				-- full_cycle is one "clkin" cycle in duration and occure once for every two occurrences of half_cycle
   
   BEGIN
   		IF (rst_n = '0') Then
		-- on active clock
			toggle_next <= TRUE;
			full_cycle <= '0';
		ELSIF (rising_edge(clkin)) THEN
			-- when the clock is at half cycle
			If (half_cycle = '1') THEN
			-- if it was signaled to toggle this half cycle
				IF (toggle_next = TRUE) THEN
					toggle_next <= FALSE;
					full_cycle <= '1';
				-- signal to toggle next half cycle if it didnt this cycle
				ELSE
					toggle_next <= TRUE;
				END IF;
			-- if it wasnt half cycle, the output is always 0
			ELSE
				full_cycle <= '0';
			END IF ;
		-- not active clock
		ELSE
			full_cycle <= full_cycle;
		END IF;
	END PROCESS;

	END Architecture;

