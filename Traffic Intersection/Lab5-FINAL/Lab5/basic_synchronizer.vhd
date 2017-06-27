LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

entity basic_synchronizer is port(
	clkin 			:IN std_logic;
	data_input		:IN std_logic;
	data_output 	:OUT std_logic
	--rst_n		:IN std_logic; was added for completeness, removed as it is unnecessary
);
end basic_synchronizer;

architecture basic_synchro of basic_synchronizer is
	--signals for inputs and outputs of DFF network
	SIGNAL first_latch, second_latch, input1, input2 	:std_logic;
begin 
-- data flow of synchronizer
input1 <= data_input;
data_output <= second_latch;
input2 <= first_latch; -- so it doesnt go straight into the second latch after it changes

sync: process(clkin)
begin
	-- now obsolete reset button;
	--if (rst_n = '1') then
	--	first_latch <='0';
		--second_latch <= '0';
	if (rising_edge(clkin)) then 
		-- dump input info into output
		first_latch <= input1;
		second_latch <= input2;
	ELSE
		--maintain current data
		first_latch <= first_latch;
		second_latch <= second_latch;
	END if;
	
end process;


end architecture basic_synchro;